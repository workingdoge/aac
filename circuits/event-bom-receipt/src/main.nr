//! event-bom-receipt -- the EVENT/1 proof for the bill-of-materials (materials
//! kit) posting program. The SECOND posting program, built to validate that the
//! shared `event_harness` is genuinely schema-agnostic: this main is a near-clone
//! of `event-complete`'s, differing ONLY in the schema-specific half (a 4-quantity
//! Event, its event_commitment, and Phi_P with basis B=4). The schema-agnostic
//! obligations are discharged through the identical `discharge` call -- if the
//! harness were secretly fit to goods-receipt-invoice (B=3), this would not type.

use bom_receipt::{compile_materials_kit_receipt, event_commitment, MaterialsKitReceipt};
use receipt::{event_nullifier, participant_set};
use ledger::journal_commitment;
use event_harness::{discharge, EventPublics};

fn main(
    posting_program_id: pub Field,
    event_commitment_pub: pub Field,
    participant_set_pub: pub Field,
    journal_commitment_pub: pub Field,
    event_nullifier_pub: pub Field,
    usd_cents: u64,
    fabric_meters: u64,
    thread_spools: u64,
    trim_units: u64,
    buyer_id: Field,
    supplier_id: Field,
) {
    // schema-specific: role coverage (Buyer + Supplier present and distinct).
    assert(buyer_id != 0, "missing Buyer role");
    assert(supplier_id != 0, "missing Supplier role");
    assert(buyer_id != supplier_id, "one party fills both roles");
    let ps = participant_set(buyer_id, supplier_id);

    // schema-specific: bind the event commitment to the witnessed Event.
    let e = MaterialsKitReceipt { usd_cents, fabric_meters, thread_spools, trim_units };
    assert(event_commitment(e) == event_commitment_pub, "event_commitment does not commit the event");

    // schema-specific: Phi_P -- compile the Event to its canonical journal (B=4).
    let j = compile_materials_kit_receipt(e);

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

fn jc(e: MaterialsKitReceipt) -> Field {
    let j = compile_materials_kit_receipt(e);
    journal_commitment(j.accounts, j.debits, j.credits)
}

#[test]
fn accepts_a_complete_kit_receipt() {
    let e = MaterialsKitReceipt { usd_cents: 10000, fabric_meters: 50, thread_spools: 8, trim_units: 120 };
    let ps = participant_set(111, 222);
    main(9, event_commitment(e), ps, jc(e), event_nullifier(9, event_commitment(e), ps), 10000, 50, 8, 120, 111, 222);
}

#[test(should_fail_with = "one party fills both roles")]
fn rejects_self_dealing() {
    let e = MaterialsKitReceipt { usd_cents: 10000, fabric_meters: 50, thread_spools: 8, trim_units: 120 };
    let ps = participant_set(111, 111);
    main(9, event_commitment(e), ps, jc(e), event_nullifier(9, event_commitment(e), ps), 10000, 50, 8, 120, 111, 111);
}

#[test(should_fail_with = "missing Buyer role")]
fn rejects_missing_role() {
    let e = MaterialsKitReceipt { usd_cents: 10000, fabric_meters: 50, thread_spools: 8, trim_units: 120 };
    let ps = participant_set(0, 222);
    main(9, event_commitment(e), ps, jc(e), event_nullifier(9, event_commitment(e), ps), 10000, 50, 8, 120, 0, 222);
}

#[test(should_fail_with = "event_nullifier incorrectly derived")]
fn rejects_replay_under_a_foreign_nullifier() {
    let e = MaterialsKitReceipt { usd_cents: 10000, fabric_meters: 50, thread_spools: 8, trim_units: 120 };
    let other = MaterialsKitReceipt { usd_cents: 1, fabric_meters: 1, thread_spools: 1, trim_units: 1 };
    let ps = participant_set(111, 222);
    main(9, event_commitment(e), ps, jc(e), event_nullifier(9, event_commitment(other), ps), 10000, 50, 8, 120, 111, 222);
}

#[test(should_fail_with = "compiled journal is not a zero-account")]
fn harness_rejects_an_unbalanced_journal_at_b4() {
    // The harness proves balance over the journal it is HANDED, not the witness.
    // Hand it a B=4 journal that debits fabric with no matching credit: discharge
    // asserts journal_balanced BEFORE journal_commitment, so this trips the
    // zero-account obligation even with a self-consistent commitment + nullifier.
    let ps = participant_set(111, 222);
    let bad = event_harness::CompiledJournal::<4, 4> {
        accounts: [0, 1, 2, 3],
        debits: [[0, 50, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]],
        credits: [[0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]],
    };
    let jc_bad = journal_commitment(bad.accounts, bad.debits, bad.credits);
    let pubs = EventPublics {
        posting_program_id: 9,
        event_commitment: 0xabc,
        participant_set: ps,
        journal_commitment: jc_bad,
        event_nullifier: event_nullifier(9, 0xabc, ps),
    };
    discharge(pubs, ps, bad);
}

#[test]
fn print_public_inputs() {
    // Fill Prover.toml: `nargo test --show-output print_public_inputs`.
    let e = MaterialsKitReceipt { usd_cents: 10000, fabric_meters: 50, thread_spools: 8, trim_units: 120 };
    let ps = participant_set(111, 222);
    println(event_commitment(e));
    println(ps);
    println(jc(e));
    println(event_nullifier(9, event_commitment(e), ps));
}
