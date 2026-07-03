#!/usr/bin/env bash
# eval-self.sh -- functional evidence for cand-0096.
#
# This evaluator stages the candidate landing, exercises the independent Python
# Poseidon2/PEDERSEN-VECTOR/1 reference, checks load-bearing mutants, and ends
# by attesting the probe table.
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"

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

# shellcheck source=../../tools/eval/eval-lib.sh
. "$ROOT/tools/eval/eval-lib.sh"
eval_init "$CAND_DIR" "$ROOT" || exit 1

WORK="$(mktemp -d /private/tmp/aac-cand-0096.XXXXXX)"
STAGED="$WORK/root"
stage_root "$STAGED" || exit 1

PY_REF="$STAGED/sites/ledger/specs/profiles/reference/pedersen_vector_1.py"
PROFILE="$STAGED/sites/ledger/specs/profiles/PEDERSEN-VECTOR-1.md"
VECTOR="$STAGED/sites/ledger/specs/profiles/vectors/PEDERSEN-VECTOR-1.json"
QUEUE="$STAGED/candidates/QUEUE.md"
README="$CAND_DIR/README.md"

python_rederivation_probe() {
  local generated="$WORK/PEDERSEN-VECTOR-1.generated.json" corrupt="$WORK/PEDERSEN-VECTOR-1.corrupt.json"
  python3 "$PY_REF" check "$VECTOR" || { echo "positive Python check failed"; return 0; }
  python3 "$PY_REF" generate --out "$generated" || { echo "Python generation failed"; return 0; }
  cmp -s "$generated" "$VECTOR" || { echo "generated JSON is not byte-identical to staged vector"; return 0; }
  cp "$VECTOR" "$corrupt"
  perl -0pi -e 's/"accepted_ctr": 3/"accepted_ctr": 4/' "$corrupt"
  if python3 "$PY_REF" check "$corrupt"; then
    echo "corrupt vector mutant unexpectedly matched"
    return 0
  fi
  echo "Python reference byte-matched the vector and rejected the corrupt counter mutant"
  return 41
}

tampered_round_constant_probe() {
  python3 "$PY_REF" check "$VECTOR" || { echo "positive Python check failed"; return 0; }
  if python3 "$PY_REF" check "$VECTOR" --tamper-round-constant; then
    echo "tampered Poseidon2 round constant unexpectedly matched"
    return 0
  fi
  echo "tampered Poseidon2 round constant changed the derivation and was rejected"
  return 42
}

even_y_probe() {
  local mutant="$WORK/pedersen_vector_1.no-derived-even-y.py" mutant_out="$TRACES/t03-even-y-mutant.out"
  python3 "$PY_REF" check-even-y > "$TRACES/t03-even-y.out" || { cat "$TRACES/t03-even-y.out"; return 0; }
  grep -Fq 'generator raw odd sqrt: G_0, G_1, G_2' "$TRACES/t03-even-y.out" || {
    echo "expected derived generator raw odd sqrt evidence missing"
    cat "$TRACES/t03-even-y.out"
    return 0
  }
  cp "$PY_REF" "$mutant"
  perl -0pi -e 's/"raw_sqrt_was_odd": raw_sqrt_was_odd/"raw_sqrt_was_odd": False/' "$mutant"
  if python3 "$mutant" check-even-y > "$mutant_out" 2>&1 && grep -Fq 'generator raw odd sqrt' "$mutant_out"; then
    echo "even-y observation mutant unexpectedly retained derived generator evidence"
    return 0
  fi
  echo "even-y rule exercised by G_0, G_1, and G_2; observation mutant rejected"
  return 43
}

check_honesty_upgrade() {
  local profile="$1" vector="$2"
  grep_prose 'vector is independently cross-checked by [`reference/pedersen_vector_1.py`](reference/pedersen_vector_1.py), a dependency-free Python implementation' "$profile" >/dev/null || return 1
  grep_prose 'The Python reference re-derives `field_of`, `basis_commitment`, every seed, accepted and rejected counters, and the `H`, `G_0`, `G_1`, and `G_2` coordinates byte-for-byte against the committed vector.' "$profile" >/dev/null || return 1
  grep -Fq 'Independently cross-checked by sites/ledger/specs/profiles/reference/pedersen_vector_1.py, a dependency-free Python implementation of the BN254 Poseidon2 permutation, Grumpkin try-and-increment, and even-y canonicalization.' "$vector" || return 1
  grep -Fq 'The Python checker re-derives field_of, basis_commitment, seeds, counters, rejected prior x values, and H/G_0/G_1/G_2 coordinates byte-for-byte.' "$vector" || return 1
  ! grep_prose 'not yet an independent Poseidon2 implementation cross-check' "$profile" "$vector" >/dev/null
}

