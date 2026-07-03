#!/usr/bin/env bash
# eval-self.sh -- blocker evidence for cand-0092-vnet-profile-alignment.
#
# The task is soundness-critical: PEDERSEN-VECTOR/1 section 2 requires
# basis-bound, verifier-redetermined, pinned Grumpkin generators. The available
# source only gives a symbolic derivation and the repo has no executable
# PEDERSEN-VECTOR/1 Grumpkin vector/reference generator, so this candidate stops
# at a queue obstruction instead of inventing generator constants.
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

WORK="$(mktemp -d /private/tmp/aac-cand-0092.XXXXXX)"
STAGED="$WORK/root"
stage_root "$STAGED" || exit 1

assert_profile_derivation_text_present() {
  local profile="$1"
  grep_prose 'seed(label, j) = Poseidon2( "aac/vnet/1", profile_id, basis_commitment, basis_type_id_j, label, j )' "$profile" >/dev/null \
    || { echo "unexpected: PEDERSEN-VECTOR/1 section 2 derivation text is missing"; return 1; }
  grep_prose 'Generators are verifier-determined, not prover-chosen' "$profile" >/dev/null \
    || { echo "unexpected: verifier-determined generator rule is missing"; return 1; }
}

profile_generator_gap_probe() {
  local root="$1" profile vector_dir
  profile="$root/sites/ledger/specs/profiles/PEDERSEN-VECTOR-1.md"
  vector_dir="$root/sites/ledger/specs/profiles/vectors"
  [[ -f "$profile" ]] || { echo "unexpected: profile missing"; return 0; }
  assert_profile_derivation_text_present "$profile" || return 0
  if find "$vector_dir" -maxdepth 1 -type f \( -iname '*pedersen-vector*.json' -o -iname '*pedersen*.json' \) | grep -q .; then
    echo "unexpected: executable PEDERSEN-VECTOR/1 Grumpkin vector already exists"
    return 0
  fi
  echo "blocked: no executable PEDERSEN-VECTOR/1 Grumpkin vector/reference generator pins the section 2 derivation"
  return 41
}

assert_aligned_generator_binding() {
  local f="$1" bad=0
  grep -Fq 'std::hash::derive_generators("AAC_PEDERSEN_VECTOR_VNET_1".as_bytes(), 0)' "$f" \
    && { echo "old free-label derive_generators path is still present"; bad=1; }
  grep -Fq 'basis_commitment' "$f" || { echo "basis_commitment is not bound into generator selection"; bad=1; }
  grep -Fq 'basis_type_id' "$f" || { echo "basis_type_id_j is not bound into generator selection"; bad=1; }
  grep -Fq 'PEDERSEN_VECTOR_GENERATORS' "$f" || { echo "pinned generator constants are absent"; bad=1; }
  [[ "$bad" -eq 0 ]]
}

old_free_label_rejection_probe() {
  local m="$WORK/old-free-label-main.nr"
  {
    printf 'fn generators() {\n'
    printf '  std::hash::derive_generators("AAC_PEDERSEN_VECTOR_VNET_1".as_bytes(), 0);\n'
    printf '}\n'
  } > "$m"
  assert_aligned_generator_binding "$m"
}

abi_surface_probe() {
  local root="$1" spec main bad=0
  spec="$root/sites/ledger/specs/applications/VNET-1.md"
  main="$root/world-app/provekit-vnet/src/main.nr"
  [[ -f "$spec" && -f "$main" ]] || { echo "unexpected: VNET spec or circuit source missing"; return 0; }
  grep_prose '| 0 | `profile_id` | Pedersen vector profile; `unconstrained` but policy-bound |' "$spec" >/dev/null \
    || { echo "unexpected: VNET/1 public ABI table missing profile_id slot"; return 0; }
  for slot in \
    'profile_id_pub: pub Field' \
    'basis_commitment_pub: pub Field' \
    'transition_set_commitment_pub: pub Field' \
    'commitment_set_commitment_pub: pub Field' \
    'aggregate_opening_x_pub: pub Field' \
    'aggregate_opening_y_pub: pub Field' \
    'atom_count_pub: pub Field' \
    'context_commitment_pub: pub Field'; do
    grep -Fq "$slot" "$main" || { echo "missing VNET/1 ABI slot: $slot"; bad=1; }
  done
  grep -Fq 'journal_commitments_pub: pub [Field; N_ATOMS]' "$main" \
    && { echo "demo-only public journal array remains outside VNET/1 section 5 ABI"; bad=1; }
  grep -Fq 'generator_set_id_pub: pub Field' "$main" \
    && { echo "demo generator_set_id_pub remains instead of profile_id + basis_commitment policy binding"; bad=1; }
  [[ "$bad" -eq 0 ]]
}

