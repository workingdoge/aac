#!/usr/bin/env bash
set -euo pipefail

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"

source "$ROOT/tools/eval/eval-lib.sh"
eval_init "$CAND_DIR" "$ROOT"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/cand-0091-eval.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

STAGED="$WORK/root"
stage_root "$STAGED" --apply-landing --include-candidate
QUEUE="$STAGED/candidates/QUEUE.md"

check_second_posting_edit() {
  local q="${1:-$QUEUE}" ok=0
  grep_prose "SECOND POSTING PROGRAM TRIAGE" "$q" >/dev/null || ok=1
  grep_prose 'satisfied by local lineage `cand-0039-second-posting-program`' "$q" >/dev/null || ok=1
  grep_prose "circuits/event-bom-receipt/src/main.nr" "$q" >/dev/null || ok=1
  grep_prose 'The second-posting-program validation is resolved by `cand-0039-second-posting-program`' "$q" >/dev/null || ok=1
  if grep_prose "**Second posting program** (validates the cand-0037 EVENT harness interface)" "$q" >/dev/null; then ok=1; fi
  return "$ok"
}

check_provekit_edit() {
  local q="${1:-$QUEUE}" ok=0
  grep_prose "PROVEKIT NIX-REPRO TRIAGE" "$q" >/dev/null || ok=1
  grep_prose 'superseded by remote `cand-0050-provekit-flake-import`' "$q" >/dev/null || ok=1
  grep_prose "cargoExtraArgs = \"--offline -p provekit-cli\"" "$q" >/dev/null || ok=1
  grep_prose 'repairs the vendored `noirc_driver`/`noir_stdlib` embed paths' "$q" >/dev/null || ok=1
  if grep_prose '`nix build .#provekit` (crane attempt) is BLOCKED' "$q" >/dev/null; then ok=1; fi
  return "$ok"
}

check_vnet_edit() {
  local q="${1:-$QUEUE}" ok=0
  grep_prose '**VNET/1 reference circuit (scope corrected after `cand-0052-provekit-vnet-circuit`).**' "$q" >/dev/null || ok=1
  grep_prose "The remaining scope is to align the circuit ABI, generator binding, and TRANSITION/1 journal linkage" "$q" >/dev/null || ok=1
  grep_prose 'is demo-shaped (`N_ATOMS = 2`, `N_BASIS = 3`)' "$q" >/dev/null || ok=1
  grep_prose "basis-bound, verifier-determined generator derivation/pinning" "$q" >/dev/null || ok=1
  grep_prose 'commitment_set_commitment`, `atom_count`, and policy/context checks' "$q" >/dev/null || ok=1
  if grep_prose "landing it as a boat candidate (conformance vectors + attested eval) is the governance step" "$q" >/dev/null; then ok=1; fi
  return "$ok"
}

check_fundraise_edit() {
  local q="${1:-$QUEUE}" ok=0
  grep_prose "Fundraise/BCC runtime is proof-harness-orphaned" "$q" >/dev/null || ok=1
  grep_prose 'imports `bcc-runtime` and `vnet-runtime` JS reference verifiers and never touches `circuits/event-harness`' "$q" >/dev/null || ok=1
  grep_prose "whether/how fundraise settlement events become posting programs discharged through the Noir harness" "$q" >/dev/null || ok=1
  grep_prose "or record why the JS runtime remains a permanently separate demo surface" "$q" >/dev/null || ok=1
  return "$ok"
}

check_queue_lint() {
  local q="${1:-$QUEUE}"
  QUEUE_MD="$q" bash "$STAGED/tools/queue-lint.sh" >/dev/null
}

