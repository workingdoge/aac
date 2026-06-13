#!/usr/bin/env bash
set -u

# cross-surface-check: the RJ-1.4 receipt-pair join (STONE S2 backstop).
#
# Joins three record surfaces per candidate — META status, the LANDED
# manifest, and the memory/log.jsonl landing records — and refuses
# typed when they fail to glue:
#   - a landed candidate missing its LANDED manifest or chain record is
#     `descent_failure` (GATE-3.3: no global glue exists for the
#     landing claim);
#   - a chain record whose snapshot disagrees with LANDED git_commit is
#     `glue_non_contractible` (GATE-3.4: two restrictions of the same
#     landing disagree);
#   - a chain landing record naming a candidate directory that does not
#     exist is `descent_failure` on the chain side.
# Profile: boat.cross-surface.v0 — a SET-LEVEL join citing the GATE
# laws through record-judgments-v0 RJ-1.4; no kernel conformance is
# claimed. Rolled-back candidates are exempt from the landed-side
# obligations (their landing receipts legitimately persist).
#
# Chain integrity is delegated to memory.sh verify first; failures are
# emitted typed via tools/eval/emit-refusal.sh (witnessIds minted), one
# JSON envelope per line on stdout, human summary on stderr.
# Exit: 0 all surfaces glue; 1 mismatches; 65 chain integrity failure;
# 66 missing substrate.

ROOT="${BOAT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
LOG="${MEMORY_LOG:-$ROOT/memory/log.jsonl}"
STORE="$ROOT/candidates"
EMIT="$ROOT/tools/eval/emit-refusal.sh"
PY="$(command -v python3 || true)"

[[ -n "$PY" && -x "$PY" ]] || { printf 'cross-surface-check: python3 unavailable\n' >&2; exit 66; }
[[ -d "$STORE" ]] || { printf 'cross-surface-check: no candidate store\n' >&2; exit 66; }
[[ -f "$EMIT" ]] || { printf 'cross-surface-check: emit-refusal.sh missing\n' >&2; exit 66; }

# A missing chain is NOT a substrate failure: it is the worst drift
# state (landed candidates with zero receipts) and must flow into the
# joins as an empty chain so every landed candidate is caught.
chain_empty=no
if [[ ! -f "$LOG" ]]; then
  printf 'cross-surface-check: memory chain absent — treating as empty (every landed candidate will fail its join)\n' >&2
  chain_empty=yes
fi

if [[ "$chain_empty" == no ]] && ! bash "$ROOT/tools/memory.sh" verify >/dev/null 2>&1; then
  printf 'cross-surface-check: memory chain integrity FAILED (memory.sh verify) — joins are meaningless over a broken chain\n' >&2
  exit 65
fi

failures=0
refuse() { # CLASS TOKEN_PATH REASON
  bash "$EMIT" "$1" "$2" "RJ-1.4 cross-surface join (profile boat.cross-surface.v0)" "$3" 'null' \
    || printf 'cross-surface-check: emission degraded for %s\n' "$2" >&2
  failures=$((failures+1))
}

# Chain-side map: candidate -> last-recorded snapshot
chain_map="$(mktemp)"
if [[ "$chain_empty" == yes ]]; then
  : > "$chain_map"
else
"$PY" - "$LOG" > "$chain_map" <<'PYEOF'
import json, sys
last = {}
for ln in open(sys.argv[1]):
    ln = ln.strip()
    if not ln:
        continue
    rec = json.loads(ln)
    if rec.get("kind") != "landing":
        continue
    body = json.loads(rec["body"])
    last[body["candidate"]] = body.get("snapshot", "")
for cand, snap in sorted(last.items()):
    print(f"{cand}\t{snap}")
PYEOF
fi

# Candidate-side pass
checked=0
for d in "$STORE"/cand-*/; do
  [[ -f "$d/META" ]] || continue
  cid="$(awk -F': ' '$1 == "candidate_id" { print $2; exit }' "$d/META")"
  status="$(awk -F': ' '$1 == "status" { print $2; exit }' "$d/META")"
  [[ "$status" == "landed" ]] || continue
  checked=$((checked+1))
  if [[ ! -f "$d/LANDED" ]]; then
    refuse descent_failure "$cid.LANDED" "META says landed but no LANDED manifest exists"
    continue
  fi
  snap="$(awk -F'\t' '$1 == "git_commit" { print $2; exit }' "$d/LANDED")"
  rec_snap="$(awk -F'\t' -v c="$cid" '$1 == c { print $2; exit }' "$chain_map")"
  if ! grep -q "^$cid	" "$chain_map"; then
    refuse descent_failure "$cid.chain" "landed candidate has no landing record on the memory chain (repair: bash tools/memory.sh import-loop)"
    continue
  fi
  if [[ -n "$snap" && "$rec_snap" != "$snap" ]]; then
    refuse glue_non_contractible "$cid.snapshot" "chain record snapshot '$rec_snap' disagrees with LANDED git_commit '$snap'"
  fi
done

# Chain-side reverse pass: every recorded landing names a real candidate
while IFS=$'\t' read -r cid snap; do
  [[ -n "$cid" ]] || continue
  [[ -d "$STORE/$cid" && -f "$STORE/$cid/META" ]] \
    || refuse descent_failure "chain.$cid" "chain landing record names a candidate directory that does not exist"
done < "$chain_map"

rm -f "$chain_map"

if [[ "$failures" -gt 0 ]]; then
  printf 'cross-surface-check: %s join failure(s) over %s landed candidate(s)\n' "$failures" "$checked" >&2
  exit 1
fi
printf 'cross-surface-check: ok (%s landed candidates glue across META/LANDED/chain)\n' "$checked"
