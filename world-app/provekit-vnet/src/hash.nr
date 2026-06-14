//! hash.nr -- one circuit-native hash indirection for the ProveKit VNET package.
//!
//! This mirrors the existing beta.19 receipt package: a Poseidon2 sponge over the
//! public `std::hash::poseidon2_permutation`, width 4 / rate 3, with the message
//! length in the capacity lane. The hash is used only for transition-link and
//! profile-id folds; Pedersen vector commitments remain homomorphic curve points.

global P2_WIDTH: u32 = 4;
global P2_RATE: u32 = 3;

pub fn hash<let N: u32>(input: [Field; N]) -> Field {
    let mut state: [Field; 4] = [0, 0, 0, N as Field];
    for k in 0..N {
        state[k % P2_RATE] = state[k % P2_RATE] + input[k];
        if (k % P2_RATE) == (P2_RATE - 1) {
            state = std::hash::poseidon2_permutation(state, P2_WIDTH);
        }
    }
    if (N % P2_RATE) != 0 {
        state = std::hash::poseidon2_permutation(state, P2_WIDTH);
    }
    state[0]
}

pub fn hash2(a: Field, b: Field) -> Field {
    hash([a, b])
}
