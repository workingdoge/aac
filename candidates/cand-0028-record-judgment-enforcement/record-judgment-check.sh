#!/usr/bin/env bash
set -u

# Record-judgment fixture checker (premath.record-judgments.v0).
# Candidate cand-0035-record-judgments; destination on admission:
# tools/record-judgment-check.sh, with fixtures under
# sites/premath/fixtures/record-*.md.
#
# Pattern follows cwf-comprehension-check.sh / sigpi-judgment-check.sh:
# required-text verification with failure-delta result reporting. This
# is textual conformance (L0) — it pins the statement of each record
# judgment and its worked pass/fail cases; it does not read live store
# records (model-layer work, declared in the statement Boundary).

ROOT="${BOAT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
FIXTURE_DIR="${RJ_FIXTURE_DIR:-$ROOT/sites/premath/fixtures}"
STATEMENT="${RJ_STATEMENT:-$ROOT/sites/premath/statements/record-judgments-v0.md}"
failures=0

usage() {
  printf 'usage: %s [--all] FIXTURE_MD [FIXTURE_MD...]\n' "$(basename "$0")" >&2
}

error() {
  printf 'record-judgment-check: %s\n' "$*" >&2
  failures=$((failures + 1))
}

require_contains() {
  local file="$1"
  local needle="$2"

  if ! grep -Fq "$needle" "$file"; then
    error "$(basename "$file") missing required text: $needle"
  fi
}

print_result() {
  local failures_before="$1"
  if [[ "$failures" -gt "$failures_before" ]]; then
    printf '  result: rejected\n'
  else
    printf '  result: accepted\n'
  fi
}

check_statement() {
  local file="$1"
  local failures_before="$failures"

  printf 'statement: %s\n' "$(basename "$file")"
  [[ -f "$file" ]] || { error "statement missing: $file"; print_result "$failures_before"; return; }
  require_contains "$file" 'Statement id: `premath.record-judgments.v0`'
  require_contains "$file" 'Law: RJ-1.1'
  require_contains "$file" 'Law: RJ-1.2'
  require_contains "$file" 'Law: RJ-1.3'
  require_contains "$file" 'Law: RJ-1.4'
  require_contains "$file" 'Law: RJ-1.5'
  require_contains "$file" 'Law: RJ-1.6'
  require_contains "$file" 'adjoint support is ABSENT'
  require_contains "$file" 'never executable authority'
  require_contains "$file" 'record-formation-incomplete'
  require_contains "$file" 'sigma-missing-witness'
  require_contains "$file" 'verifier_contract_violation'
  require_contains "$file" 'vocabulary-atom-failure'
  print_result "$failures_before"
}

check_meta_pass() {
  local file="$1"
  local failures_before="$failures"
  require_contains "$file" 'Fixture id: `premath.fixture.record-meta-telescope-pass.v0`'
  require_contains "$file" 'status : StatusVocab'
  require_contains "$file" 'premises_present: candidate_id, cycle_id, opened, intent, status'
  require_contains "$file" 'expected_result: accepted'
  print_result "$failures_before"
}

check_meta_fail() {
  local file="$1"
  local failures_before="$failures"
  require_contains "$file" 'Fixture id: `premath.fixture.record-meta-telescope-fail.v0`'
  require_contains "$file" 'missing_premise: status'
  require_contains "$file" 'expected_result: rejected'
  require_contains "$file" 'expected_failure_class: record-formation-incomplete'
  require_contains "$file" 'distinct_from: comprehension-missing-evidence'
  print_result "$failures_before"
}

check_scores_pass() {
  local file="$1"
  local failures_before="$failures"
  require_contains "$file" 'Fixture id: `premath.fixture.record-scores-sigma-pass.v0`'
  require_contains "$file" 'sigma_second_component: attestation witness'
  require_contains "$file" 'the serialized packet does not create authority'
  require_contains "$file" 'expected_result: accepted'
  print_result "$failures_before"
}

