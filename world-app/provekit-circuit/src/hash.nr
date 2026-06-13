//! hash.nr -- the circuit-native hash, isolated behind ONE indirection so the
//! whole circuit's hash primitive is a single-point decision.
//!
//! HASH CHOICE IS OPEN (Design Note 0002 S2.1, S9). ProveKit's DEFAULT in-circuit
//! hash is **Skyscraper**; Poseidon2 appears in ProveKit examples. This is NOT the
//! same decision as AAC's bb-workspace Poseidon2 migration (Design Note 0001 S8) --
//! that decision is measured against UltraHonk gate counts, whereas here the metric
//! is ProveKit's R1CS/WHIR cost. Decide by measurement with ProveKit's own
//! `circuit_stats` / `analyze-pkp`.
//!
//! TODO(verify-at-integration): wire this to ProveKit's Skyscraper as exposed by
//! the beta.19 toolchain / ProveKit stdlib. The exact import path is unverified in
//! this environment (no beta.19 nargo here). Until then we use `poseidon2` from the
//! Noir stdlib as a PLACEHOLDER so the circuit's STRUCTURE typechecks; swap the body
//! of `hash` for Skyscraper without touching any caller.
//!
//! The reference `circuits/event-complete` (beta.14) uses `pedersen_hash`. We do NOT
//! copy that: pedersen is ~48x more expensive than a sponge hash (Design Note 0001
//! S8) and ProveKit prefers a sponge-style native hash. Commitment VALUES therefore
//! differ from the beta.14 circuit by construction -- this is a re-expression, not a
//! copy, and the two need not produce identical field images.

use std::hash::poseidon2::Poseidon2;

/// The one circuit-native hash. Every commitment / nullifier / fold routes through
/// here, so switching to Skyscraper is a one-line change.
///
/// PLACEHOLDER: Poseidon2 sponge. Replace with Skyscraper at integration.
pub fn hash<let N: u32>(input: [Field; N]) -> Field {
    Poseidon2::hash(input, N)
}

/// Two-field compression -- the 2:1 step a Merkle fold needs.
pub fn hash2(a: Field, b: Field) -> Field {
    hash([a, b])
}
