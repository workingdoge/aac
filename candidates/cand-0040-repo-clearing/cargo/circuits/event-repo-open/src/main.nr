//! event-repo-open -- the EVENT/1 proof for the OPEN leg of a FICC/GSD repo.
//! Another posting program routing the schema-agnostic obligations through the
//! shared `event_harness::discharge` (basis B=2: cash + security par). The roles
//! are Borrower (cash borrower / collateral provider) and Lender.

use repo::{compile_repo_open, event_commitment_open, RepoOpen};
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
    collateral_par: u64,
    borrower_id: Field,
    lender_id: Field,
) {
    // schema-specific: role coverage (Borrower + Lender present and distinct).
    assert(borrower_id != 0, "missing Borrower role");
    assert(lender_id != 0, "missing Lender role");
    assert(borrower_id != lender_id, "one party fills both roles");
    let ps = participant_set(borrower_id, lender_id);

    // schema-specific: bind the event commitment to the witnessed open-leg Event.
    let e = RepoOpen { principal_cents, collateral_par };
    assert(event_commitment_open(e) == event_commitment_pub, "event_commitment does not commit the event");

    // schema-specific: Phi_P -- compile the open leg to its canonical journal.
    let j = compile_repo_open(e);

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

fn jc(e: RepoOpen) -> Field {
    let j = compile_repo_open(e);
    journal_commitment(j.accounts, j.debits, j.credits)
}

#[test]
fn accepts_a_complete_open_leg() {
    let e = RepoOpen { principal_cents: 100000000, collateral_par: 1000000 };
    let ps = participant_set(111, 222);
    main(11, event_commitment_open(e), ps, jc(e), event_nullifier(11, event_commitment_open(e), ps), 100000000, 1000000, 111, 222);
}

#[test(should_fail_with = "one party fills both roles")]
fn rejects_self_dealing() {
    let e = RepoOpen { principal_cents: 100000000, collateral_par: 1000000 };
    let ps = participant_set(111, 111);
    main(11, event_commitment_open(e), ps, jc(e), event_nullifier(11, event_commitment_open(e), ps), 100000000, 1000000, 111, 111);
}

#[test(should_fail_with = "missing Lender role")]
fn rejects_missing_role() {
    let e = RepoOpen { principal_cents: 100000000, collateral_par: 1000000 };
    let ps = participant_set(111, 0);
    main(11, event_commitment_open(e), ps, jc(e), event_nullifier(11, event_commitment_open(e), ps), 100000000, 1000000, 111, 0);
}

#[test(should_fail_with = "event_nullifier incorrectly derived")]
fn rejects_replay_under_a_foreign_nullifier() {
    let e = RepoOpen { principal_cents: 100000000, collateral_par: 1000000 };
    let other = RepoOpen { principal_cents: 1, collateral_par: 1 };
    let ps = participant_set(111, 222);
    main(11, event_commitment_open(e), ps, jc(e), event_nullifier(11, event_commitment_open(other), ps), 100000000, 1000000, 111, 222);
}

#[test]
fn print_public_inputs() {
    let e = RepoOpen { principal_cents: 100000000, collateral_par: 1000000 };
    let ps = participant_set(111, 222);
    println(event_commitment_open(e));
    println(ps);
    println(jc(e));
    println(event_nullifier(11, event_commitment_open(e), ps));
}