honesty_clause_probe() {
  local mp="$WORK/PEDERSEN-VECTOR-1.honesty-mutant.md" mv="$WORK/PEDERSEN-VECTOR-1.honesty-mutant.json"
  check_honesty_upgrade "$PROFILE" "$VECTOR" || { echo "positive honesty upgrade check failed"; return 0; }
  cp "$PROFILE" "$mp"
  cp "$VECTOR" "$mv"
  perl -0pi -e 's/vector is independently cross-checked/vector is not yet independently cross-checked/' "$mp"
  perl -0pi -e 's/Independently cross-checked by/Not independently cross-checked by/' "$mv"
  if check_honesty_upgrade "$mp" "$mv"; then
    echo "honesty upgrade mutant unexpectedly passed"
    return 0
  fi
  echo "honesty clause upgraded and downgrade mutant rejected"
  return 44
}

check_constants_provenance() {
  local readme="$1"
  grep_prose '/nix/store/4rb54wn3b0cydjc5f0n6h3a8xlyw58i0-source' "$readme" >/dev/null || return 1
  grep_prose 'sha256-Plp1ARY6cMUhsqczwYNfIWltgxZ3yHle74af+ZCnUYY=' "$readme" >/dev/null || return 1
  grep_prose 'poseidon2_constants.rs` (`sha256: 4e31415d0696eef3ca558746841a12f54250f452e2b53c35aba96684fb776b3b`)' "$readme" >/dev/null || return 1
  grep_prose 'poseidon2.rs` (`sha256: 6511aeb27d28efa0c6e2e69dcf4b50da31e397df9fdffffe6bcdd01e096e5fc9`)' "$readme" >/dev/null || return 1
  grep_prose 'The Python code does not read those paths at runtime; the constants are transcribed into the reference file.' "$readme" >/dev/null || return 1
}

constants_provenance_probe() {
  local mutant="$WORK/README.constants-mutant.md"
  check_constants_provenance "$README" || { echo "positive constants provenance check failed"; return 0; }
  cp "$README" "$mutant"
  perl -0pi -e 's/4e31415d0696eef3ca558746841a12f54250f452e2b53c35aba96684fb776b3b/0000000000000000000000000000000000000000000000000000000000000000/' "$mutant"
  if check_constants_provenance "$mutant"; then
    echo "constants provenance mutant unexpectedly passed"
    return 0
  fi
  echo "constants provenance path and hashes present; sha mutant rejected"
  return 45
}

queue_probe() {
  local mutant="$WORK/QUEUE.duplicate-header.md"
  BOAT_ROOT="$STAGED" QUEUE_MD="$QUEUE" bash "$STAGED/tools/queue-lint.sh" > "$TRACES/t06-queue-lint.out" 2>&1 \
    || { echo "staged queue does not lint"; cat "$TRACES/t06-queue-lint.out"; return 0; }
  grep -Fq '[resolved cand-0096-python-poseidon-crosscheck, 2026-07-03]' "$QUEUE" || {
    echo "resolved cand-0096 queue row missing"
    return 0
  }
  grep_prose 'The cand-0093 honesty clause is upgraded: the vector remains generated by the Noir-family harness, but is now independently cross-checked by Python.' "$QUEUE" >/dev/null || {
    echo "queue honesty-upgrade summary missing"
    return 0
  }
  if grep_prose 'Follow up with an independent Python Poseidon2 implementation' "$QUEUE" >/dev/null; then
    echo "old open follow-up text still present"
    return 0
  fi
  cp "$QUEUE" "$mutant"
  printf '\n## Open\n' >> "$mutant"
  if BOAT_ROOT="$STAGED" QUEUE_MD="$mutant" bash "$STAGED/tools/queue-lint.sh" > "$TRACES/t06-queue-mutant.out" 2>&1; then
    echo "duplicate-header queue mutant unexpectedly passed"
    return 0
  fi
  echo "queue resolves cand-0096 and duplicate-header mutant rejected"
  return 46
}

run_failing_probe \
  t01-python-rederivation \
  "Python reference regenerates PEDERSEN-VECTOR-1.json byte-for-byte and rejects a corrupt accepted_ctr mutant" \
  "Python rederivation probe did not reject its corrupt mutant" \
  python_rederivation_probe

run_failing_probe \
  t02-tampered-round-constant \
  "Tampering one Poseidon2 round constant changes the derivation and fails the vector check" \
  "tampered round constant probe did not fail" \
  tampered_round_constant_probe

run_failing_probe \
  t03-even-y-exercised \
  "Even-y canonicalization is exercised by G_0, G_1, and G_2 raw odd square roots; observation mutant rejected" \
  "even-y probe did not reject its observation mutant" \
  even_y_probe

run_failing_probe \
  t04-honesty-clause-upgrade \
  "Spec and vector notes upgrade cand-0093 honesty clause to independently cross-checked; downgrade mutant rejected" \
  "honesty clause probe did not reject its downgrade mutant" \
  honesty_clause_probe

run_failing_probe \
  t05-constants-provenance \
  "Candidate README records exact local constants provenance path and hashes; sha mutant rejected" \
  "constants provenance probe did not reject its sha mutant" \
  constants_provenance_probe

run_failing_probe \
  t06-queue-update \
  "Queue resolves cand-0096 with the honesty-clause upgrade and rejects malformed duplicate-header mutant" \
  "queue probe did not reject its malformed mutant" \
  queue_probe

attest_tail "cand-0096 independent Python Poseidon2 cross-check for PEDERSEN-VECTOR/1"
