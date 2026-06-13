#!/usr/bin/env bash
set -u

# tools/memory.sh — boat's content-addressed witness chain (MEMORY-0000).
#
# Subcommands:
#   memory.sh append KIND CONTEXT       (stdin body -> chained record)
#   memory.sh verify                    (replay chain; rc 0 iff valid)
#   memory.sh recall PATTERN [--context C]
#   memory.sh import-loop               (seed from candidates/*/LANDED)
#   memory.sh sync supermemory          (push unsynced records to lowering)
#
# Repo-rooted: resolves ROOT relative to this script's location, so the
# tool's behavior does not depend on the caller's cwd. Override with
# MEMORY_DIR (absolute) to point at a different chain (used by eval-self
# scratch trees; never mutate the real log from tests).
#
# Acceptance is local: a record is authoritative iff it resides in the
# log AND verifies under MEM-1.2. External services (supermemory, beads)
# are caches (MEM-1.5); their downtime emits unavailable(reason) and
# never blocks append/verify/recall.

TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$TOOLS_DIR/.." && pwd)"
MEMORY_DIR="${MEMORY_DIR:-$ROOT/memory}"
LOG="$MEMORY_DIR/log.jsonl"
BASE_TSV="${BASE_TSV:-$ROOT/nix/contexts/base.tsv}"
SYNC_STATE="$MEMORY_DIR/.synced.supermemory"

die() { printf 'memory: %s\n' "$*" >&2; exit 1; }
warn() { printf 'memory: %s\n' "$*" >&2; }

require_python() {
  command -v python3 >/dev/null 2>&1 \
    || die "verifier_contract_violation: python3 unavailable (ctx-scripted dependency)"
}

sha256_stdin() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 | awk '{print $1}'
  else
    sha256sum | awk '{print $1}'
  fi
}

# Canonical JSON: sort_keys, tight separators. Operates on the record
# minus its hash field, so the hash is reproducible (MEM-1.1).
canonical_without_hash() {
  python3 -c '
import json, sys
d = json.load(sys.stdin)
d.pop("hash", None)
print(json.dumps(d, sort_keys=True, separators=(",", ":")), end="")
'
}

# closure_up CTX  ->  prints, one per line, the contexts coarsens_to-
# reachable from CTX (including CTX itself). Falls back to {CTX} when
# base.tsv is missing — MEM-1.4 honest fallback.
closure_up() {
  local ctx="$1"
  if [[ ! -f "$BASE_TSV" ]]; then
    printf 'unavailable(no-base)\n%s\n' "$ctx"
    return 0
  fi
  python3 - "$BASE_TSV" "$ctx" <<'PY'
import sys
base_path, start = sys.argv[1], sys.argv[2]
edges = {}
with open(base_path) as f:
    for line in f:
        line = line.rstrip("\n")
        if not line or line.startswith("#"):
            continue
        parts = line.split("\t")
        if len(parts) < 2:
            continue
        src, dst = parts[0], parts[1]
        if dst == "-":
            continue
        edges.setdefault(src, []).append(dst)
seen = {start}
stack = [start]
while stack:
    cur = stack.pop()
    for nxt in edges.get(cur, []):
        if nxt not in seen:
            seen.add(nxt)
            stack.append(nxt)
print("\n".join(sorted(seen)))
PY
}

ensure_log() {
  mkdir -p "$MEMORY_DIR"
  [[ -f "$LOG" ]] || : > "$LOG"
}

last_hash() {
  ensure_log
  local line
  line="$(tail -n 1 "$LOG" 2>/dev/null || true)"
  [[ -z "$line" ]] && { printf ''; return 0; }
  printf '%s' "$line" | python3 -c 'import json,sys; print(json.load(sys.stdin)["hash"], end="")'
}

# Validate one record's body for the canonical fields and types. Used
# during verify; append builds records itself so this is a sanity gate
# on imported data.
require_fields() {
  python3 - <<'PY' "$@"
import json, sys
line = sys.argv[1]
try:
    d = json.loads(line)
except Exception as e:
    print("malformed JSON:", e, file=sys.stderr); sys.exit(1)
for k in ("context", "kind", "body", "prev", "hash", "recorded_at"):
    if k not in d:
        print("missing field:", k, file=sys.stderr); sys.exit(1)
PY
}

