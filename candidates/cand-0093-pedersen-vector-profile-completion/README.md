# cand-0093-pedersen-vector-profile-completion

Intent: Pin the PEDERSEN-VECTOR/1 derivation encodings, basis commitment, canonical-y, and vectors (closes the cand-0092 obstruction)

Status: open (pre-threshold).

## Cargo

This candidate completes the PEDERSEN-VECTOR/1 generator-pinning surface:

- amends `sites/ledger/specs/profiles/PEDERSEN-VECTOR-1.md` with `field_of`,
  `basis_commitment`, canonical even-y try-and-increment, and vector notes;
- adds `sites/ledger/specs/profiles/vectors/PEDERSEN-VECTOR-1.json`;
- adds the standalone beta.19 Noir harness
  `world-app/provekit-pedersen-vector-derivation`;
- resolves the cand-0092 queue obstruction and leaves the independent Python
  Poseidon2 cross-check as an open follow-up.

The profile identity decision is the operator-resolved lowercase
`profile_id = "pedersen-vector/1"`. The existing §8 text is not changed.

## Toolchain

The derivation harness uses Noir `v1.0.0-beta.19` via the repo's `.#nargo19`
flake output. This matches the ProveKit VNET package and keeps the derivation
separate from the beta.14 bb/UltraHonk workspace.

Regeneration path used by eval:

```sh
nix build .#nargo19
cd world-app/provekit-pedersen-vector-derivation
HOME=/private/tmp/aac-home ../../result/bin/nargo execute /private/tmp/pedersen-vector-derivation.gz > /private/tmp/pedersen-vector-derivation.out
node render-vector.mjs < /private/tmp/pedersen-vector-derivation.out
```

The `HOME` override is only for direct `result/bin/nargo` execution in the
restricted worker sandbox; `nix run .#nargo19 -- test --show-output` also runs
the harness.

## Optional RLM Trace Evidence

When model-assisted or large-context reasoning materially supports this candidate,
keep that support in checking mode: generate an explicit trace with
`tools/eval/rlm-trace-from-candidate.sh`, check it with
`sites/eval/realizations/rlm-trace-profile-check/rlm-trace-profile-check.sh`,
and store the JSONL plus checker output under `traces/` before attestation.
A passing RLM trace is evidence only; it does not grant answer authority,
KB admission, Boat candidate admission, Harbor readiness, live LLM calls,
provider calls, network access, shell access, or secret access.
