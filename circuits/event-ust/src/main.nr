//! event-ust -- the EVENT/1 proof for a US Treasury cash trade. A near-clone of the
//! other event-* bins (the schema-agnostic obligations route through the identical
//! event_harness::discharge); roles are Seller and Buyer. Its value-add beyond
//! "another posting program" is the COMPOSITION conformance test: the journal a UST
//! trade compiles to is byte-identical to the bilateral NOVATE/1 novates, so
//! capture (EVENT/1) and interposition (NOVATE/1) compose at the journal_commitment
//! seam.

use ust_trade::{compile_ust_trade, event_commitment, UstTrade};
use receipt::{event_nullifier, participant_set};
use ledger::journal_commitment;
use event_harness::{discharge, EventPublics};

fn main(
    posting_program_id: pub Field,
    event_commitment_pub: pub Field,
    participant_set_pub: pub Field,
    journal_commitment_pub: pub Field,
    event_nullifier_pub: pub Field,
    par: u64,
    cash_cents: u64,
    seller_id: Field,
    buyer_id: Field,
) {
    // schema-specific: role coverage (Seller + Buyer present and distinct).
    assert(seller_id != 0, "missing Seller role");
    assert(buyer_id != 0, "missing Buyer role");
    assert(seller_id != buyer_id, "one party fills both roles");
    let ps = participant_set(seller_id, buyer_id);

    // schema-specific: bind the event commitment to the witnessed trade.
    let e = UstTrade { par, cash_cents };
    assert(event_commitment(e) == event_commitment_pub, "event_commitment does not commit the event");

    // schema-specific: Phi_P -- compile the trade to its canonical journal.
    let j = compile_ust_trade(e);

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

fn jc(e: UstTrade) -> Field {
    let j = compile_ust_trade(e);
    journal_commitment(j.accounts, j.debits, j.credits)
}

#[test]
fn accepts_a_complete_trade() {
    let e = UstTrade { par: 1000000, cash_cents: 100000000 };
    let ps = participant_set(111, 222);
    main(13, event_commitment(e), ps, jc(e), event_nullifier(13, event_commitment(e), ps), 1000000, 100000000, 111, 222);
}

#[test(should_fail_with = "one party fills both roles")]
fn rejects_self_dealing() {
    let e = UstTrade { par: 1000000, cash_cents: 100000000 };
    let ps = participant_set(111, 111);
    main(13, event_commitment(e), ps, jc(e), event_nullifier(13, event_commitment(e), ps), 1000000, 100000000, 111, 111);
}

#[test(should_fail_with = "missing Seller role")]
fn rejects_missing_role() {
    let e = UstTrade { par: 1000000, cash_cents: 100000000 };
    let ps = participant_set(0, 222);
    main(13, event_commitment(e), ps, jc(e), event_nullifier(13, event_commitment(e), ps), 1000000, 100000000, 0, 222);
}

#[test]
fn ust_journal_is_the_novate_bilateral() {
    // THE COMPOSITION: the journal a UST trade compiles to is byte-identical to the
    // bilateral NOVATE/1 novates -- so capture and interposition agree on the leaf.
    let par = 1000000;
    let cash = 100000000;
    let ust = compile_ust_trade(UstTrade { par, cash_cents: cash });
    let bilateral = novate::compile_bilateral(par, cash);
    assert(
        journal_commitment(ust.accounts, ust.debits, ust.credits)
            == journal_commitment(bilateral.accounts, bilateral.debits, bilateral.credits),
        "the UST trade journal is not NOVATE/1's bilateral",
    );
    // and NOVATE/1 accepts that very journal as the bilateral of a faithful novation.
    let (leg_ac, leg_cb) = novate::compile_novation_legs(par, cash);
    novate::novate(bilateral, leg_ac, leg_cb);
}

#[test]
fn print_public_inputs() {
    let e = UstTrade { par: 1000000, cash_cents: 100000000 };
    let ps = participant_set(111, 222);
    println(event_commitment(e));
    println(ps);
    println(jc(e));
    println(event_nullifier(13, event_commitment(e), ps));
}
