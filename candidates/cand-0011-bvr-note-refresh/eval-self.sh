#!/usr/bin/env bash
# eval-self.sh — evidence for cand-0011-bvr-note-refresh.
# The refreshed design note folds in the sketch deltas: it points to the
# now-landed EVENT-COMPLETE/1 spec (which must exist), states the coSNARK
# "not a universal proving mode" nuance, and the vector-commitment zero-opening
# requirement; and it stays non-normative.
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"
NOTE="$CAND_DIR/cargo/sites/ledger/design/0001-bvr-clearing-kernel.md"
TRACES="$CAND_DIR/traces"
rm -rf "$TRACES"; mkdir -p "$TRACES"

check_deltas() {
  local bad=0
  grep -qi 'non-normative' "$NOTE" || { echo "no longer marked non-normative"; bad=1; }
  grep -q 'EVENT-COMPLETE-1.md' "$NOTE" || { echo "does not point to the EVENT-COMPLETE/1 spec"; bad=1; }
  grep -qi 'not a universal proving mode' "$NOTE" || { echo "missing coSNARK pragmatism"; bad=1; }
  grep -qi 'zero-opening' "$NOTE" || { echo "missing the vector-commitment zero-opening requirement"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "deltas folded: spec pointer + coSNARK pragmatism + zero-opening; still non-normative"
}

check_pointer_resolves() {
  # The spec the note now points to must actually exist in the tree.
  [[ -e "$ROOT/sites/ledger/specs/applications/EVENT-COMPLETE-1.md" ]] || { echo "spec pointer is dangling"; return 1; }
  grep -q 'EVENT-COMPLETE/1' "$ROOT/sites/ledger/specs/applications/EVENT-COMPLETE-1.md" || { echo "spec target missing its name"; return 1; }
  echo "the EVENT-COMPLETE/1 spec pointer resolves"
}

run() { local n="$1" fn="$2" rc; "$fn" > "$TRACES/$n.txt" 2>&1; rc=$?; printf 'loop-eval: %-14s %s (exit=%d)\n' "$n" "$([[ $rc -eq 0 ]] && echo pass || echo FAIL)" "$rc"; return $rc; }

fail=0
run 01-deltas   check_deltas          || fail=1
run 02-pointer  check_pointer_resolves || fail=1

verdict="pass"; [[ "$fail" -eq 0 ]] || verdict="fail"
{
  printf '{\n  "schema": "boat.eval-self.v0",\n  "candidate": "cand-0011-bvr-note-refresh",\n'
  printf '  "evaluated_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '  "task": "Refresh Design Note 0001 — point to the landed EVENT-COMPLETE/1 spec, add the coSNARK not-a-universal-mode nuance and the vector-commitment zero-opening requirement; stays non-normative",\n'
  printf '  "checks": {\n'
  printf '    "deltas": "%s",\n'  "$(grep -q 'deltas folded' "$TRACES/01-deltas.txt" && echo pass || echo fail)"
  printf '    "pointer": "%s"\n'  "$(grep -q 'pointer resolves' "$TRACES/02-pointer.txt" && echo pass || echo fail)"
  printf '  },\n  "verdict": "%s"\n}\n' "$verdict"
} > "$CAND_DIR/scores.json"

printf 'loop-eval: verdict=%s\n' "$verdict"
bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES" \
  || { printf 'loop-eval: WARNING attestation failed\n' >&2; exit 1; }
[[ "$verdict" == "pass" ]] || exit 1