# Partial-line guard (REVIEW.md concern 1): a final record without a
# trailing newline is invisible to `while read` but visible to python
# readers — a smuggling channel. Any unterminated log fails closed
# everywhere (verify AND recall).
chain_terminated() {
  [[ ! -s "$LOG" ]] && return 0
  [[ -z "$(tail -c 1 "$LOG")" ]]
}


case "${1:-}" in

append)
  shift
  kind="${1:-}"; ctx="${2:-}"
  [[ -n "$kind" && -n "$ctx" ]] || die "usage: memory.sh append KIND CONTEXT (body on stdin)"
  require_python
  ensure_log
  body="$(cat)"
  prev="$(last_hash)"
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  # Build record (without hash), canonicalize, hash, then emit final form.
  record_no_hash="$(python3 -c '
import json, sys
context, kind, body, prev, ts = sys.argv[1:6]
print(json.dumps({
    "context": context, "kind": kind, "body": body,
    "prev": prev, "recorded_at": ts
}, sort_keys=True, separators=(",", ":")), end="")
' "$ctx" "$kind" "$body" "$prev" "$ts")"
  rec_hash="$(printf '%s' "$record_no_hash" | sha256_stdin)"
  python3 -c '
import json, sys
rec = json.loads(sys.argv[1])
rec["hash"] = sys.argv[2]
print(json.dumps(rec, sort_keys=True, separators=(",", ":")))
' "$record_no_hash" "$rec_hash" >> "$LOG"
  printf '%s\n' "$rec_hash"
  ;;

verify)
  require_python
  ensure_log
  chain_terminated || { printf 'memory: verifier_contract_violation: unterminated final record (partial-line smuggling)\n' >&2; exit 65; }
  i=0; prev=""
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    i=$((i + 1))
    require_fields "$line" || die "verifier_contract_violation: record $i malformed"
    rec_prev="$(printf '%s' "$line" | python3 -c 'import json,sys; print(json.load(sys.stdin)["prev"], end="")')"
    rec_hash="$(printf '%s' "$line" | python3 -c 'import json,sys; print(json.load(sys.stdin)["hash"], end="")')"
    if [[ "$rec_prev" != "$prev" ]]; then
      printf 'memory: verifier_contract_violation: record %s prev=%s does not match expected %s\n' \
        "$i" "$rec_prev" "$prev" >&2
      exit 65
    fi
    recomputed="$(printf '%s' "$line" | canonical_without_hash | sha256_stdin)"
    if [[ "$rec_hash" != "$recomputed" ]]; then
      printf 'memory: verifier_contract_violation: record %s hash=%s does not recompute (%s)\n' \
        "$i" "$rec_hash" "$recomputed" >&2
      exit 65
    fi
    prev="$rec_hash"
  done < "$LOG"
  printf 'memory: verify ok (%s records)\n' "$i"
  ;;

recall)
  shift
  pattern="${1:-}"; shift || true
  ctx=""
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --context)
        [[ "$#" -ge 2 && -n "${2:-}" ]] || die "usage: memory.sh recall PATTERN [--context C] (--context requires a value)"
        ctx="$2"; shift 2 ;;
      *) die "unknown flag: $1" ;;
    esac
  done
  [[ -n "$pattern" ]] || die "usage: memory.sh recall PATTERN [--context C]"
  require_python
  ensure_log
  chain_terminated || die "unterminated final record — refuse recall on an unverifiable chain (run: memory.sh verify)"
  if [[ -n "$ctx" ]]; then
    # CTX-1.3 pushforward: record(R) matches query(C) iff C is coarsens_to-
    # reachable from R (closure_up(R) ∋ C). We compute closure_up per
    # record context. Honest fallback noted in trace when base.tsv absent.
    if [[ ! -f "$BASE_TSV" ]]; then
      printf 'memory: recall context restriction unavailable(no-base) — falling back to literal equality\n' >&2
    fi
  fi
  python3 - "$pattern" "$ctx" "$LOG" "$BASE_TSV" <<'PY'
