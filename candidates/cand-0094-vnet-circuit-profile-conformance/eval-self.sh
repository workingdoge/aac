#!/usr/bin/env bash
# eval-self.sh -- functional evidence for cand-0094.
#
# This evaluator stages the candidate landing, checks the ProveKit VNET circuit
# against PEDERSEN-VECTOR/1 and VNET/1 public-surface obligations, runs the
# beta.19 package tests, and verifies the queue update.
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

WORK="$(mktemp -d /private/tmp/aac-cand-0094.XXXXXX)"
STAGED="$WORK/root"
stage_root "$STAGED" || exit 1

VNET_PKG="$STAGED/world-app/provekit-vnet"
VNET_MAIN="$VNET_PKG/src/main.nr"
VNET_README="$VNET_PKG/README.md"
VNET_PROVER="$VNET_PKG/Prover.toml.example"
VECTOR="$STAGED/sites/ledger/specs/profiles/vectors/PEDERSEN-VECTOR-1.json"
QUEUE="$STAGED/candidates/QUEUE.md"

resolve_nargo19() {
  local p
  for p in "${NARGO19_BIN:-}" "$ROOT/result/bin/nargo" "/nix/store/hgz7fp6br2721vh7c72bk0c9bwdz04ii-nargo-v1.0.0-beta.19/bin/nargo"; do
    [[ -n "$p" && -x "$p" ]] && { printf '%s\n' "$p"; return 0; }
  done
  return 1
}

check_no_free_label() {
  local f="$1"
  ! grep -Fq 'std::hash::derive_generators' "$f" || return 1
  ! grep -Fq 'AAC_PEDERSEN_VECTOR_VNET_1' "$f" || return 1
  grep -Fq 'point(G0_X, G0_Y)' "$f" || return 1
  grep -Fq 'point(G1_X, G1_Y)' "$f" || return 1
  grep -Fq 'point(G2_X, G2_Y)' "$f" || return 1
}

free_label_probe() {
  local m="$WORK/main-free-label-mutant.nr"
  check_no_free_label "$VNET_MAIN" || { echo "positive free-label absence check failed"; return 0; }
  cp "$VNET_MAIN" "$m"
  printf '\nfn mutant_free_label_probe() {\n    let _points: [EmbeddedCurvePoint; N_BASIS + 1] = std::hash::derive_generators("AAC_PEDERSEN_VECTOR_VNET_1".as_bytes(), 0);\n}\n' >> "$m"
  if check_no_free_label "$m"; then
    echo "free-label mutant unexpectedly passed"
    return 0
  fi
  echo "legacy free-label derivation is absent; mutant reintroducing it was rejected"
  return 41
}

check_constants_match_vector() {
  local vector="$1" main="$2" value
  jq -r '
    .basis.basis_commitment.field,
    (.generators[] | select(.label == "H" and .j == 0) | .point.x),
    (.generators[] | select(.label == "H" and .j == 0) | .point.y),
    (.generators[] | select(.label == "G" and .j == 0) | .point.x),
    (.generators[] | select(.label == "G" and .j == 0) | .point.y),
    (.generators[] | select(.label == "G" and .j == 1) | .point.x),
    (.generators[] | select(.label == "G" and .j == 1) | .point.y),
    (.generators[] | select(.label == "G" and .j == 2) | .point.x),
    (.generators[] | select(.label == "G" and .j == 2) | .point.y)
  ' "$vector" | while IFS= read -r value; do
    grep -Fq "$value" "$main" || { echo "missing vector value in circuit: $value"; exit 1; }
  done
}

constants_probe() {
  local corrupt="$WORK/PEDERSEN-VECTOR-1.corrupt.json"
  check_constants_match_vector "$VECTOR" "$VNET_MAIN" || { echo "positive vector constant match failed"; return 0; }
  cp "$VECTOR" "$corrupt"
  perl -0pi -e 's/4442116937809428038466015586910822967980340166078939661906387952790413686754/4442116937809428038466015586910822967980340166078939661906387952790413686755/' "$corrupt"
  if check_constants_match_vector "$corrupt" "$VNET_MAIN"; then
    echo "corrupt vector mutant unexpectedly matched circuit constants"
    return 0
  fi
  echo "circuit generator constants byte-match PEDERSEN-VECTOR-1.json; corrupt vector mutant rejected"
  return 42
}

