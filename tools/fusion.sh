#!/usr/bin/env bash
set -u

# fusion.sh - thin client for OpenRouter Fusion (boat.fusion.v0).
#
# Fusion is OpenRouter's hosted compound model. This tool builds the request,
# optionally calls OpenRouter, and parses the response into either prose or a
# structured advisory analysis object. It does not replace file-grounded
# REVIEW.md and does not create acceptance authority.
#
# Key handling:
#   live calls read OPENROUTER_API_KEY, OPENROUTER_API_KEY_FILE, or
#   --api-key-file PATH. The key is never printed and is not placed in shell
#   argv for curl. The bounded Bridge shape is a key-file/proxy reference at
#   the execution leaf; raw key material must not enter cargo, traces, queue,
#   prompts, or logs.
#
# usage:
#   fusion.sh [options] "PROMPT"
#   echo "PROMPT" | fusion.sh [options] -
# options:
#   --structured        server-tool mode -> structured analysis JSON
#   --outer MODEL       outer model hosting the tool in --structured mode
#                       (default: $FUSION_OUTER_MODEL or openrouter/auto)
#   --panel m1,m2,...   panel models (1-8; default = OpenRouter's quality preset)
#   --judge MODEL       judge model (default: first panel model / outer)
#   --max-tool-calls N  per-member web-tool cap (1-16; default: server default)
#   --system TEXT       optional system message
#   --api-key-file PATH read the OpenRouter API key from PATH for a live call
#   --raw               print the full JSON response (to inspect structure)
#   --dry-run           build + print the request (key redacted), do NOT call
#   --parse FILE        parse FILE as a response instead of calling (offline)
#
# exit: 0 ok; 64 usage; 66 no key / missing dep / unsafe key shape;
#       67 transport or API non-200; 68 malformed / unparseable response.

ENDPOINT="${OPENROUTER_ENDPOINT:-https://openrouter.ai/api/v1/chat/completions}"
PY="$(command -v python3 || true)"

die() { printf 'fusion: %s\n' "$*" >&2; exit "${2:-1}"; }
usage() { sed -n '4,48p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }
need_value() {
  [[ "$#" -ge 2 && "${2:-}" != --* ]] || die "$1 requires a value" 64
}
[[ -n "$PY" ]] || die "python3 unavailable" 66

mode="prose"; outer="${FUSION_OUTER_MODEL:-openrouter/auto}"
panel=""; judge=""; maxtc=""; system=""; raw=0; dryrun=0; parsefile=""
api_key_file="${OPENROUTER_API_KEY_FILE:-}"
prompt=""; got_prompt=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --structured) mode="structured"; shift ;;
    --outer) need_value "$@"; outer="$2"; shift 2 ;;
    --panel) need_value "$@"; panel="$2"; shift 2 ;;
    --judge) need_value "$@"; judge="$2"; shift 2 ;;
    --max-tool-calls) need_value "$@"; maxtc="$2"; shift 2 ;;
    --system) need_value "$@"; system="$2"; shift 2 ;;
    --api-key-file) need_value "$@"; api_key_file="$2"; shift 2 ;;
    --raw) raw=1; shift ;;
    --dry-run) dryrun=1; shift ;;
    --parse) need_value "$@"; parsefile="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    -) prompt="$(cat)"; got_prompt=1; shift ;;
    --*) die "unknown flag: $1" 64 ;;
    *) prompt="$1"; got_prompt=1; shift ;;
  esac
done

parse_response_file() {
  "$PY" - "$1" "$raw" "$mode" <<'PYEOF'
import json, sys
path, raw, mode = sys.argv[1], sys.argv[2] == "1", sys.argv[3]
try:
    with open(path, encoding="utf-8") as f:
        doc = json.load(f)
except Exception as e:
    sys.stderr.write("fusion: malformed response (%s)\n" % e)
    sys.exit(68)
if raw:
    print(json.dumps(doc, indent=2))
    sys.exit(0)

if mode == "structured":
    def find(o):
        if isinstance(o, dict):
            a = o.get("analysis")
            if isinstance(a, dict) and "consensus" in a and "blind_spots" in a:
                return o
            for v in o.values():
                r = find(v)
                if r is not None:
                    return r
        elif isinstance(o, list):
            for v in o:
                r = find(v)
                if r is not None:
                    return r
        elif isinstance(o, str):
            s = o.strip()
            if '"analysis"' in s and '"consensus"' in s:
                try:
                    return find(json.loads(s))
                except Exception:
                    return None
        return None
    result = find(doc)
    if result is None:
        sys.stderr.write("fusion: structured analysis not found in response (use --raw to inspect)\n")
        sys.exit(68)
    print(json.dumps(result, indent=2))
    sys.exit(0)

try:
    content = doc["choices"][0]["message"]["content"]
except Exception:
    sys.stderr.write("fusion: response missing choices[0].message.content\n")
    sys.exit(68)
if not isinstance(content, str) or not content.strip():
    sys.stderr.write("fusion: empty answer content\n")
    sys.exit(68)
sys.stderr.write("fusion: answer via %s\n" % doc.get("model", "?"))
print(content)
PYEOF
}

