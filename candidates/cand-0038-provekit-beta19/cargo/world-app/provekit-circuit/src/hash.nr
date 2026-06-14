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
//! the beta.19 toolchain / ProveKit stdlib. Until then we use a Poseidon2 SPONGE as
//! a PLACEHOLDER so the circuit's STRUCTURE typechecks; swap the body of `hash` for
//! Skyscraper without touching any caller.
//!
//! NB: the sponge is built over the PUBLIC `std::hash::poseidon2_permutation`, not
//! the private `std::hash::poseidon2::Poseidon2::hash` (which is `pub(crate)` to std
//! on beta.19 and so unimportable from here -- the same constraint circuits/hash hit
//! in beta.14, cand-0024). This mirrors `circuits/hash/src/lib.nr` exactly: a fixed
//! width-4 / rate-3 sponge with the message length absorbed into the capacity lane.
//!
//! The reference `circuits/event-complete` (beta.14) uses `pedersen_hash`. We do NOT
//! copy that: pedersen is ~48x more expensive than a sponge hash (Design Note 0001
//! S8) and ProveKit prefers a sponge-style native hash. Commitment VALUES therefore
//! differ from the beta.14 circuit by construction -- this is a re-expression, not a
//! copy, and the two need not produce identical field images.

global P2_WIDTH: u32 = 4;
global P2_RATE: u32 = 3;

/// The one circuit-native hash. Every commitment / nullifier / fold routes through
/// here, so switching to Skyscraper is a one-line change.
///
/// PLACEHOLDER: a Poseidon2 sponge over the PUBLIC permutation. Replace with
/// Skyscraper at integration. Width 4 / rate 3, length absorbed into the capacity
/// lane -- identical construction to circuits/hash/src/lib.nr.
pub fn hash<let N: u32>(input: [Field; N]) -> Field {
    let mut state: [Field; 4] = [0, 0, 0, N as Field];
    for k in 0..N {
        state[k % P2_RATE] = state[k % P2_RATE] + input[k];
        if (k % P2_RATE) == (P2_RATE - 1) {
            state = std::hash::poseidon2_permutation(state, P2_WIDTH);
        }
    }
    // Final permutation for the trailing partial block (or the empty message).
    if (N % P2_RATE) != 0 {
        state = std::hash::poseidon2_permutation(state, P2_WIDTH);
    }
    state[0]
}

/// Two-field compression -- the 2:1 step a Merkle fold needs.
pub fn hash2(a: Field, b: Field) -> Field {
    hash([a, b])
}