check_header_cardinality() {
  local q="${1:-$QUEUE}" ok=0
  [[ "$(awk '$0 == "## Open" { c++ } END { print c + 0 }' "$q")" -eq 1 ]] || ok=1
  [[ "$(awk '$0 == "## Resolved" { c++ } END { print c + 0 }' "$q")" -eq 1 ]] || ok=1
  return "$ok"
}

check_landing_scope() {
  local ok=0
  grep -qx $'seeds/candidates/QUEUE.md\tcandidates/QUEUE.md' "$CAND_DIR/LANDING" || ok=1
  [[ "$(find "$CAND_DIR/seeds" -type f | sed "s#^$CAND_DIR/##" | sort)" == "seeds/candidates/QUEUE.md" ]] || ok=1
  return "$ok"
}

mkdir -p "$WORK/mutants"
MUT_SECOND="$WORK/mutants/missing-second-posting.md"
MUT_PROVEKIT="$WORK/mutants/missing-provekit.md"
MUT_VNET="$WORK/mutants/missing-vnet-scope.md"
MUT_FUNDRAISE="$WORK/mutants/missing-fundraise.md"
MUT_DUP_OPEN="$WORK/mutants/duplicate-open.md"
MUT_LANDING="$WORK/mutants/LANDING"

cp "$QUEUE" "$MUT_SECOND"
perl -0pi -e 's/SECOND POSTING PROGRAM TRIAGE/SECOND POSTING PROGRAM MUTATED/' "$MUT_SECOND"

cp "$QUEUE" "$MUT_PROVEKIT"
perl -0pi -e 's/PROVEKIT NIX-REPRO TRIAGE/PROVEKIT MUTATED TRIAGE/' "$MUT_PROVEKIT"

cp "$QUEUE" "$MUT_VNET"
perl -0pi -e 's/basis-bound, verifier-determined generator derivation\/pinning/basis binding omitted/' "$MUT_VNET"

cp "$QUEUE" "$MUT_FUNDRAISE"
perl -0pi -e 's/Fundraise\/BCC runtime is proof-harness-orphaned/Fundraise BCC runtime mutated/' "$MUT_FUNDRAISE"

awk '{ print } $0 == "## Open" { print "## Open" }' "$QUEUE" > "$MUT_DUP_OPEN"
cp "$CAND_DIR/LANDING" "$MUT_LANDING"
printf 'seeds/extra.txt\tcandidates/extra.txt\n' >> "$MUT_LANDING"

check_bad_landing_scope() {
  local ok=0
  grep -qx $'seeds/candidates/QUEUE.md\tcandidates/QUEUE.md' "$MUT_LANDING" || ok=1
  [[ "$(wc -l < "$MUT_LANDING" | tr -d ' ')" -eq 1 ]] || ok=1
  return "$ok"
}

run_probe t01-second-posting-edit \
  "second posting open entry resolved with candidate/evidence citations" \
  "second posting triage prose missing or stale open row still present" \
  check_second_posting_edit "$QUEUE" || true
run_failing_probe t01-second-posting-mutant \
  "second posting mutant rejected" \
  "second posting mutant was not rejected" \
  check_second_posting_edit "$MUT_SECOND" || true

run_probe t02-provekit-edit \
  "ProveKit nix-repro entry resolved against cand-0050 evidence" \
  "ProveKit nix-repro triage prose missing or stale blocked row still present" \
  check_provekit_edit "$QUEUE" || true
run_failing_probe t02-provekit-mutant \
  "ProveKit mutant rejected" \
  "ProveKit mutant was not rejected" \
  check_provekit_edit "$MUT_PROVEKIT" || true

run_probe t03-vnet-edit \
  "VNET reference circuit row rewritten to corrected remaining scope" \
  "VNET rewrite prose missing or stale governance-step row still present" \
  check_vnet_edit "$QUEUE" || true
run_failing_probe t03-vnet-mutant \
  "VNET mutant rejected" \
  "VNET mutant was not rejected" \
  check_vnet_edit "$MUT_VNET" || true

run_probe t04-fundraise-edit \
  "fundraise/BCC proof-harness orphan entry added" \
  "fundraise/BCC integration-arc entry missing" \
  check_fundraise_edit "$QUEUE" || true
run_failing_probe t04-fundraise-mutant \
  "fundraise mutant rejected" \
  "fundraise mutant was not rejected" \
  check_fundraise_edit "$MUT_FUNDRAISE" || true

run_probe t05-queue-lint \
  "staged queue passes queue-lint" \
  "staged queue failed queue-lint" \
  check_queue_lint "$QUEUE" || true
run_failing_probe t05-queue-lint-mutant \
  "duplicate-header queue mutant rejected by queue-lint" \
  "duplicate-header queue mutant was not rejected by queue-lint" \
  check_queue_lint "$MUT_DUP_OPEN" || true

run_probe t06-header-cardinality \
  "staged queue has exactly one Open and one Resolved header" \
  "staged queue header cardinality is wrong" \
  check_header_cardinality "$QUEUE" || true
run_failing_probe t06-header-cardinality-mutant \
  "duplicate-header mutant rejected by cardinality probe" \
  "duplicate-header mutant passed cardinality probe" \
  check_header_cardinality "$MUT_DUP_OPEN" || true

run_probe t07-landing-scope \
  "landing scope is seeds/candidates/QUEUE.md only" \
  "landing scope is not limited to the queue seed" \
  check_landing_scope || true
run_failing_probe t07-landing-scope-mutant \
  "extra landing-row mutant rejected" \
  "extra landing-row mutant passed scope probe" \
  check_bad_landing_scope || true

attest_tail "cand-0091 queue staleness triage: resolve/rewrite stale queue entries"
