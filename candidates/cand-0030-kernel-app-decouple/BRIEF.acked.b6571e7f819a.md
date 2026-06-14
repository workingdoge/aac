# Threshold Brief: cand-0030-kernel-app-decouple

Generated: 2026-06-14T00:29:46Z
Status: validated
Intent: Sever the kernel->app back-edge: remove the rulebook (application schema) dependency from the enshrined transition + nullify circuits -- it is test-only, the proven main is already schema-agnostic. transition keeps pacioli+ledger+hash; nullify drops to hash only. The transition composition test uses the literal Pn conformance vector (a fixture) and an opaque nullifier instead of compile_goods_receipt_invoice/event_nullifier; nullify anti-replay tests use opaque field values. nargo test green workspace-wide; a structural probe witnesses the kernel crates carry no app refs. Enforces 4/REG S5 (base MUST NOT require an application target) at the crate level. Circuits-only, no tier-guard.
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=a324246e80c0202d95f4e3a4b88dc8b048e92e49a9326a4e6bccd1e76b94cba1

## Cargo (what lands if admitted)

- `cargo/circuits/transition/Nargo.toml` replaces `circuits/transition/Nargo.toml`: +0/-1 lines vs live
- `cargo/circuits/transition/src/main.nr` replaces `circuits/transition/src/main.nr`: +24/-15 lines vs live
- `cargo/circuits/nullify/Nargo.toml` replaces `circuits/nullify/Nargo.toml`: +0/-2 lines vs live
- `cargo/circuits/nullify/src/main.nr` replaces `circuits/nullify/src/main.nr`: +18/-15 lines vs live

## Witnessed behavioral delta (task: sever the kernel->app back-edge: remove the rulebook (application schema) dependency from the enshrined transition + nullify circuits (test-only; the proven main was already schema-agnostic). transition keeps pacioli+ledger+hash; nullify drops to hash alone. The transition composition test uses the literal Pn conformance vector + an opaque nullifier; nullify anti-replay tests use an opaque field. nargo test green workspace-wide, all sample witnesses solve, and a structural probe (with a candidate-local mutant) witnesses the kernel carries no app refs. 4/REG S5: base MUST NOT require an application target.)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
