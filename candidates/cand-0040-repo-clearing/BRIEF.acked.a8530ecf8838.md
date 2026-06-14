# Threshold Brief: cand-0040-repo-clearing

Generated: 2026-06-14T05:48:52Z
Status: validated
Intent: Add the first REAL clearing instrument on the EVENT/1 harness: a FICC/GSD repurchase agreement (repo), modeled as the clearing kernel sees it. New app lib circuits/repo compiles BOTH legs -- OPEN (borrower delivers collateral, receives principal cash) and CLOSE (borrower returns principal+repo-interest, lender returns collateral) -- each a per-dimension zero-account over basis B=2 {cash, security par}: a leg merely TRANSFERS cash one way and securities the other, so balance is a theorem for any quantities. The repo INTEREST is the cash DELTA between legs (close cash = open cash + interest), not a within-leg imbalance. Two bins event-repo-open + event-repo-close prove each leg end-to-end via the IDENTICAL discharge call (distinct R1 tags 127/128). DOCTRINE: collateral par and cash cents are SEPARATE incommensurable dimensions; the haircut/valuation (collateral value = principal/(1-haircut)) is a pricing relationship OUTSIDE the zero-account -- vector Pacioli conserves the par, not the fluctuating value (1/PACI Ellerman). Cross-leg sequencing (close consumes the open position) is a TRANSITION/1 concern, and the multilateral net of many such legs is VNET/1's -- both deliberately OUT of scope here (no VNET files touched). App-side only: kernel boundary law holds. Witnessed: nargo test --workspace green (repo 3/3 incl. legs_link + event_repo_open 5/5 + event_repo_close 4/4 + existing crates value-preserving), both repo witnesses solve, kernel-boundary-check clean, R1 tags 127/128 recorded.
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=a324246e80c0202d95f4e3a4b88dc8b048e92e49a9326a4e6bccd1e76b94cba1

## Cargo (what lands if admitted)

- `cargo/circuits/Nargo.toml` replaces `circuits/Nargo.toml`: +1/-1 lines vs live
- `cargo/circuits/repo/Nargo.toml` is NEW at `circuits/repo/Nargo.toml`:        9 lines
- `cargo/circuits/repo/src/lib.nr` is NEW at `circuits/repo/src/lib.nr`:      171 lines
- `cargo/circuits/event-repo-open/Nargo.toml` is NEW at `circuits/event-repo-open/Nargo.toml`:        9 lines
- `cargo/circuits/event-repo-open/src/main.nr` is NEW at `circuits/event-repo-open/src/main.nr`:       88 lines
- `cargo/circuits/event-repo-open/Prover.toml` is NEW at `circuits/event-repo-open/Prover.toml`:       10 lines
- `cargo/circuits/event-repo-close/Nargo.toml` is NEW at `circuits/event-repo-close/Nargo.toml`:        9 lines
- `cargo/circuits/event-repo-close/src/main.nr` is NEW at `circuits/event-repo-close/src/main.nr`:       85 lines
- `cargo/circuits/event-repo-close/Prover.toml` is NEW at `circuits/event-repo-close/Prover.toml`:       11 lines
- `cargo/sites/ledger/specs/registers/R1.md` replaces `sites/ledger/specs/registers/R1.md`: +9/-0 lines vs live

## Witnessed behavioral delta (task: Add the first real clearing instrument on the EVENT/1 harness: a FICC/GSD repo. circuits/repo compiles BOTH legs over basis B=2 {cash, security par} -- OPEN (collateral out / principal in) and CLOSE (collateral back / principal+interest out) -- each a per-dimension zero-account; the repo interest is the cross-leg cash delta, not a within-leg imbalance. Two bins (event-repo-open / event-repo-close) prove each leg end-to-end through the IDENTICAL discharge. The haircut/valuation lives OUTSIDE the zero-account (par vs cash are incommensurable; vector Pacioli conserves par). Distinct R1 tags 127/128. Cross-leg sequencing (TRANSITION/1) and the multilateral net (VNET/1) are out of scope -- no VNET files touched. App-side. Witnessed: structural (both legs + B=2 + legs_link + harness reuse + workspace + R1); nargo test --workspace green (repo 3/3 + event_repo_open 5/5 + event_repo_close 4/4); both repo witnesses solve; existing event_complete/transition/nullify still solve; the cand-0033 boundary law still passes.)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
