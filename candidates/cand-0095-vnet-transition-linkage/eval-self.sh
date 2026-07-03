#!/usr/bin/env bash
# eval-self.sh -- functional evidence for cand-0095.
#
# This evaluator stages the candidate landing, checks the VNET/1 section 4.1
# TRANSITION/1 journal linkage, runs the beta.19 package tests and example
# witness, and verifies that the cand-0094 queue deferral is resolved.
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

WORK="$(mktemp -d /private/tmp/aac-cand-0095.XXXXXX)"
STAGED="$WORK/root"
stage_root "$STAGED" || exit 1

VNET_PKG="$STAGED/world-app/provekit-vnet"
VNET_MAIN="$VNET_PKG/src/main.nr"
VNET_README="$VNET_PKG/README.md"
VNET_PROVER="$VNET_PKG/Prover.toml.example"
QUEUE="$STAGED/candidates/QUEUE.md"

resolve_nargo19() {
  local p
  for p in "${NARGO19_BIN:-}" "$ROOT/result/bin/nargo" "/nix/store/hgz7fp6br2721vh7c72bk0c9bwdz04ii-nargo-v1.0.0-beta.19/bin/nargo"; do
    [[ -n "$p" && -x "$p" ]] && { printf '%s\n' "$p"; return 0; }
  done
  return 1
}

check_tautology_absent() {
  local f="$1"
  ! grep -Fq 'context_commitment_pub == context_commitment_pub' "$f" || return 1
  grep -Fq 'context_commitment_pub == SAMPLE_CONTEXT_COMMITMENT' "$f" || return 1
  grep -Fq 'wrong VNET/1 context_commitment' "$f" || return 1
}

tautology_probe() {
  local m="$WORK/main-tautology-mutant.nr"
  check_tautology_absent "$VNET_MAIN" || { echo "positive tautology absence check failed"; return 0; }
  cp "$VNET_MAIN" "$m"
  perl -0pi -e 's/context_commitment_pub == SAMPLE_CONTEXT_COMMITMENT/context_commitment_pub == context_commitment_pub/' "$m"
  if check_tautology_absent "$m"; then
    echo "tautology mutant unexpectedly passed"
    return 0
  fi
  echo "context self-tautology is absent and the demo context is asserted; tautology mutant rejected"
  return 41
}

check_linkage_constraint() {
  local f="$1" readme="$2" prover="$3"
  grep -Fq 'global TAG_JOURNAL: Field = 3;' "$f" || return 1
  grep -Fq 'fn transition_journal_commitment(' "$f" || return 1
  grep -Fq 'hash::hash([TAG_JOURNAL, 0])' "$f" || return 1
  grep -Fq 'transition_journal_commitment(accounts, journal_debits, journal_credits) == journal_commitment' "$f" || return 1
  grep -Fq 'TRANSITION/1 journal commitment does not bind atom vector' "$f" || return 1
  grep -Fq 'atom debit vector is not derived from TRANSITION/1 journal' "$f" || return 1
  grep -Fq 'transition_accounts = ' "$prover" || return 1
  grep -Fq 'transition_debits = ' "$prover" || return 1
  grep -Fq 'transition_credits = ' "$prover" || return 1
  grep_prose 'This is the VNET/1 section 4.1 in-circuit recomputation path, not the companion-link-proof path' "$readme" >/dev/null || return 1
  grep_prose 'canonical TRANSITION/1 journal commitment from `circuits/ledger` / `circuits/transition`' "$readme" >/dev/null || return 1
}

linkage_constraint_probe() {
  local m="$WORK/main-linkage-mutant.nr"
  check_linkage_constraint "$VNET_MAIN" "$VNET_README" "$VNET_PROVER" || { echo "positive linkage constraint check failed"; return 0; }
  cp "$VNET_MAIN" "$m"
  perl -0pi -e 's/transition_journal_commitment\(accounts, journal_debits, journal_credits\) == journal_commitment/journal_commitment == journal_commitment/' "$m"
  if check_linkage_constraint "$m" "$VNET_README" "$VNET_PROVER"; then
    echo "linkage mutant unexpectedly passed"
    return 0
  fi
  echo "VNET/1 section 4.1 linkage constraint is present; mutant replacing it with self-equality rejected"
  return 42
}

