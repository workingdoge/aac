//! hash -- AAC's in-circuit commitment hash: a Poseidon2 sponge vendored over
//! the standard library permutation. Replaces pedersen_hash (~3,586 gates per
//! 2:1 hash) with poseidon2_permutation (~75 gates) -- the ~48x reduction on the
//! pedersen-dominated TRANSITION/1 gate count.
//!
//! Construction (t=4, rate=3, capacity=1): a standard sponge over the BN254
//! Poseidon2 permutation (which takes exactly t=4 lanes). The capacity lane is
//! initialized with the input LENGTH so inputs of different arity can never
//! collide, and the existing domain tags (TAG_JOURNAL, TAG_SET, ...) ride in the
//! input exactly as before. AAC controls its own commitment convention -- the
//! hash need only be deterministic and collision-resistant, not match any
//! external value -- so a sound sponge over a correct permutation suffices. The
//! permutation's soundness (round constants, MDS) is the stdlib's; this crate is
//! only the sponge wrapper.

global P2_WIDTH: u32 = 4;
global P2_RATE: u32 = 3;

/// Poseidon2 sponge over an N-field input -> one field. Absorb in rate-sized
/// chunks (add into the rate lanes, permute after each full chunk), permute a
/// trailing partial chunk, then squeeze one lane. N is comptime, so the chunk
/// boundaries and the final-permute branch are all resolved at compile time.
pub fn poseidon_hash<let N: u32>(input: [Field; N]) -> Field {
    let mut state: [Field; 4] = [0, 0, 0, N as Field]; // capacity = length (arity domain-sep)
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

#[test]
fn deterministic_and_distinguishing() {
    // deterministic
    assert(poseidon_hash([1, 2]) == poseidon_hash([1, 2]), "not deterministic");
    // order-sensitive (a commitment must bind position)
    assert(poseidon_hash([1, 2]) != poseidon_hash([2, 1]), "ignores order");
    // arity domain-separation: [1,2] vs [1,2,0] must differ (the capacity carries N)
    assert(poseidon_hash([1, 2]) != poseidon_hash([1, 2, 0]), "arity collision");
    // every element is bound
    assert(poseidon_hash([1, 2, 3]) != poseidon_hash([1, 2, 4]), "ignores an element");
    // a typical tagged 2-input is nontrivial
    assert(poseidon_hash([3, 0]) != 0, "trivial zero digest");
    // a 4-input spans two chunks (3 + 1) and stays order-binding
    assert(poseidon_hash([1, 2, 3, 4]) != poseidon_hash([1, 2, 4, 3]), "4-input ignores order");
    // a 3-input is exactly one full chunk (no trailing permute) and binds order
    assert(poseidon_hash([5, 6, 7]) != poseidon_hash([7, 6, 5]), "3-input ignores order");
}
