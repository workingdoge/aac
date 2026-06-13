//! ledger -- canonical commitments shared by the enshrined TRANSITION/1 and the
//! application target EVENT-COMPLETE/1, so the two targets COMPOSE: a receipt's
//! journal_commitment and event_nullifier are exactly what the registry posts
//! and consumes. Lifting these into one place is what makes the three-proof
//! spine (BVR -> TRANSITION -> registry) agree by construction.

// Canonical domain tags (shared; TAG_JOURNAL matches TRANSITION/1's original
// construction so its commitment value is unchanged).
pub global TAG_JOURNAL: Field = 3;
pub global TAG_NULL: Field = 123;
pub global TAG_PARTY: Field = 122;

/// The canonical order-binding journal commitment: a fold over rows, each row =
/// (account, debit-vector, credit-vector). Generic in row count R and basis B.
pub fn journal_commitment<let R: u32, let B: u32>(
    accounts: [u32; R],
    debits: [[u64; B]; R],
    credits: [[u64; B]; R],
) -> Field {
    let mut jc = std::hash::pedersen_hash([TAG_JOURNAL, 0]);
    for r in 0..R {
        let mut buf: [Field; 3 + 2 * B] = [0; 3 + 2 * B];
        buf[0] = TAG_JOURNAL;
        buf[1] = jc;
        buf[2] = accounts[r] as Field;
        for b in 0..B {
            buf[3 + b] = debits[r][b] as Field;
            buf[3 + B + b] = credits[r][b] as Field;
        }
        jc = std::hash::pedersen_hash(buf);
    }
    jc
}

/// Commit the parties filling a schema's roles.
pub fn participant_set(buyer: Field, supplier: Field) -> Field {
    std::hash::pedersen_hash([TAG_PARTY, buyer, supplier])
}

/// The one-shot event identity, scoped to rulebook + event + parties (2/FACT S8).
pub fn event_nullifier(rulebook_id: Field, event_commitment: Field, participant_set: Field) -> Field {
    std::hash::pedersen_hash([TAG_NULL, rulebook_id, event_commitment, participant_set])
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

#[test]
fn identities_distinguish() {
    assert(participant_set(1, 2) != participant_set(2, 1), "participant_set ignores order");
    assert(event_nullifier(1, 10, 20) != event_nullifier(2, 10, 20), "nullifier ignores rulebook");
    assert(event_nullifier(1, 10, 20) != event_nullifier(1, 11, 20), "nullifier ignores event");
}
