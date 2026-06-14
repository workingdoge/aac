//! receipt -- the BalancedVectorReceipt app-side identities the kernel consumes
//! OPAQUELY: the participant set over a schema's roles and the one-shot event
//! nullifier. These are NOT kernel structures -- TRANSITION/1 and NULLIFY/1 take
//! the nullifier as an opaque Field and never recompute it (the
//! recompute-vs-consume seam rule). Lifted out of `ledger` (cand-0032) so the
//! kernel commitment seam (`ledger::journal_commitment`) carries no application
//! identity, and so changing these app tags cannot touch the enshrined registry.
//!
//! Application-range domain tags (3/PROOF Annex A, 120-255), assigned in R1:
//!   124 participant set        125 event nullifier
//! Reassigned off the 122/123 collision with R1's receipt-reference block
//! (3/PROOF S3: tag reuse across structures is a soundness failure).

pub global TAG_PARTY: Field = 124;
pub global TAG_NULL: Field = 125;

/// Commit the parties filling a schema's roles.
pub fn participant_set(buyer: Field, supplier: Field) -> Field {
    hash::poseidon_hash([TAG_PARTY, buyer, supplier])
}

/// The one-shot event identity, scoped to rulebook + event + parties (2/FACT S8).
pub fn event_nullifier(rulebook_id: Field, event_commitment: Field, participant_set: Field) -> Field {
    hash::poseidon_hash([TAG_NULL, rulebook_id, event_commitment, participant_set])
}

#[test]
fn identities_distinguish() {
    assert(participant_set(1, 2) != participant_set(2, 1), "participant_set ignores order");
    assert(event_nullifier(1, 10, 20) != event_nullifier(2, 10, 20), "nullifier ignores rulebook");
    assert(event_nullifier(1, 10, 20) != event_nullifier(1, 11, 20), "nullifier ignores event");
}