conformance_vector_probe() {
  local root="$1" vector_dir
  vector_dir="$root/sites/ledger/specs/profiles/vectors"
  [[ -d "$vector_dir" ]] || { echo "unexpected: profile vector directory missing"; return 0; }
  [[ -f "$vector_dir/VNET-BN254-G1-1.json" ]] \
    || { echo "unexpected: existing BN254 vector disappeared"; return 0; }
  if find "$vector_dir" -maxdepth 1 -type f \( -iname '*pedersen-vector*.json' -o -iname '*pedersen*.json' \) | grep -q .; then
    echo "unexpected: PEDERSEN-VECTOR/1 vectors now exist"
    return 0
  fi
  echo "blocked: only VNET-BN254-G1-1.json exists; no PEDERSEN-VECTOR/1 Grumpkin expected commitments are available"
  return 42
}

readme_citation_probe() {
  local readme="$1" bad=0
  [[ -f "$readme" ]] || { echo "unexpected: README missing"; return 0; }
  grep_prose 'PEDERSEN-VECTOR/1 section 2' "$readme" >/dev/null \
    || { echo "README does not cite the implemented generator clause"; bad=1; }
  grep_prose 'VNET/1 section 5' "$readme" >/dev/null \
    || { echo "README does not cite the public ABI clause"; bad=1; }
  grep_prose 'VNET/1 section 6' "$readme" >/dev/null \
    || { echo "README does not cite the verifier policy clause"; bad=1; }
  [[ "$bad" -eq 0 ]]
}

queue_update_probe() {
  local root="$1" q m open_count resolved_count
  q="$root/candidates/QUEUE.md"
  m="$WORK/QUEUE-duplicate-open.md"
  [[ -f "$q" ]] || { echo "unexpected: staged queue missing"; return 0; }
  BOAT_ROOT="$root" QUEUE_MD="$q" bash "$root/tools/queue-lint.sh" > "$TRACES/t06-queue-positive.txt" 2>&1 \
    || { echo "unexpected: staged queue update does not lint"; cat "$TRACES/t06-queue-positive.txt"; return 0; }
  grep_prose 'PEDERSEN-VECTOR/1 ProveKit generator pinning is underspecified' "$q" > "$TRACES/t06-queue-gap.txt" 2>&1 \
    || { echo "unexpected: gap queue entry missing"; return 0; }
  open_count="$(awk '$0 == "## Open" { c++ } END { print c + 0 }' "$q")"
  resolved_count="$(awk '$0 == "## Resolved" { c++ } END { print c + 0 }' "$q")"
  [[ "$open_count" == "1" && "$resolved_count" == "1" ]] \
    || { echo "unexpected: queue header pair count is Open=$open_count Resolved=$resolved_count"; return 0; }
  cp "$q" "$m"
  printf '\n## Open\n' >> "$m"
  BOAT_ROOT="$root" QUEUE_MD="$m" bash "$root/tools/queue-lint.sh"
}

run_failing_probe \
  t01-profile-generator-gap \
  "PEDERSEN-VECTOR/1 section 2 is present, but executable Grumpkin generator vectors/reference code are absent and block safe pinning" \
  "profile generator gap probe did not fail on the missing executable pinning surface" \
  profile_generator_gap_probe "$STAGED"

run_failing_probe \
  t02-old-free-label-rejected \
  "old free-label derive_generators path is rejected by the alignment checker" \
  "old free-label derivation unexpectedly passed the alignment checker" \
  old_free_label_rejection_probe

run_failing_probe \
  t03-vnet-abi-gap \
  "live ProveKit VNET circuit is rejected against the VNET/1 section 5 public ABI" \
  "VNET/1 ABI gap probe unexpectedly passed" \
  abi_surface_probe "$STAGED"

run_failing_probe \
  t04-conformance-vector-gap \
  "PEDERSEN-VECTOR/1 Grumpkin conformance vectors are absent; only the BN254 profile vector is present" \
  "conformance vector gap probe unexpectedly passed" \
  conformance_vector_probe "$STAGED"

run_failing_probe \
  t05-readme-citation-gap \
  "README citation probe rejects the current ProveKit package documentation as not clause-specific enough for a full profile claim" \
  "README citation probe unexpectedly passed" \
  readme_citation_probe "$STAGED/world-app/provekit-vnet/README.md"

run_failing_probe \
  t06-queue-update-mutant \
  "staged queue update lints with one Open/Resolved header pair; duplicate-header mutant is rejected" \
  "queue update mutant unexpectedly passed queue-lint" \
  queue_update_probe "$STAGED"

attest_tail "Record the cand-0092 PEDERSEN-VECTOR/1 ProveKit generator-pinning blocker instead of silently choosing soundness-critical generators."
