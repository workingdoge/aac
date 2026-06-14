//! event-complete -- the EVENT/1 proof for the goods-receipt-invoice posting
//! program. Witnesses the typed Event + parties, binds event_commitment,
//! compiles via Phi_P, then discharges the SCHEMA-AGNOSTIC obligations through
//! the shared `event_harness`. (Harness factored out; API names point toward the
//! EVENT/1 + Posting Program vocabulary; file/crate names keep the old form.)

use rulebook::{compile_goods_receipt_invoice, event_commitment, GoodsReceiptInvoice};
use receipt::{event_nullifier, participant_set};
use ledger::journal_commitment;
use event_harness::{discharge, EventPublics};

fn main(
    rulebook_id: pub Field,
    event_commitment_pub: pub Field,
    participant_set_pub: pub Field,
    journal_commitment_pub: pub Field,
    event_nullifier_pub: pub Field,
    usd_cents: u64,
    fabric_meters: u64,
    buyer_id: Field,
    supplier_id: Field,
) {
    // schema-specific: role coverage (Buyer + Supplier present and distinct).
    assert(buyer_id != 0, "missing Buyer role");
    assert(supplier_id != 0, "missing Supplier role");
    assert(buyer_id != supplier_id, "one party fills both roles");
    let ps = participant_set(buyer_id, supplier_id);

    // schema-specific: bind the event commitment to the witnessed Event.
    let e = GoodsReceiptInvoice { usd_cents, fabric_meters };
    assert(event_commitment(e) == event_commitment_pub, "event_commitment does not commit the event");

    // schema-specific: Phi_P -- compile the Event to its canonical journal.
    let j = compile_goods_receipt_invoice(e);

    // schema-agnostic: discharge the shared EVENT/1 obligations via the harness.
    let pubs = EventPublics {
        posting_program_id: rulebook_id,
        event_commitment: event_commitment_pub,
        participant_set: participant_set_pub,
        journal_commitment: journal_commitment_pub,
        event_nullifier: event_nullifier_pub,
    };
    discharge(pubs, ps, j);
}

fn jc(e: GoodsReceiptInvoice) -> Field {
    let j = compile_goods_receipt_invoice(e);
    journal_commitment(j.accounts, j.debits, j.credits)
}

#[test]
fn accepts_a_complete_receipt() {
    let e = GoodsReceiptInvoice { usd_cents: 10000, fabric_meters: 50 };
    let ps = participant_set(111, 222);
    main(7, event_commitment(e), ps, jc(e), event_nullifier(7, event_commitment(e), ps), 10000, 50, 111, 222);
}

#[test(should_fail_with = "one party fills both roles")]
fn rejects_self_dealing() {
    let e = GoodsReceiptInvoice { usd_cents: 10000, fabric_meters: 50 };
    let ps = participant_set(111, 111);
    main(7, event_commitment(e), ps, jc(e), event_nullifier(7, event_commitment(e), ps), 10000, 50, 111, 111);
}

#[test(should_fail_with = "missing Buyer role")]
fn rejects_missing_role() {
    let e = GoodsReceiptInvoice { usd_cents: 10000, fabric_meters: 50 };
    let ps = participant_set(0, 222);
    main(7, event_commitment(e), ps, jc(e), event_nullifier(7, event_commitment(e), ps), 10000, 50, 0, 222);
}

#[test(should_fail_with = "event_nullifier incorrectly derived")]
fn rejects_replay_under_a_foreign_nullifier() {
    let e = GoodsReceiptInvoice { usd_cents: 10000, fabric_meters: 50 };
    let other = GoodsReceiptInvoice { usd_cents: 1, fabric_meters: 1 };
    let ps = participant_set(111, 222);
    main(7, event_commitment(e), ps, jc(e), event_nullifier(7, event_commitment(other), ps), 10000, 50, 111, 222);
}

#[test]
fn print_public_inputs() {
    let e = GoodsReceiptInvoice { usd_cents: 10000, fabric_meters: 50 };
    let ps = participant_set(111, 222);
    println(event_commitment(e));
    println(ps);
    println(jc(e));
    println(event_nullifier(7, event_commitment(e), ps));
}