if [[ -n "$parsefile" ]]; then
  [[ -f "$parsefile" ]] || die "parse file not found: $parsefile" 64
  parse_response_file "$parsefile"
  exit $?
fi

[[ "$got_prompt" -eq 1 && -n "$prompt" ]] || die "a prompt is required (arg or stdin '-')" 64

req="$("$PY" - "$mode" "$outer" "$prompt" "$panel" "$judge" "$maxtc" "$system" <<'PYEOF'
import json, sys
mode, outer, prompt, panel, judge, maxtc, system = sys.argv[1:8]

messages = []
if system:
    messages.append({"role": "system", "content": system})
messages.append({"role": "user", "content": prompt})

params = {}
if panel:
    ms = [m.strip() for m in panel.split(",") if m.strip()]
    if not (1 <= len(ms) <= 8):
        sys.stderr.write("fusion: --panel must list 1-8 models\n")
        sys.exit(64)
    params["analysis_models"] = ms
if judge:
    params["model"] = judge
if maxtc:
    try:
        n = int(maxtc)
    except ValueError:
        sys.stderr.write("fusion: --max-tool-calls must be an integer\n")
        sys.exit(64)
    if not (1 <= n <= 16):
        sys.stderr.write("fusion: --max-tool-calls must be 1-16\n")
        sys.exit(64)
    params["max_tool_calls"] = n

if mode == "structured":
    tool = {"type": "openrouter:fusion"}
    if params:
        tool["parameters"] = params
    body = {"model": outer, "messages": messages,
            "tools": [tool], "tool_choice": "required"}
else:
    body = {"model": "openrouter/fusion", "messages": messages}
    if params:
        params["id"] = "fusion"
        body["plugins"] = [params]
print(json.dumps(body))
PYEOF
)" || exit $?

if [[ "$dryrun" -eq 1 ]]; then
  printf 'POST %s\nAuthorization: Bearer <redacted>\nContent-Type: application/json\n\n' "$ENDPOINT"
  printf '%s' "$req" | "$PY" -m json.tool
  exit 0
fi

req_file="$(mktemp)"
resp_file="$(mktemp)"
trap 'rm -f "$req_file" "$resp_file"' EXIT
printf '%s' "$req" > "$req_file"

"$PY" - "$ENDPOINT" "$api_key_file" "$req_file" "$resp_file" <<'PYEOF'
import os, pathlib, sys, urllib.error, urllib.request

endpoint, key_file, req_file, resp_file = sys.argv[1:5]

def fail(msg, code):
    sys.stderr.write("fusion: %s\n" % msg)
    sys.exit(code)

def read_key_from_file(path):
    try:
        data = pathlib.Path(path).read_bytes()
    except Exception as e:
        fail("cannot read api key file: %s" % e, 66)
    if data.endswith(b"\n"):
        data = data[:-1]
    if data.endswith(b"\r"):
        data = data[:-1]
    if b"\n" in data or b"\r" in data or b"\0" in data:
        fail("api key file must contain exactly one key plus optional trailing newline", 66)
    try:
        return data.decode("utf-8")
    except UnicodeDecodeError:
        fail("api key file must be utf-8 text", 66)

key = read_key_from_file(key_file) if key_file else os.environ.get("OPENROUTER_API_KEY", "")
if not key:
    fail("OPENROUTER_API_KEY or OPENROUTER_API_KEY_FILE is required for live calls", 66)
if any((ord(ch) < 33 or ord(ch) > 126 or ch in {'"', '\\'}) for ch in key):
    fail("api key has unsupported characters for header use", 66)

try:
    body = pathlib.Path(req_file).read_bytes()
except Exception as e:
    fail("cannot read request body: %s" % e, 64)

request = urllib.request.Request(
    endpoint,
    data=body,
    headers={
        "Authorization": "Bearer %s" % key,
        "Content-Type": "application/json",
        "HTTP-Referer": "https://github.com/boat-loop",
        "X-Title": "boat-fusion",
    },
    method="POST",
)

try:
    with urllib.request.urlopen(request, timeout=120) as response:
        pathlib.Path(resp_file).write_bytes(response.read())
except urllib.error.HTTPError as e:
    snippet = e.read(2000).decode("utf-8", "replace")
    sys.stderr.write("fusion: API returned HTTP %s\n%s\n" % (e.code, snippet))
    sys.exit(67)
except Exception as e:
    fail("transport error calling %s: %s" % (endpoint, e), 67)
PYEOF
live_rc=$?
if [[ "$live_rc" -ne 0 ]]; then
  exit "$live_rc"
fi

parse_response_file "$resp_file"