import json, sys
pattern, ctx, log_path, base_path = sys.argv[1:5]
edges = {}
have_base = False
try:
    with open(base_path) as f:
        have_base = True
        for line in f:
            line = line.rstrip("\n")
            if not line or line.startswith("#"):
                continue
            parts = line.split("\t")
            if len(parts) < 2 or parts[1] == "-":
                continue
            edges.setdefault(parts[0], []).append(parts[1])
except FileNotFoundError:
    have_base = False
def closure_up(start):
    seen = {start}; stack = [start]
    while stack:
        cur = stack.pop()
        for nxt in edges.get(cur, []):
            if nxt not in seen:
                seen.add(nxt); stack.append(nxt)
    return seen
hits = 0
with open(log_path) as f:
    for line in f:
        line = line.rstrip("\n")
        if not line:
            continue
        try:
            d = json.loads(line)
        except Exception:
            continue
        hay = "\t".join((d.get("kind",""), d.get("context",""), d.get("body","")))
        if pattern not in hay:
            continue
        if ctx:
            R = d.get("context","")
            if have_base:
                if ctx not in closure_up(R):
                    continue
            else:
                # Honest fallback: literal equality only (MEM-1.4).
                if R != ctx:
                    continue
        print(json.dumps({"hash": d.get("hash",""), "context": d.get("context",""),
                          "kind": d.get("kind",""), "body": d.get("body","")},
                         separators=(",", ":")))
        hits += 1
print(f"# recall hits: {hits}", file=sys.stderr)
PY
  ;;

import-loop)
  require_python
  ensure_log
  # For each candidate dir whose META says status=landed and which carries
  # a LANDED manifest, append one "landing" record. Content addressing
  # (MEM-1.1) makes this idempotent: re-running import-loop re-hashes the
  # same body and the chain dedups by hash check below (skip if last
  # record body matches; full dedup would require scanning the chain, so
  # we scan for the exact body+kind+context match in linear time).
  cand_dir="$ROOT/candidates"
  [[ -d "$cand_dir" ]] || die "no candidate store at $cand_dir"
  count=0
  for d in "$cand_dir"/cand-*/; do
    [[ -f "$d/META" && -f "$d/LANDED" ]] || continue
    status="$(awk -F': ' '$1 == "status" { print $2; exit }' "$d/META")"
    [[ "$status" == "landed" ]] || continue
    cid="$(awk -F': ' '$1 == "candidate_id" { print $2; exit }' "$d/META")"
    snap="$(awk -F'\t' '$1 == "git_commit" { print $2; exit }' "$d/LANDED")"
    landed_at="$(awk '/^# landed_at:/ { sub(/^# landed_at: */, ""); print; exit }' "$d/LANDED")"
    body="$(python3 -c '
import json, sys
print(json.dumps({"candidate": sys.argv[1], "snapshot": sys.argv[2],
                  "landed_at": sys.argv[3]}, sort_keys=True, separators=(",", ":")))
' "$cid" "${snap:-unknown}" "${landed_at:-unknown}")"
    # Dedup: if log already has a "landing" record with this body, skip.
    # MEM-1.1 makes the hash deterministic from body+kind+context+prev+ts;
    # since prev/ts differ run to run we dedup by body content match (this
    # makes import-loop idempotent for the same landed-set; new landings
    # since the last run become new records, the chain grows forward).
    seen_already="$(python3 - "$LOG" "$body" <<'PY'
import json, sys
log_path, body = sys.argv[1], sys.argv[2]
try:
    with open(log_path) as f:
        for line in f:
            line = line.rstrip("\n")
            if not line:
                continue
            try:
                d = json.loads(line)
            except Exception:
                continue
            if d.get("kind") == "landing" and d.get("body") == body:
                print("yes"); sys.exit(0)
except FileNotFoundError:
    pass
print("no")
PY
)"
    if [[ "$seen_already" == "yes" ]]; then
      continue
    fi
    printf '%s' "$body" | bash "$BASH_SOURCE" append landing scripted >/dev/null
    count=$((count + 1))
  done
  printf 'memory: import-loop appended %s landing records\n' "$count"
  ;;