nargo_probe() {
  local nargo home out exec_out mut mut_out
  nargo="$(resolve_nargo19)" || { echo "nargo19 binary not available"; return 0; }
  home="$WORK/nargo-home"
  mkdir -p "$home"
  HOME="$home" "$nargo" --version > "$TRACES/t03-nargo-version.out" 2>&1 || return 0

  out="$TRACES/t03-nargo-test-positive.out"
  if ! ( cd "$VNET_PKG" && HOME="$home" "$nargo" test --show-output ) > "$out" 2>&1; then
    cat "$out"
    return 0
  fi
  grep -Fq '14 tests passed' "$out" || { echo "nargo output did not report 14 tests passed"; return 0; }
  grep -Fq 'rejects_mismatched_transition_link' "$out" || { echo "linkage negative test did not run"; return 0; }
  grep -Fq 'rejects_wrong_context_commitment' "$out" || { echo "context negative test did not run"; return 0; }

  exec_out="$TRACES/t03-nargo-execute-positive.out"
  if ! ( cd "$VNET_PKG" && cp Prover.toml.example Prover.toml && HOME="$home" "$nargo" execute "$WORK/vnet-witness.gz" ) > "$exec_out" 2>&1; then
    cat "$exec_out"
    return 0
  fi

  mut="$WORK/provekit-vnet-linkage-mutant"
  cp -R "$VNET_PKG" "$mut"
  perl -0pi -e 's/transition_journal_commitment\(accounts, journal_debits, journal_credits\) == journal_commitment/journal_commitment == journal_commitment/' "$mut/src/main.nr"
  mut_out="$TRACES/t03-nargo-test-mutant.out"
  if ( cd "$mut" && HOME="$home" "$nargo" test --show-output ) > "$mut_out" 2>&1; then
    echo "linkage-removal nargo mutant unexpectedly passed"
    return 0
  fi
  grep -Fq 'rejects_mismatched_transition_link' "$mut_out" || { echo "mutant failed for an unexpected reason"; return 0; }
  echo "beta.19 nargo tests and linked example execute pass; linkage-removal mutant rejected"
  return 43
}

check_queue_resolved() {
  local q="$1"
  BOAT_ROOT="$STAGED" QUEUE_MD="$q" bash "$STAGED/tools/queue-lint.sh" >/dev/null 2>&1 || return 1
  ! grep_prose '[open] (codex cand-0094-vnet-circuit-profile-conformance, 2026-07-03) **VNET/1 ProveKit TRANSITION/1 journal linkage.' "$q" >/dev/null || return 1
  grep_prose '[resolved cand-0095-vnet-transition-linkage, 2026-07-03] **VNET/1 ProveKit TRANSITION/1 journal linkage.' "$q" >/dev/null || return 1
  grep_prose 'choosing the in-circuit recomputation path from VNET/1 section 4.1' "$q" >/dev/null || return 1
  grep_prose 'The former `context_commitment_pub == context_commitment_pub` ABI-slot tautology is replaced by a demo context assertion against `9001`' "$q" >/dev/null || return 1
  ! grep_prose 'the full TRANSITION/1 journal linkage required by VNET/1 section 4.1 remains open above' "$q" >/dev/null || return 1
}

queue_probe() {
  local m="$WORK/QUEUE-duplicate-header.md" open_count resolved_count
  check_queue_resolved "$QUEUE" || { echo "positive queue resolution check failed"; return 0; }
  open_count="$(awk '$0 == "## Open" { c++ } END { print c + 0 }' "$QUEUE")"
  resolved_count="$(awk '$0 == "## Resolved" { c++ } END { print c + 0 }' "$QUEUE")"
  [[ "$open_count" == "1" && "$resolved_count" == "1" ]] || { echo "header count Open=$open_count Resolved=$resolved_count"; return 0; }
  cp "$QUEUE" "$m"
  printf '\n## Open\n' >> "$m"
  if BOAT_ROOT="$STAGED" QUEUE_MD="$m" bash "$STAGED/tools/queue-lint.sh" > "$TRACES/t04-queue-dup-header.out" 2>&1; then
    echo "duplicate-header queue mutant unexpectedly passed"
    return 0
  fi
  echo "queue resolves the cand-0094 linkage deferral; duplicate-header mutant rejected"
  return 44
}

run_failing_probe \
  t01-tautology-absent \
  "context self-tautology is absent and replaced by a demo context assertion; mutant reintroducing the tautology was rejected" \
  "tautology absence probe did not reject its mutant" \
  tautology_probe

run_failing_probe \
  t02-linkage-constraint \
  "VNET/1 section 4.1 linkage recomputes the canonical TRANSITION/1 journal commitment and derives atom vectors from the same rows; mutant rejected" \
  "linkage constraint probe did not reject its mutant" \
  linkage_constraint_probe

run_failing_probe \
  t03-nargo-tests \
  "beta.19 nargo tests and linked example execute pass; linkage-removal mutant rejected" \
  "nargo probe did not reject its failing mutant" \
  nargo_probe

run_failing_probe \
  t04-queue-resolved \
  "queue resolves the cand-0094 VNET/1 section 4.1 linkage deferral; duplicate-header mutant rejected" \
  "queue resolution probe did not reject its duplicate-header mutant" \
  queue_probe

attest_tail "cand-0095 VNET/1 section 4.1 TRANSITION/1 journal linkage"
