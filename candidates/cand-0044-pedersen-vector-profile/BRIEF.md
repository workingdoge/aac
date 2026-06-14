# Threshold Brief: cand-0044-pedersen-vector-profile

Generated: 2026-06-14T07:44:31Z
Status: validated
Intent: Concretize VNET/1 into the PEDERSEN-VECTOR/1 profile: Grumpkin group, domain-separated per-basis generators, MSM-only aggregation (ProveKit has no EmbeddedCurveAdd), zero-opening as a single MSM, bounded non-negative coordinates, conformance vectors. The homomorphic commitment decomposition enabling confidential netting.
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=a324246e80c0202d95f4e3a4b88dc8b048e92e49a9326a4e6bccd1e76b94cba1

## Cargo (what lands if admitted)

- `cargo/sites/ledger/specs/profiles/PEDERSEN-VECTOR-1.md` is NEW at `sites/ledger/specs/profiles/PEDERSEN-VECTOR-1.md`:      188 lines
- `cargo/sites/ledger/specs/profiles/README.md` replaces `sites/ledger/specs/profiles/README.md`: +1/-1 lines vs live
- `cargo/sites/ledger/specs/applications/VNET-1.md` replaces `sites/ledger/specs/applications/VNET-1.md`: +25/-6 lines vs live

## Witnessed behavioral delta (task: Concretize VNET/1 into the PEDERSEN-VECTOR/1 profile: Grumpkin group + EmbeddedCurvePoint encoding, domain-separated try-and-increment generator derivation (verifier-determined), the Commit_B(v,r) MSM form, the MSM-ONLY aggregation discipline grounded in a measured backend capability (ProveKit implements MultiScalarMul but not EmbeddedCurveAdd), the zero-opening proven as a single MSM with per-dimension nullity, bounded non-negative coordinates with no scalar wraparound, conformance vectors incl. the false-net soundness case, and target identity. Index + VNET/1 §2/§9 reference it; no circuit or R1 tag allocation.)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
