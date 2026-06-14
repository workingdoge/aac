# cand-0028-record-judgment-enforcement

Intent: turn on a law aac already thinks it enforces. aac's
`tools/eval/evaluate-landed.sh:207` enrolls `run_suite record-judgments`,
guarded by `[[ -f tools/record-judgment-check.sh ]]`. aac carries the
record-judgments STATEMENT (`sites/premath/statements/record-judgments-v0.md`)
but NOT the checker or its fixtures — so the guard is false, the member is
silently skipped, and `premath.record-judgments.v0` has been unenforced through
aac's entire candidate history (up to cand-0027). This candidate ships the
checker + its exact 8-fixture closure so the guard flips true and aac enforces
record-formation exactly as the boat source does.

## Why now

boat completed the same fix upstream (the export-course conditional-membership
footgun: a checker that does not travel is absent-not-failing, so suites stay
green while enforcement quietly vanishes). aac is the living instance of that
footgun. Propagating it through aac's own loop is the governed way — aac is
sovereign; the kernel does not get pushed into it, it is adopted as a candidate.

## Cargo (verbatim from the boat kernel, ROOT-relative)

- `record-judgment-check.sh` → `tools/record-judgment-check.sh` (attested
  upstream; uses `$ROOT/sites/premath/...`, so it runs identically in aac).
- 8 fixtures `fixtures/record-*.md` → `sites/premath/fixtures/record-*.md` —
  the checker's exact `ALL_FIXTURES` closure (meta-telescope pass/fail, scores-
  sigma pass/fail, queue-checking-mode pass/fail, landing-receipt-pass,
  vocab-atom-fail). aac's statement is byte-identical to boat's, so the
  checker's `check_statement` is satisfied.
- `export-manifest.tsv` → `tools/schemas/export-manifest.tsv`: **+9 lines, -0**
  (checker grouped with the enforcers, fixtures with the site fixtures), so if
  aac ever births a sub-instance the law travels whole.

## Evaluation (eval-self.sh, attested)

t01 manifest grammar intact and every one of the 9 new entries is covered by the
LANDING map (so post-land the manifest is honest — names only files this
candidate ships); t02 the shipped checker + 8 fixtures RUN green: `--all`
against aac's live statement returns rc=0 (the law is enforceable in aac); t03
the guard footgun — `tools/record-judgment-check.sh` is currently ABSENT in aac
so the enrolled record-judgments member is skipped (witnessed); this candidate's
LANDING provides it, flipping the guard true; t04 abroad-enforcement mutant —
corrupting one shipped fixture makes `--all` FAIL (enforcement is real, not
vacuous); t05 deltas confined and additive (manifest -0/+9, statement not
re-added, `tools/loop` untouched).

## Tier

LANDING touches `tools/` (the checker + `tools/schemas/export-manifest.tsv`) —
an independent REVIEW.md is required.
