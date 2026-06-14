//! event-repo-close -- the EVENT/1 proof for the CLOSE leg of a FICC/GSD repo.
//! The repurchase: borrower returns principal + repo interest, lender returns the
//! collateral. Same parties and collateral_par as the open leg (the cross-leg
//! sequencing -- close consumes the open position -- is a TRANSITION/1 concern;
//! this proves the close leg is itself a well-formed balanced BVR).

use repo::{compile_repo_close, event_commitment_close, RepoClose};
use receipt::{event_nullifier, participant_set};
use ledger::journal_commitment;
use event_harness::{discharge, EventPublics};

fn main(
    posting_program_id: pub Field,
    event_commitment_pub: pub Field,
    participant_set_pub: pub Field,
    journal_commitment_pub: pub Field,
    event_nullifier_pub: pub Field,
    principal_cents: u64,
    interest_cents: u64,
    collateral_par: u64,
    borrower_id: Field,
    lender_id: Field,
) {
    // schema-specific: role coverage (Borrower + Lender present and distinct).
    assert(borrower_id != 0, "missing Borrower role");
    assert(lender_id != 0, "missing Lender role");
    assert(borrower_id != lender_id, "one party fills both roles");
    let ps = participant_set(borrower_id, lender_id);

    // schema-specific: bind the event commitment to the witnessed close-leg Event.
    let e = RepoClose { principal_cents, interest_cents, collateral_par };
    assert(event_commitment_close(e) == event_commitment_pub, "event_commitment does not commit the event");

    // schema-specific: Phi_P -- compile the close leg to its canonical journal.
    let j = compile_repo_close(e);

    // schema-agnostic: discharge the shared EVENT/1 obligations via the harness.
    let pubs = EventPublics {
        posting_program_id,
        event_commitment: event_commitment_pub,
        participant_set: participant_set_pub,
        journal_commitment: journal_commitment_pub,
        event_nullifier: event_nullifier_pub,
    };
    discharge(pubs, ps, j);
}

fn jc(e: RepoClose) -> Field {
    let j = compile_repo_close(e);
    journal_commitment(j.accounts, j.debits, j.credits)
}

#[test]
fn accepts_a_complete_close_leg() {
    let e = RepoClose { principal_cents: 100000000, interest_cents: 40000, collateral_par: 1000000 };
    let ps = participant_set(111, 222);
    main(12, event_commitment_close(e), ps, jc(e), event_nullifier(12, event_commitment_close(e), ps), 100000000, 40000, 1000000, 111, 222);
}

#[test(should_fail_with = "one party fills both roles")]
fn rejects_self_dealing() {
    let e = RepoClose { principal_cents: 100000000, interest_cents: 40000, collateral_par: 1000000 };
    let ps = participant_set(111, 111);
    main(12, event_commitment_close(e), ps, jc(e), event_nullifier(12, event_commitment_close(e), ps), 100000000, 40000, 1000000, 111, 111);
}

#[test(should_fail_with = "event_commitment does not commit the event")]
fn rejects_a_tampered_interest() {
    // Bind the commitment to one interest but witness another: the schema's
    // event_commitment must reject it (the close cash is part of the committed event).
    let committed = RepoClose { principal_cents: 100000000, interest_cents: 40000, collateral_par: 1000000 };
    let tampered = RepoClose { principal_cents: 100000000, interest_cents: 1, collateral_par: 1000000 };
    let ps = participant_set(111, 222);
    main(12, event_commitment_close(committed), ps, jc(tampered), event_nullifier(12, event_commitment_close(committed), ps), 100000000, 1, 1000000, 111, 222);
}

#[test]
fn print_public_inputs() {
    let e = RepoClose { principal_cents: 100000000, interest_cents: 40000, collateral_par: 1000000 };
    let ps = participant_set(111, 222);
    println(event_commitment_close(e));
    println(ps);
    println(jc(e));
    println(event_nullifier(12, event_commitment_close(e), ps));
}
