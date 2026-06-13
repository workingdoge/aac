//! EVENT-COMPLETE/1 -- the schema-complete event-compilation proof, with role
//! coverage and the one-shot event nullifier. The prover witnesses the typed
//! event and its parties; the circuit runs the rulebook compiler in-circuit and
//! binds journal_commitment to the compiled journal.
//!
//! Commitments are the SHARED ledger primitives (journal_commitment,
//! participant_set, event_nullifier) -- the same the registry's TRANSITION/1
//! posts and consumes -- so a BalancedVectorReceipt COMPOSES with the
//! state-transition proof rather than diverging. event_commitment is the
//! rulebook's schema encoding.
//!
//! Realizes EVENT-COMPLETE/1 obligations 2, 4, 5, 10 in full. Obligation 9 is
//! realized in an EVENT-SCOPED form: a single one-shot nullifier over
//! (rulebook_id, event_commitment, participant_set) -- NOT the 2/FACT S3
//! factId-derived per-fact nullifier set (that needs cjson(Fact) encoded
//! in-circuit; see EVENT-COMPLETE/1 "Implementation status"). For the
//! single-canonical-fact BVR the event scope IS the one right consumed, so this
//! is a deliberate narrowing, not the full multi-nullifier rule. Public ABI
//! (subset of the BVR): rulebook_id, event_commitment, participant_set,
//! journal_commitment, event_nullifier. Proven end-to-end under UltraHonk (bb)
//! on Apple Silicon.

use pacioli::journal_balanced;
use rulebook::{compile_goods_receipt_invoice, event_commitment, GoodsReceiptInvoice};
use ledger::{event_nullifier, journal_commitment, participant_set};

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
    // obligation 2: role coverage -- Buyer and Supplier present and distinct.
    assert(buyer_id != 0, "missing Buyer role");
    assert(supplier_id != 0, "missing Supplier role");
    assert(buyer_id != supplier_id, "one party fills both roles");
    let ps = participant_set(buyer_id, supplier_id);
    assert(ps == participant_set_pub, "participant_set does not commit the parties");

    // obligation 2/10: bind the event commitment to the witnessed event.
    let e = GoodsReceiptInvoice { usd_cents, fabric_meters };
    assert(event_commitment(e) == event_commitment_pub, "event_commitment does not commit the event");

    // obligation 4 + 5: canonical compilation J = Phi_R(E), a P^n zero-account.
    let j = compile_goods_receipt_invoice(e);
    assert(journal_balanced(j.debits, j.credits), "compiled journal is not a zero-account");

    // obligation 10: journal_commitment recomputed over the COMPILED journal, via
    // the SHARED ledger primitive -- exactly what TRANSITION/1 posts.
    assert(
        journal_commitment(j.accounts, j.debits, j.credits) == journal_commitment_pub,
        "journal_commitment is not the schema image of the event",
    );

    // obligation 9 (event-scoped): the one-shot nullifier, derived in-circuit from
    // the committed event and parties -- shared with the registry's consumption.
    // This is the EVENT-scoped right (rulebook+event+parties), NOT the 2/FACT S3
    // factId = H(enc(fact)) derivation; for the single-canonical-fact BVR the two
    // coincide in scope (the event is its one fact). The value is a hash image, so
    // it is never the 0 sentinel NULLIFY/1 reserves -- assert it, keeping the two
    // circuits' nullifier domains aligned (a 0 nullifier could never be consumed).
    let n = event_nullifier(rulebook_id, event_commitment_pub, ps);
    assert(n != 0, "event_nullifier is the 0 sentinel");
    assert(n == event_nullifier_pub, "event_nullifier incorrectly derived");
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
fn nullifier_is_event_and_party_distinguishing() {
    let a = GoodsReceiptInvoice { usd_cents: 10000, fabric_meters: 50 };
    let b = GoodsReceiptInvoice { usd_cents: 10000, fabric_meters: 51 };
    let ps1 = participant_set(111, 222);
    let ps2 = participant_set(111, 333);
    assert(event_nullifier(7, event_commitment(a), ps1) != event_nullifier(7, event_commitment(b), ps1), "same nullifier for different events");
    assert(event_nullifier(7, event_commitment(a), ps1) != event_nullifier(7, event_commitment(a), ps2), "same nullifier for different parties");
    assert(event_nullifier(7, event_commitment(a), ps1) != event_nullifier(8, event_commitment(a), ps1), "same nullifier across rulebooks");
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