check_scores_fail() {
  local file="$1"
  local failures_before="$failures"
  require_contains "$file" 'Fixture id: `premath.fixture.record-scores-sigma-fail.v0`'
  require_contains "$file" 'sigma_second_component: ABSENT'
  require_contains "$file" 'expected_result: rejected'
  require_contains "$file" 'expected_failure_class: sigma-missing-witness'
  print_result "$failures_before"
}

check_queue_pass() {
  local file="$1"
  local failures_before="$failures"
  require_contains "$file" 'Fixture id: `premath.fixture.record-queue-checking-mode-pass.v0`'
  require_contains "$file" 'mode: checking (BIDIR-4.4'
  require_contains "$file" 'expected_result: accepted'
  print_result "$failures_before"
}

check_queue_fail() {
  local file="$1"
  local failures_before="$failures"
  require_contains "$file" 'Fixture id: `premath.fixture.record-queue-checking-mode-fail.v0`'
  require_contains "$file" 'expected_result: rejected'
  require_contains "$file" 'expected_failure_class: verifier_contract_violation'
  print_result "$failures_before"
}

check_landing_pass() {
  local file="$1"
  local failures_before="$failures"
  require_contains "$file" 'Fixture id: `premath.fixture.record-landing-receipt-pass.v0`'
  require_contains "$file" 'the receipt is the variable q'
  require_contains "$file" 'rollback is the projection p'
  require_contains "$file" 'expected_result: accepted'
  print_result "$failures_before"
}

check_vocab_fail() {
  local file="$1"
  local failures_before="$failures"
  require_contains "$file" 'Fixture id: `premath.fixture.record-vocab-atom-fail.v0`'
  require_contains "$file" 'not a sum type'
  require_contains "$file" 'expected_result: rejected'
  require_contains "$file" 'expected_failure_class: vocabulary-atom-failure'
  print_result "$failures_before"
}

check_fixture() {
  local file="$1"
  printf 'fixture: %s\n' "$(basename "$file")"
  [[ -f "$file" ]] || { error "fixture missing: $file"; return; }
  case "$(basename "$file")" in
    record-meta-telescope-pass-v0.md) check_meta_pass "$file" ;;
    record-meta-telescope-fail-v0.md) check_meta_fail "$file" ;;
    record-scores-sigma-pass-v0.md) check_scores_pass "$file" ;;
    record-scores-sigma-fail-v0.md) check_scores_fail "$file" ;;
    record-queue-checking-mode-pass-v0.md) check_queue_pass "$file" ;;
    record-queue-checking-mode-fail-v0.md) check_queue_fail "$file" ;;
    record-landing-receipt-pass-v0.md) check_landing_pass "$file" ;;
    record-vocab-atom-fail-v0.md) check_vocab_fail "$file" ;;
    *) error "unknown record fixture: $(basename "$file")" ;;
  esac
}

ALL_FIXTURES=(
  record-meta-telescope-pass-v0.md
  record-meta-telescope-fail-v0.md
  record-scores-sigma-pass-v0.md
  record-scores-sigma-fail-v0.md
  record-queue-checking-mode-pass-v0.md
  record-queue-checking-mode-fail-v0.md
  record-landing-receipt-pass-v0.md
  record-vocab-atom-fail-v0.md
)

if [[ "$#" -eq 0 ]]; then
  usage
  exit 64
fi

if [[ "$1" == "--all" ]]; then
  check_statement "$STATEMENT"
  for f in "${ALL_FIXTURES[@]}"; do
    check_fixture "$FIXTURE_DIR/$f"
  done
else
  for f in "$@"; do
    check_fixture "$f"
  done
fi

if [[ "$failures" -gt 0 ]]; then
  printf 'record-judgment-check: %s failure(s)\n' "$failures" >&2
  exit 1
fi
printf 'record-judgment-check: ok\n'