check_public_surface() {
  local f="$1" readme="$2" prover="$3"
  perl -0e '$s=<>; exit($s =~ /fn main\(\s*profile_id_pub: pub Field,\s*basis_commitment_pub: pub Field,\s*transition_set_commitment_pub: pub Field,\s*commitment_set_commitment_pub: pub Field,\s*aggregate_opening_x_pub: pub Field,\s*aggregate_opening_y_pub: pub Field,\s*atom_count_pub: pub Field,\s*context_commitment_pub: pub Field,/s ? 0 : 1)' "$f" || return 1
  grep -Fq 'basis_commitment_pub == BASIS_COMMITMENT' "$f" || return 1
  grep -Fq 'profile_id_pub == PROFILE_ID' "$f" || return 1
  grep_prose "The circuit's public inputs are in the VNET/1 section 5 order" "$readme" >/dev/null || return 1
  grep -Fq 'basis_commitment_pub =' "$prover" || return 1
  grep -Fq 'commitment_set_commitment_pub =' "$prover" || return 1
}

public_surface_probe() {
  local m="$WORK/main-public-surface-mutant.nr"
  check_public_surface "$VNET_MAIN" "$VNET_README" "$VNET_PROVER" || { echo "positive public surface check failed"; return 0; }
  cp "$VNET_MAIN" "$m"
  perl -0pi -e 's/basis_commitment_pub: pub Field,/basis_commitment_witness: Field,/' "$m"
  if check_public_surface "$m" "$VNET_README" "$VNET_PROVER"; then
    echo "public-surface mutant unexpectedly passed"
    return 0
  fi
  echo "basis_commitment is in the VNET/1 public surface and asserted; mutant removing the public slot rejected"
  return 43
}

nargo_probe() {
  local nargo home mut out mut_out exec_out
  nargo="$(resolve_nargo19)" || { echo "nargo19 binary not available"; return 0; }
  home="$WORK/nargo-home"
  mkdir -p "$home"
  HOME="$home" "$nargo" --version > "$TRACES/t04-nargo-version.out" 2>&1 || return 0
  out="$TRACES/t04-nargo-test-positive.out"
  ( cd "$VNET_PKG" && HOME="$home" "$nargo" test --show-output ) > "$out" 2>&1 || { cat "$out"; return 0; }
  grep -Fq '13 tests passed' "$out" || { echo "nargo output did not report 13 tests passed"; return 0; }
  grep -Fq 'rejects_commitment_set_from_legacy_free_label_generators' "$out" || { echo "legacy-generator negative test did not run"; return 0; }
  exec_out="$TRACES/t04-nargo-execute-positive.out"
  ( cd "$VNET_PKG" && cp Prover.toml.example Prover.toml && HOME="$home" "$nargo" execute "$WORK/vnet-witness.gz" ) > "$exec_out" 2>&1 || { cat "$exec_out"; return 0; }

  mut="$WORK/provekit-vnet-mutant"
  cp -R "$VNET_PKG" "$mut"
  perl -0pi -e 's/assert\(H_X == 4442116937809428038466015586910822967980340166078939661906387952790413686754\)/assert(H_X == 4442116937809428038466015586910822967980340166078939661906387952790413686755)/' "$mut/src/main.nr"
  mut_out="$TRACES/t04-nargo-test-mutant.out"
  if ( cd "$mut" && HOME="$home" "$nargo" test --show-output ) > "$mut_out" 2>&1; then
    echo "failing-test mutant unexpectedly passed"
    return 0
  fi
  echo "beta.19 nargo tests and sample execute pass; failing-test mutant rejected"
  return 44
}

