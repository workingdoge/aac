//! ledger -- the canonical KERNEL commitment seam: the order-binding
//! journal_commitment that the enshrined TRANSITION/1 RECOMPUTES in-circuit and
//! the application target EVENT-COMPLETE/1 produces for the same journal -- so the
//! two agree by construction. App-side receipt identities (participant_set,
//! event_nullifier) live in `circuits/receipt` (cand-0032): the kernel consumes
//! nullifiers OPAQUELY and never recomputes them (the recompute-vs-consume seam),
//! so they carry no kernel meaning here.

// The kernel commitment tag (TAG_JOURNAL matches TRANSITION/1's original
// construction so journal_commitment's value is unchanged).
pub global TAG_JOURNAL: Field = 3;

/// The canonical order-binding journal commitment: a fold over rows, each row =
/// (account, debit-vector, credit-vector). Generic in row count R and basis B.
pub fn journal_commitment<let R: u32, let B: u32>(
    accounts: [u32; R],
    debits: [[u64; B]; R],
    credits: [[u64; B]; R],
) -> Field {
    let mut jc = hash::poseidon_hash([TAG_JOURNAL, 0]);
    for r in 0..R {
        let mut buf: [Field; 3 + 2 * B] = [0; 3 + 2 * B];
        buf[0] = TAG_JOURNAL;
        buf[1] = jc;
        buf[2] = accounts[r] as Field;
        for b in 0..B {
            buf[3 + b] = debits[r][b] as Field;
            buf[3 + B + b] = credits[r][b] as Field;
        }
        jc = hash::poseidon_hash(buf);
    }
    jc
}

#[test]
fn journal_commitment_is_order_binding() {
    let a: [u32; 2] = [0, 1];
    let d: [[u64; 2]; 2] = [[5, 0], [0, 5]];
    let c: [[u64; 2]; 2] = [[0, 5], [5, 0]];
    assert(journal_commitment(a, d, c) == journal_commitment(a, d, c)); // deterministic
    let a2: [u32; 2] = [1, 0]; // reordered rows
    let d2: [[u64; 2]; 2] = [[0, 5], [5, 0]];
    let c2: [[u64; 2]; 2] = [[5, 0], [0, 5]];
    assert(journal_commitment(a, d, c) != journal_commitment(a2, d2, c2), "fold is not order-binding");
}

use receipt::participant_set;
