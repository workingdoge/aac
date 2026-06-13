#!/usr/bin/env bash
set -u

# emit-refusal: the shared typed-refusal emitter (STONE S1).
# Prints ONE failure object (check-sigpi-judgment-v0 rejected-shape
# member) to stdout:
#   {"failed_judgment": J, "obstruction_class": C, "lawRef": L,
#    "tokenPath": P, "reason": R, "witnessId": W}
# lawRef is looked up from tools/schemas/failure-classes.tsv; the
# witnessId is minted via tools/eval/witness-id.sh over the canonical
# key {class, lawRef, tokenPath, context}. An unregistered class or a
# missing minting substrate degrades HONESTLY (lawRef
# "unregistered(...)" / witnessId null) — the refusal itself is never
# suppressed; emission failure exits 65 so callers fail closed.
#
# usage: emit-refusal.sh CLASS TOKEN_PATH JUDGMENT REASON [CONTEXT_JSON]

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REGISTRY="${BOAT_FAILURE_CLASSES:-$ROOT/tools/schemas/failure-classes.tsv}"
WID="$ROOT/tools/eval/witness-id.sh"
PYTHON="${BOAT_WITNESS_ID_PYTHON:-$(command -v python3 || true)}"

[[ "$#" -ge 4 && "$#" -le 5 ]] || {
  printf 'usage: emit-refusal.sh CLASS TOKEN_PATH JUDGMENT REASON [CONTEXT_JSON]\n' >&2
  exit 64
}
cls="$1"; tok="$2"; judgment="$3"; reason="$4"; ctx="${5:-null}"

law=""
if [[ -f "$REGISTRY" ]]; then
  law="$(awk -F'\t' -v c="$cls" '$0 !~ /^#/ && $1 == c { print $2; exit }' "$REGISTRY")"
fi
[[ -n "$law" ]] || law="unregistered($cls)"

[[ -n "$PYTHON" && -x "$PYTHON" ]] || exit 65

"$PYTHON" - "$cls" "$law" "$tok" "$judgment" "$reason" "$ctx" "$WID" <<'PYEOF'
import json, subprocess, sys
cls, law, tok, judgment, reason, ctx_raw, wid_tool = sys.argv[1:8]
try:
    ctx = json.loads(ctx_raw)
except json.JSONDecodeError:
    sys.exit(65)
witness_id = None
key = json.dumps({"class": cls, "lawRef": law,
                  "tokenPath": tok if tok else None, "context": ctx})
try:
    out = subprocess.run(["bash", wid_tool], input=key,
                         capture_output=True, text=True, timeout=30)
    if out.returncode == 0:
        witness_id = out.stdout.strip()
except Exception:
    pass
print(json.dumps({
    "failed_judgment": judgment,
    "obstruction_class": cls,
    "lawRef": law,
    "tokenPath": tok if tok else None,
    "reason": reason,
    "witnessId": witness_id,
}, sort_keys=True))
PYEOF
