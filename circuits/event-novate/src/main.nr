//! event-novate -- the NOVATE/1 proof: a bilateral trade and its two CCP-legs are a
//! faithful novation. Public ABI = the three journal commitments a clearing venue
//! sees (the bilateral and the two legs TRANSITION/1 would post); the witness is the
//! trade. The circuit recomputes each commitment, binds it, and proves the novation
//! relation (`novate`) -- balanced legs that compose to the bilateral, the CCP flat.
//!
//! v1 builds the legs by the canonical novation rule (as event-complete builds its
//! journal by Phi_P), so the bound legs ARE the novation of the witnessed bilateral;
//! the `novate` obligation's non-vacuity is shown by the reject tests in
//! `circuits/novate`. A venue-submitted-legs variant (legs witnessed independently
//! and only checked) is the natural follow-on.

use novate::{compile_bilateral, compile_novation_legs, novate};
use ledger::journal_commitment;

fn main(
    bilateral_commitment: pub Field,
    leg_ac_commitment: pub Field,
    leg_cb_commitment: pub Field,
    asset_amt: u64,
    cash_amt: u64,
) {
    let bilateral = compile_bilateral(asset_amt, cash_amt);
    let (leg_ac, leg_cb) = compile_novation_legs(asset_amt, cash_amt);

    // bind each committed journal to its public commitment (the leaves a registry posts).
    assert(
        journal_commitment(bilateral.accounts, bilateral.debits, bilateral.credits) == bilateral_commitment,
        "bilateral_commitment does not commit the trade",
    );
    assert(
        journal_commitment(leg_ac.accounts, leg_ac.debits, leg_ac.credits) == leg_ac_commitment,
        "leg_ac_commitment does not commit the A-C leg",
    );
    assert(
        journal_commitment(leg_cb.accounts, leg_cb.debits, leg_cb.credits) == leg_cb_commitment,
        "leg_cb_commitment does not commit the C-B leg",
    );

    // prove the three committed journals are a faithful novation (CCP flat).
    novate(bilateral, leg_ac, leg_cb);
}

fn commits(asset_amt: u64, cash_amt: u64) -> (Field, Field, Field) {
    let bilateral = compile_bilateral(asset_amt, cash_amt);
    let (leg_ac, leg_cb) = compile_novation_legs(asset_amt, cash_amt);
    (
        journal_commitment(bilateral.accounts, bilateral.debits, bilateral.credits),
        journal_commitment(leg_ac.accounts, leg_ac.debits, leg_ac.credits),
        journal_commitment(leg_cb.accounts, leg_cb.debits, leg_cb.credits),
    )
}

#[test]
fn accepts_a_faithful_novation() {
    let (cb, cac, ccb) = commits(1000000, 100000000);
    main(cb, cac, ccb, 1000000, 100000000);
}

#[test(should_fail_with = "leg_ac_commitment does not commit the A-C leg")]
fn rejects_a_wrong_leg_commitment() {
    let (cb, _cac, ccb) = commits(1000000, 100000000);
    main(cb, 0xdead, ccb, 1000000, 100000000);
}

#[test(should_fail_with = "bilateral_commitment does not commit the trade")]
fn rejects_a_tampered_witness() {
    // commitments for one trade, witness a different one: the binding must reject.
    let (cb, cac, ccb) = commits(1000000, 100000000);
    main(cb, cac, ccb, 1000000, 999);
}

#[test]
fn print_public_inputs() {
    let (cb, cac, ccb) = commits(1000000, 100000000);
    println(cb);
    println(cac);
    println(ccb);
}
