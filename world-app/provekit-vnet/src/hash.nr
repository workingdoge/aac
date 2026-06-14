//! hash.nr -- the circuit-native hash behind one indirection (Poseidon2 sponge
//! over the PUBLIC `std::hash::poseidon2_permutation`, width 4 / rate 3, message
//! length in the capacity lane). Identical construction to
//! world-app/provekit-circuit/src/hash.nr and circuits/hash. Used here only for
//! the cheap `journal_commitment` recompute that binds a netting atom to its
//! posted TRANSITION/1 journal (PEDERSEN-VECTOR/1 S5/S9 -- bind via the Poseidon2
//! identity hash, not redundant Pedersen recomputation).

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
