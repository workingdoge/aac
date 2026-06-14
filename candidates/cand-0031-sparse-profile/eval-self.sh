#!/usr/bin/env bash
# eval-self.sh -- functional evidence for cand-0031-sparse-profile.
# Checks that the sparse finite-basis amount profile states the canonical
# encoding and target-identity obligations needed before any circuit rewrite.
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"
CARGO="$CAND_DIR/cargo/sites/ledger/specs"
TRACES="$CAND_DIR/traces"
rm -rf "$TRACES"; mkdir -p "$TRACES"

PROFILE="$CARGO/profiles/SPARSE-CELLS-1.md"
INDEX="$CARGO/README.md"
PACI="$CARGO/1/README.md"
PROOF="$CARGO/3/README.md"

# tools/eval/attest.sh uses GNU `head -n -1`. On BSD/macOS, provide the exact
# behavior to the child bash process without modifying the verifier-set tool.
head() {
  if [[ "${1:-}" == "-n" && "${2:-}" == "-1" && $# -eq 3 ]]; then
    awk 'NR > 1 { print prev } { prev = $0 }' "$3"
  else
    command head "$@"
  fi
}
export -f head

check_profile_file() {
  local f="$1"
  local bad=0
  grep -q 'change the semantic object' "$f" || { echo "missing semantic non-change boundary"; bad=1; }
  grep -q 'SparseCell' "$f" || { echo "missing SparseCell definition"; bad=1; }
  grep -q 'active:   bit' "$f" || { echo "missing active bit"; bad=1; }
  grep -q 'basis_id: uint' "$f" || { echo "missing basis id"; bad=1; }
  grep -q 'debit:    uint' "$f" || { echo "missing debit"; bad=1; }
  grep -q 'credit:   uint' "$f" || { echo "missing credit"; bad=1; }
  grep -q 'absent basis coordinates contribute zero' "$f" || { echo "missing absent-as-zero interpretation"; bad=1; }
  grep -q 'Active cells are a prefix' "$f" || { echo "missing active prefix canonicalization"; bad=1; }
  grep -q 'strictly increasing by `basis_id`' "$f" || { echo "missing strict basis ordering"; bad=1; }
  grep -q 'Inactive cells are exactly zero' "$f" || { echo "missing inactive-zero rule"; bad=1; }
  grep -q 'active cell with `debit = 0` and `credit = 0` MUST be rejected' "$f" || { echo "missing active zero-cell rejection"; bad=1; }
  grep -q 'does not require debit and credit support' "$f" || { echo "missing raw-term support boundary"; bad=1; }
  grep -q 'per account and per basis' "$f" || { echo "missing state arithmetic boundary"; bad=1; }
  grep -q '`(account, basis_id)`' "$f" || { echo "missing sparse state uniqueness key"; bad=1; }
  grep -q 'include every slot' "$f" || { echo "missing commitment preimage rule"; bad=1; }
  grep -q 'new target identity' "$f" || { echo "missing target-identity consequence"; bad=1; }
  grep -q 'duplicate active `basis_id`' "$f" || { echo "missing duplicate rejection vector"; bad=1; }
  grep -q 'unsorted active `basis_id`' "$f" || { echo "missing unsorted rejection vector"; bad=1; }
  grep -q 'gap in the active prefix' "$f" || { echo "missing active-gap rejection vector"; bad=1; }
  grep -q 'non-zero inactive-cell junk' "$f" || { echo "missing inactive-junk rejection vector"; bad=1; }
  grep -q 'basis coordinate vanishes by omission' "$f" || { echo "missing omitted-basis rejection vector"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "profile carries sparse canonicalization + target identity obligations"
}

check_cross_refs() {
  local bad=0
  grep -q 'SPARSE-CELLS/1' "$INDEX" || { echo "spec index does not point to SPARSE-CELLS/1"; bad=1; }
  grep -q 'profiles/SPARSE-CELLS-1.md' "$INDEX" || { echo "spec index link missing"; bad=1; }
  grep -q 'sparse representation is conforming only if absent basis coordinates' "$PACI" || { echo "1/PACI sparse representation boundary missing"; bad=1; }
  grep -q 'SPARSE-CELLS/1' "$PACI" || { echo "1/PACI does not name SPARSE-CELLS/1"; bad=1; }
  grep -q 'Private witness layout is not itself public ABI' "$PROOF" || { echo "3/PROOF private witness boundary missing"; bad=1; }
  grep -q 'sparse amount profile' "$PROOF" || { echo "3/PROOF sparse profile target-identity hook missing"; bad=1; }
  echo "cross references present"
  [[ "$bad" -eq 0 ]]
}

check_corrupt() {
  local m="$TRACES/profile-mutant.md"
  cp "$PROFILE" "$m"
  perl -0pi -e 's/strictly increasing by `basis_id`/listed by `basis_id`/' "$m"
  if check_profile_file "$m" > "$TRACES/_mutant_check.txt" 2>&1; then
    echo "mutant unexpectedly passed"
    return 1
  fi
  grep -q 'missing strict basis ordering' "$TRACES/_mutant_check.txt" || { echo "mutant failed for the wrong reason"; cat "$TRACES/_mutant_check.txt"; return 1; }
  echo "mutant rejected when strict basis ordering is removed"
}

run() {
  local nm="$1" fn="$2" rc
  shift 2
  "$fn" "$@" > "$TRACES/$nm.txt" 2>&1
  rc=$?
  printf 'loop-eval: %-12s %s (exit=%d)\n' "$nm" "$([[ $rc -eq 0 ]] && echo pass || echo FAIL)" "$rc"
  return $rc
}

fail=0
run 01-profile "check_profile_file" "$PROFILE" || fail=1
run 02-crossrefs check_cross_refs || fail=1
run 03-corrupt check_corrupt || fail=1

verdict="pass"; [[ "$fail" -eq 0 ]] || verdict="fail"
{
  printf '{\n  "schema": "boat.eval-self.v0",\n  "candidate": "cand-0031-sparse-profile",\n'
  printf '  "evaluated_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '  "task": "define SPARSE-CELLS/1, a sparse finite-basis amount profile: fixed per-basis T-account cells with active flags, basis-id bounds, active-prefix canonicalization, strict basis-id ordering, zero inactive slots, active zero-cell rejection, absent-as-zero interpretation, sparse state uniqueness, commitment preimage rules, and target-identity consequences. No circuit rewrite, no domain tags, no R1 allocation.",\n'
  printf '  "checks": {\n'
  printf '    "profile": "%s",\n' "$(grep -q 'profile carries' "$TRACES/01-profile.txt" && echo pass || echo fail)"
  printf '    "crossrefs": "%s",\n' "$(grep -q 'cross references present' "$TRACES/02-crossrefs.txt" && echo pass || echo fail)"
  printf '    "corrupt": "%s"\n' "$(grep -q 'mutant rejected' "$TRACES/03-corrupt.txt" && echo pass || echo fail)"
  printf '  },\n  "verdict": "%s"\n}\n' "$verdict"
} > "$CAND_DIR/scores.json"

printf 'loop-eval: verdict=%s\n' "$verdict"
bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES" \
  || { printf 'loop-eval: WARNING attestation failed\n' >&2; exit 1; }
[[ "$verdict" == "pass" ]] || exit 1
