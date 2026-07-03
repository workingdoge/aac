# cand-0092-vnet-profile-alignment

Intent: Align world-app/provekit-vnet to the full PEDERSEN-VECTOR/1 profile and VNET/1 public surface

Status: open (pre-threshold).

## Stop Finding

This candidate does not change `world-app/provekit-vnet`. The requested circuit
alignment is blocked by an underspecified soundness-critical generator-pinning
surface in `PEDERSEN-VECTOR/1`:

- `PEDERSEN-VECTOR/1` section 2 requires offline
  `Poseidon2("aac/vnet/1", profile_id, basis_commitment, basis_type_id_j,
  label, j)` try-and-increment generation, verifier re-derivation, and pinned
  circuit constants.
- The repo has no `PEDERSEN-VECTOR/1` Grumpkin conformance vector or reference
  generator under `sites/ledger/specs/profiles/vectors/`.
- The profile text does not define the executable string-to-Field encoding for
  `profile_id`, `basis_type_id_j`, or labels, the exact `basis_commitment`
  formula for this profile, or the canonical-y rule needed to pin constants.
- The live circuit still uses the old free-label
  `std::hash::derive_generators("AAC_PEDERSEN_VECTOR_VNET_1".as_bytes(), 0)`
  path, which is not basis-bound as required by `PEDERSEN-VECTOR/1` section 2
  and `VNET/1` sections 2 and 6.

Per the task instruction, this candidate records that gap in the queue rather
than choosing generator points silently.

## Optional RLM Trace Evidence

When model-assisted or large-context reasoning materially supports this candidate,
keep that support in checking mode: generate an explicit trace with
`tools/eval/rlm-trace-from-candidate.sh`, check it with
`sites/eval/realizations/rlm-trace-profile-check/rlm-trace-profile-check.sh`,
and store the JSONL plus checker output under `traces/` before attestation.
A passing RLM trace is evidence only; it does not grant answer authority,
KB admission, Boat candidate admission, Harbor readiness, live LLM calls,
provider calls, network access, shell access, or secret access.
