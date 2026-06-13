#!/usr/bin/env bash
# eval-self.sh — evidence for cand-0010-event-complete-spec.
# EVENT-COMPLETE/1 is an application-target spec. Evidence is structural: it
# declares itself a non-enshrined application target, states the 10 obligations
# + the public ABI + the completeness-not-truth boundary, and every spec it
# cites actually exists.
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"
SPEC="$CAND_DIR/cargo/sites/ledger/specs/applications/EVENT-COMPLETE-1.md"
IDX="$CAND_DIR/cargo/sites/ledger/specs/applications/README.md"
TRACES="$CAND_DIR/traces"
rm -rf "$TRACES"; mkdir -p "$TRACES"

check_present() {
  local bad=0
  [[ -f "$SPEC" ]] || { echo "spec missing"; bad=1; }
  [[ -f "$IDX" ]]  || { echo "applications index missing"; bad=1; }
  grep -qi 'application target' "$SPEC" && grep -qi 'not enshrined' "$SPEC" || { echo "does not declare itself a non-enshrined application target"; bad=1; }
  grep -qE 'MUST NOT' "$SPEC" || { echo "missing the registry-MUST-NOT-require rule"; bad=1; }
  grep -qi 'non-enshrined' "$IDX" || { echo "index does not mark application targets non-enshrined"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "spec + index present; declares non-enshrined application target"
}

check_content() {
  local bad=0
  # The 10 numbered obligations.
  local n; n=$(grep -cE '^[0-9]+\. \*\*' "$SPEC")
  [[ "$n" -ge 10 ]] || { echo "fewer than 10 obligations ($n)"; bad=1; }
  # Φ_R compiler statement.
  grep -qE 'Φ_R|Phi_R' "$SPEC" && grep -q 'J = Φ_R\|Φ_R : ' "$SPEC" >/dev/null 2>&1
  grep -qE 'Φ_R' "$SPEC" || { echo "missing the Phi_R compiler"; bad=1; }
  # Pⁿ zero-account + no numeraire.
  grep -qi 'zero-account' "$SPEC" || { echo "missing the zero-account statement"; bad=1; }
  grep -qi 'numeraire' "$SPEC" || { echo "missing the no-numeraire rule"; bad=1; }
  # Public ABI table.
  grep -q 'journal_commitment' "$SPEC" && grep -q 'fact_fold' "$SPEC" && grep -q 'basis_commitment' "$SPEC" || { echo "ABI table incomplete"; bad=1; }
  # completeness-not-truth boundary.
  grep -qi 'completeness, not truth' "$SPEC" || { echo "missing the completeness-not-truth boundary"; bad=1; }
  # composes with TRANSITION/1, separated from NET/VNET.
  grep -q 'TRANSITION/1' "$SPEC" && grep -q 'NET/1' "$SPEC" || { echo "composition with enshrined targets missing"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "10 obligations, Phi_R, Pⁿ zero-account/no-numeraire, ABI, boundary, composition all present"
}

check_crossrefs() {
  local bad=0
  for p in \
    sites/ledger/specs/1/README.md \
    sites/ledger/specs/2/README.md \
    sites/ledger/specs/3/README.md \
    sites/ledger/specs/4/README.md \
    sites/ledger/design/0001-bvr-clearing-kernel.md ; do
    [[ -e "$ROOT/$p" ]] || { echo "dangling cross-reference: $p"; bad=1; }
  done
  # the obligations lean on journal_sum_field_sound + Annex B + factId — sanity that those concepts exist in the cited specs.
  grep -q 'journal_sum_field_sound' "$ROOT/sites/ledger/statements/Core.lean" || { echo "journal_sum_field_sound not in Core.lean"; bad=1; }
  grep -qi 'fact_fold' "$ROOT/sites/ledger/specs/3/README.md" || { echo "Annex B fact_fold not in 3/PROOF"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "all cross-references resolve; cited mechanisms verified"
}

run() { local n="$1" fn="$2" rc; "$fn" > "$TRACES/$n.txt" 2>&1; rc=$?; printf 'loop-eval: %-12s %s (exit=%d)\n' "$n" "$([[ $rc -eq 0 ]] && echo pass || echo FAIL)" "$rc"; return $rc; }

fail=0
run 01-present   check_present   || fail=1
run 02-content   check_content   || fail=1
run 03-crossrefs check_crossrefs || fail=1

verdict="pass"; [[ "$fail" -eq 0 ]] || verdict="fail"
{
  printf '{\n  "schema": "boat.eval-self.v0",\n  "candidate": "cand-0010-event-complete-spec",\n'
  printf '  "evaluated_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '  "task": "EVENT-COMPLETE/1 application-target spec — declares non-enshrined, states Phi_R + the 10 obligations + the BVR public ABI + the completeness-not-truth boundary; composes with TRANSITION/1; cross-references resolve",\n'
  printf '  "checks": {\n'
  printf '    "present": "%s",\n'   "$(grep -q 'non-enshrined application target' "$TRACES/01-present.txt" && echo pass || echo fail)"
  printf '    "content": "%s",\n'   "$(grep -q 'all present' "$TRACES/02-content.txt" && echo pass || echo fail)"
  printf '    "crossrefs": "%s"\n'  "$(grep -q 'cross-references resolve' "$TRACES/03-crossrefs.txt" && echo pass || echo fail)"
  printf '  },\n  "verdict": "%s"\n}\n' "$verdict"
} > "$CAND_DIR/scores.json"

printf 'loop-eval: verdict=%s\n' "$verdict"
bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES" \
  || { printf 'loop-eval: WARNING attestation failed\n' >&2; exit 1; }
[[ "$verdict" == "pass" ]] || exit 1
