//! ledger.nr -- the canonical commitments a BalancedVectorReceipt carries, mirroring
//! `circuits/ledger` (beta.14). Lifting these into one place is what makes a receipt
//! COMPOSE with the registry's TRANSITION/1: the journal_commitment and nullifier a
//! receipt proves are the same objects the registry posts and consumes.
//!
//! NOTE the hash primitive differs from the beta.14 ledger (pedersen there, the
//! native sponge here). Composition is at the LEVEL of "the same construction over
//! the same fields", but the field VALUES will differ across toolchains. At
//! integration, fix ONE canonical hash for cross-toolchain commitment equality, or
//! treat the ProveKit receipt as an application-layer attestation that is re-pinned
//! to the registry's pedersen commitments off-circuit. (Open; see README.)

use crate::hash::{hash, hash2};

// canonical domain tags (shared shape with the beta.14 ledger)
pub global TAG_JOURNAL: Field = 3;
pub global TAG_NULL: Field = 123;
pub global TAG_PARTY: Field = 122;

/// Order-binding journal commitment: a fold over rows, each row =
/// (account, debit-vector, credit-vector). Generic in row count R and basis B.
/// Reordering rows changes the image -- the journal is a sequence, not a set.
pub fn journal_commitment<let R: u32, let B: u32>(
    accounts: [u32; R],
    debits: [[u64; B]; R],
    credits: [[u64; B]; R],
) -> Field {
    let mut jc = hash2(TAG_JOURNAL, 0);
    for r in 0..R {
        let mut buf: [Field; 3 + 2 * B] = [0; 3 + 2 * B];
        buf[0] = TAG_JOURNAL;
        buf[1] = jc;
        buf[2] = accounts[r] as Field;
        for b in 0..B {
            buf[3 + b] = debits[r][b] as Field;
            buf[3 + B + b] = credits[r][b] as Field;
        }
        jc = hash(buf);
    }
    jc
}

/// Commit the parties filling a schema's roles. Order-sensitive: Buyer and Supplier
/// are distinct roles, so (buyer, supplier) != (supplier, buyer).
pub fn participant_set(buyer: Field, supplier: Field) -> Field {
    hash([TAG_PARTY, buyer, supplier])
}

/// The one-shot event identity, scoped to rulebook + event + parties (2/FACT S8).
/// EVENT-SCOPED nullifier: for the single-canonical-fact BVR this is the one right
/// consumed (see EVENT-COMPLETE/1 "Implementation status" -- obligation 9 narrowed).
pub fn event_nullifier(rulebook_id: Field, event_commitment: Field, participant_set: Field) -> Field {
    hash([TAG_NULL, rulebook_id, event_commitment, participant_set])
}