check_deferred_linkage_queue() {
  local q="$1"
  grep_prose 'VNET/1 ProveKit TRANSITION/1 journal linkage' "$q" >/dev/null || return 1
  grep_prose 'does not claim the full VNET/1 section 4.1 transition-link relation' "$q" >/dev/null || return 1
  grep_prose 'recomputing the referenced TRANSITION/1 `journal_commitment` in the VNET witness relation or verifying a companion link proof' "$q" >/dev/null || return 1
  grep_prose 'the full TRANSITION/1 journal linkage required by VNET/1 section 4.1 remains open above' "$q" >/dev/null || return 1
}

deferred_linkage_probe() {
  local m="$WORK/QUEUE-linkage-mutant.md"
  check_deferred_linkage_queue "$QUEUE" || { echo "positive deferred-linkage queue check failed"; return 0; }
  cp "$QUEUE" "$m"
  perl -0pi -e 's/VNET\/1 section 4\.1 transition-link relation/VNET\/1 transition-link relation/' "$m"
  if check_deferred_linkage_queue "$m"; then
    echo "deferred-linkage mutant unexpectedly passed"
    return 0
  fi
  echo "queue records the deferred VNET/1 section 4.1 linkage scope; mutant rejected"
  return 45
}

queue_formation_probe() {
  local q="$QUEUE" m="$WORK/QUEUE-duplicate-header.md" open_count resolved_count
  BOAT_ROOT="$STAGED" QUEUE_MD="$q" bash "$STAGED/tools/queue-lint.sh" > "$TRACES/t06-queue-lint.out" 2>&1 \
    || { echo "staged queue does not lint"; cat "$TRACES/t06-queue-lint.out"; return 0; }
  open_count="$(awk '$0 == "## Open" { c++ } END { print c + 0 }' "$q")"
  resolved_count="$(awk '$0 == "## Resolved" { c++ } END { print c + 0 }' "$q")"
  [[ "$open_count" == "1" && "$resolved_count" == "1" ]] || { echo "header count Open=$open_count Resolved=$resolved_count"; return 0; }
  grep_prose 'VNET/1 ProveKit circuit profile/public surface aligned' "$q" >/dev/null || { echo "cand-0094 resolved queue entry missing"; return 0; }
  cp "$q" "$m"
  printf '\n## Open\n' >> "$m"
  if BOAT_ROOT="$STAGED" QUEUE_MD="$m" bash "$STAGED/tools/queue-lint.sh" > "$TRACES/t06-queue-dup-header.out" 2>&1; then
    echo "duplicate-header queue mutant unexpectedly passed"
    return 0
  fi
  echo "queue lints with one Open/Resolved pair; duplicate-header mutant rejected"
  return 46
}

run_failing_probe \
  t01-free-label-absent \
  "legacy free-label generator derivation is absent from the circuit; mutant reintroducing it was rejected" \
  "free-label absence probe did not reject its mutant" \
  free_label_probe

run_failing_probe \
  t02-pinned-constants \
  "pinned circuit constants byte-match PEDERSEN-VECTOR-1.json; corrupt vector mutant rejected" \
  "pinned constants probe did not reject its corrupt-vector mutant" \
  constants_probe

run_failing_probe \
  t03-public-surface \
  "basis_commitment/profile_id are public and asserted in the VNET/1 section 5 surface; mutant rejected" \
  "public surface probe did not reject its mutant" \
  public_surface_probe

run_failing_probe \
  t04-nargo-tests \
  "beta.19 nargo tests and sample execute pass, including the legacy-generator negative test; failing-test mutant rejected" \
  "nargo probe did not reject its failing-test mutant" \
  nargo_probe

run_failing_probe \
  t05-deferred-linkage-queue \
  "queue records the explicitly deferred VNET/1 section 4.1 TRANSITION/1 linkage; mutant rejected" \
  "deferred-linkage queue probe did not reject its mutant" \
  deferred_linkage_probe

run_failing_probe \
  t06-queue-formation \
  "queue formation passes with one Open/Resolved pair; duplicate-header mutant rejected" \
  "queue formation probe did not reject its duplicate-header mutant" \
  queue_formation_probe

attest_tail "cand-0094 VNET circuit PEDERSEN-VECTOR/1 profile conformance"
