# Threshold Brief: cand-0033-kernel-boundary-law

Generated: 2026-06-14T02:09:56Z
Status: validated
Intent: Land tools/kernel-boundary-check.sh -- a read-only, ROOT-relative court for the kernel/app crate boundary (4/REG S5: the base MUST NOT require an application target; the recompute-vs-consume seam, cand-0030/0032). The law: each KERNEL circuit crate {pacioli,hash,ledger,transition,nullify} may depend on / import only KERNEL crates + std; any Nargo.toml path-dep or 'use' naming a non-kernel workspace crate (rulebook, receipt, event_complete, or any future schema/receipt lib) is REFUSED typed (witness-id minted). Sound via the manifest alone (Noir requires a dep to reference a crate); the 'use' scan is defense-in-depth. Enrolled in tools/eval/evaluate-landed.sh so every post-land re-checks the boundary -- a future candidate re-introducing a kernel->app edge FAILs. tools/ cargo -> independent REVIEW required (tier guard). Eval: checker green on the live post-cand-0032 tree; a mutant (inject receipt dep into a kernel crate) FAILs; enrollment present.
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=a324246e80c0202d95f4e3a4b88dc8b048e92e49a9326a4e6bccd1e76b94cba1

## Cargo (what lands if admitted)

- `cargo/tools/kernel-boundary-check.sh` is NEW at `tools/kernel-boundary-check.sh`:       91 lines
- `cargo/tools/eval/evaluate-landed.sh` replaces `tools/eval/evaluate-landed.sh`: +2/-0 lines vs live

## Witnessed behavioral delta (task: land tools/kernel-boundary-check.sh -- a read-only ROOT-relative court for the kernel/app crate boundary (4/REG S5): KERNEL = {pacioli,hash,ledger,transition,nullify}, each kernel crate may depend on / import only KERNEL crates + std; a Nargo.toml dep or use naming a non-kernel crate is refused typed (witnessId minted). Enrolled in evaluate-landed.sh so every post-land re-checks the boundary. Witnessed: structural (ROOT-relative, KERNEL pinned, typed witnesses, [[ -f ]]-guard-enrolled), CLEAN on the live post-cand-0032 tree, and NON-VACUOUS (a manifest-dep mutant AND a use-import mutant are both refused, exit 1).)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
