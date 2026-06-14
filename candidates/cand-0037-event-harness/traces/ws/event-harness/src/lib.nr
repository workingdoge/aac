//! event-harness -- the reusable EVENT/1 proof harness, app-side.
//!
//! Factored out of the goods-receipt-invoice event proof so a SECOND posting
//! program reuses it instead of copy-pasting the obligation glue. The harness is
//! schema-AGNOSTIC: it consumes a compiled journal + the claimed BVR public
//! commitments and discharges the obligations that do not depend on the event
//! type -- party binding, P^n balance, journal_commitment binding, and the
//! one-shot event nullifier. A Posting Program supplies the schema-SPECIFIC half
//! (the typed Event, its event_commitment, and Phi_P = compile), then calls
//! `discharge`.
//!
//! App-side by construction (it imports `receipt`); the cand-0033 kernel/app
//! boundary law holds -- no kernel crate learns about events, roles, or
//! nullifiers. Generic over journal shape <R rows, B basis> because the kernel
//! primitives it calls (pacioli::journal_balanced, ledger::journal_commitment)
//! already are.

use pacioli::journal_balanced;
use ledger::journal_commitment;
use receipt::event_nullifier;

/// The image of a Posting Program: J = Phi_P(Event), per-row (account, debit
/// vector, credit vector). Generic in row count R and basis B.
pub struct CompiledJournal<let R: u32, let B: u32> {
    pub accounts: [u32; R],
    pub debits: [[u64; B]; R],
    pub credits: [[u64; B]; R],
}

/// The claimed BVR public ABI subset (EVENT/1).
pub struct EventPublics {
    pub posting_program_id: Field,
    pub event_commitment: Field,
    pub participant_set: Field,
    pub journal_commitment: Field,
    pub event_nullifier: Field,
}

/// Discharge the schema-agnostic EVENT/1 obligations. The caller (a posting
/// program's circuit) has already witnessed the typed Event, bound
/// `event_commitment` to it, derived `participant_set_val` from its roles, and
/// compiled `journal = Phi_P(Event)`. This binds the parties, proves the journal
/// is a P^n zero-account committing to `journal_commitment`, and derives the
/// one-shot nullifier -- exactly what the registry posts and consumes.
pub fn discharge<let R: u32, let B: u32>(
    pubs: EventPublics,
    participant_set_val: Field,
    journal: CompiledJournal<R, B>,
) {
    assert(participant_set_val == pubs.participant_set, "participant_set does not commit the parties");
    assert(journal_balanced(journal.debits, journal.credits), "compiled journal is not a zero-account");
    assert(
        journal_commitment(journal.accounts, journal.debits, journal.credits) == pubs.journal_commitment,
        "journal_commitment is not the schema image of the event",
    );
    let n = event_nullifier(pubs.posting_program_id, pubs.event_commitment, participant_set_val);
    assert(n != 0, "event_nullifier is the 0 sentinel");
    assert(n == pubs.event_nullifier, "event_nullifier incorrectly derived");
}

#[test]
fn discharge_accepts_a_consistent_receipt() {
    // a tiny 2-row / 1-basis zero-account: row0 debits 5, row1 credits 5.
    let j: CompiledJournal<2, 1> = CompiledJournal {
        accounts: [0, 1],
        debits: [[5], [0]],
        credits: [[0], [5]],
    };
    let ps = receipt::participant_set(111, 222);
    let jc = journal_commitment(j.accounts, j.debits, j.credits);
    let nn = event_nullifier(7, 0xabc, ps);
    let pubs = EventPublics { posting_program_id: 7, event_commitment: 0xabc, participant_set: ps, journal_commitment: jc, event_nullifier: nn };
    discharge(pubs, ps, j);
}

#[test(should_fail_with = "journal_commitment is not the schema image of the event")]
fn discharge_rejects_a_wrong_journal_commitment() {
    let j: CompiledJournal<2, 1> = CompiledJournal { accounts: [0, 1], debits: [[5], [0]], credits: [[0], [5]] };
    let ps = receipt::participant_set(111, 222);
    let nn = event_nullifier(7, 0xabc, ps);
    let pubs = EventPublics { posting_program_id: 7, event_commitment: 0xabc, participant_set: ps, journal_commitment: 0xdead, event_nullifier: nn };
    discharge(pubs, ps, j);
}

#[test(should_fail_with = "event_nullifier incorrectly derived")]
fn discharge_rejects_a_wrong_nullifier_binding() {
    let j: CompiledJournal<2, 1> = CompiledJournal { accounts: [0, 1], debits: [[5], [0]], credits: [[0], [5]] };
    let ps = receipt::participant_set(111, 222);
    let jc = journal_commitment(j.accounts, j.debits, j.credits);
    let pubs = EventPublics { posting_program_id: 7, event_commitment: 0xabc, participant_set: ps, journal_commitment: jc, event_nullifier: 0xbad };
    discharge(pubs, ps, j);
}

#[test(should_fail_with = "participant_set does not commit the parties")]
fn discharge_rejects_a_wrong_party_binding() {
    let j: CompiledJournal<2, 1> = CompiledJournal { accounts: [0, 1], debits: [[5], [0]], credits: [[0], [5]] };
    let ps = receipt::participant_set(111, 222);
    let jc = journal_commitment(j.accounts, j.debits, j.credits);
    let nn = event_nullifier(7, 0xabc, ps);
    let pubs = EventPublics { posting_program_id: 7, event_commitment: 0xabc, participant_set: 0x999, journal_commitment: jc, event_nullifier: nn };
    discharge(pubs, ps, j);
}