sync)
  shift
  lowering="${1:-}"
  case "$lowering" in
    supermemory) ;;
    *) die "usage: memory.sh sync supermemory" ;;
  esac
  require_python
  ensure_log
  if [[ -z "${SUPERMEMORY_API_KEY:-}" ]]; then
    printf 'memory: sync unavailable(no-api-key) — set SUPERMEMORY_API_KEY to push (MEM-1.5: caches optional)\n'
    exit 0
  fi
  # CUST-1.4 (cand-0030): key-shape guard. Quote, backslash, or control
  # characters in the key could inject lines into the curl config stream
  # below (the cand-0014 smuggling family at the config layer). Refuse
  # before any curl invocation; the lowering is optional (MEM-1.5), so
  # this is an honest unavailable, not a crash.
  case "$SUPERMEMORY_API_KEY" in
    (*['"'"'"'\\']*|*[$'\t\r\n']*)
      printf 'memory: sync unavailable(key-shape) — SUPERMEMORY_API_KEY carries quote/backslash/control characters (config-injection guard); refusing to sync\n'
      exit 0
      ;;
  esac
  if ! command -v curl >/dev/null 2>&1; then
    printf 'memory: sync unavailable(no-curl) — local chain intact\n'
    exit 0
  fi
  : > "$SYNC_STATE.tmp"
  touch "$SYNC_STATE"
  pushed=0; skipped=0; failed=0
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    rec_hash="$(printf '%s' "$line" | python3 -c 'import json,sys; print(json.load(sys.stdin)["hash"], end="")')"
    if grep -qx "$rec_hash" "$SYNC_STATE" 2>/dev/null; then
      skipped=$((skipped + 1))
      printf '%s\n' "$rec_hash" >> "$SYNC_STATE.tmp"
      continue
    fi
    payload="$(python3 -c '
import json, sys
rec = json.loads(sys.argv[1])
out = {"content": rec.get("body",""), "containerTag": "boat",
       "metadata": {"kind": rec.get("kind",""), "context": rec.get("context",""),
                    "record_hash": rec.get("hash","")}}
print(json.dumps(out, separators=(",", ":")))
' "$line")"
    rc=0
    # CUST-1.4 (cand-0030): the bearer token never enters argv — argv is
    # a public, ps-visible channel (a boarding surface per CUSTODY-0000).
    # The header travels as curl config on stdin via builtin printf: no
    # exec carries the value, no temp file holds it. The payload stays in
    # argv by design: chain records are public repo content.
    printf 'header = "Authorization: Bearer %s"\n' "$SUPERMEMORY_API_KEY" | \
    curl -sS -X POST "https://api.supermemory.ai/v3/documents" \
      --config - \
      -H "Content-Type: application/json" \
      --data "$payload" >/dev/null 2>&1 || rc=$?
    if [[ "$rc" -eq 0 ]]; then
      pushed=$((pushed + 1))
      printf '%s\n' "$rec_hash" >> "$SYNC_STATE.tmp"
    else
      failed=$((failed + 1))
    fi
  done < "$LOG"
  mv "$SYNC_STATE.tmp" "$SYNC_STATE"
  printf 'memory: sync supermemory: pushed=%s skipped=%s failed=%s\n' "$pushed" "$skipped" "$failed"
  ;;

""|help|-h|--help)
  cat <<EOF
memory.sh — boat memory keel (MEMORY-0000)

Subcommands:
  append KIND CONTEXT       chain a record (body on stdin)
  verify                    replay chain (MEM-1.1 + MEM-1.2)
  recall PATTERN [--context C]
                            substring search restricted by CTX-1.3 closure
  import-loop               seed chain from candidates/*/LANDED
  sync supermemory          push unsynced records to supermemory lowering

Env:
  MEMORY_DIR    override the chain location (default \$ROOT/memory)
  BASE_TSV      override the worker-context base
  SUPERMEMORY_API_KEY  required for sync supermemory (else honest unavailable)
EOF
  ;;

*)
  die "unknown subcommand: ${1:-} (try memory.sh help)"
  ;;
esac
