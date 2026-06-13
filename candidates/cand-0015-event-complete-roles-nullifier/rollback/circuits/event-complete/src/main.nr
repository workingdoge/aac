//! EVENT-COMPLETE/1 -- the schema-complete event-compilation proof.
//!
//! This is Phi_R wired into a proof. The prover witnesses the TYPED EVENT (its
//! private quantities), the circuit runs the rulebook compiler in-circuit, and
//! binds journal_commitment to the COMPILED journal. A verifier therefore learns
//! that journal_commitment commits to Phi_R(event) -- the schema's deterministic
//! image of the committed event -- and that it is a P^n zero-account; never that
//! "some balanced journal" exists. That is what closes "fraud can balance":
//! the journal is not a free input, it is compiled from the event in-circuit.
//!
//! Realizes EVENT-COMPLETE/1 (sites/ledger/specs/applications) obligations
//! 4 (canonical compilation), 5 (P^n zero-account), and 10 (recomputation:
//! every public commitment is recomputed from the witness and equated). Roles,
//! attestations, fact_fold, and nullifiers (obligations 1-3, 7-9) are follow-on.
//!
//! Public ABI (a subset of the BalancedVectorReceipt, spec S5): event_commitment,
//! journal_commitment. Proven end-to-end under UltraHonk (bb) on Apple Silicon.

use pacioli::journal_balanced;
use rulebook::{compile_goods_receipt_invoice, GoodsReceiptInvoice};

global N_BASIS: u32 = 3;
global N_ROWS: u32 = 4;
// Application-target domain tags (3/PROOF Annex A range 120-255; R1 assigns).
global TAG_EVENT: Field = 120;
global TAG_JOURNAL: Field = 121;

/// Recompute the event commitment from the typed quantities. A minimal binding;
/// a deployment commits the full 2/FACT enc(E).
fn event_commitment(e: GoodsReceiptInvoice) -> Field {
    std::hash::pedersen_hash([TAG_EVENT, e.usd_cents as Field, e.fabric_meters as Field])
}

/// Recompute journal_commitment over the rows (the order-binding fold of
/// TRANSITION/1). Applied to the COMPILED journal, it commits to Phi_R(event).
fn journal_commitment_of(d: [[u64; N_BASIS]; N_ROWS], c: [[u64; N_BASIS]; N_ROWS]) -> Field {
    let mut jc = std::hash::pedersen_hash([TAG_JOURNAL, 0]);
    for r in 0..N_ROWS {
        let mut buf: [Field; 2 + 2 * N_BASIS] = [0; 2 + 2 * N_BASIS];
        buf[0] = TAG_JOURNAL;
        buf[1] = jc;
        for b in 0..N_BASIS {
            buf[2 + b] = d[r][b] as Field;
            buf[2 + N_BASIS + b] = c[r][b] as Field;
        }
        jc = std::hash::pedersen_hash(buf);
    }
    jc
}

fn main(
    event_commitment_pub: pub Field,
    journal_commitment_pub: pub Field,
    // private witness: the typed event quantities q of Phi_R(E, q, ...)
    usd_cents: u64,
    fabric_meters: u64,
) {
    let e = GoodsReceiptInvoice { usd_cents, fabric_meters };

    // obligation 2/10: bind the event commitment to the witnessed event.
    assert(event_commitment(e) == event_commitment_pub, "event_commitment does not commit the event");

    // obligation 4: canonical compilation -- J = Phi_R(E), in-circuit.
    let j = compile_goods_receipt_invoice(e);

    // obligation 5: J is a P^n zero-account.
    assert(journal_balanced(j.debits, j.credits), "compiled journal is not a zero-account");

    // obligation 10: journal_commitment is recomputed over the COMPILED journal,
    // so it provably commits to Phi_R(E), not an arbitrary balanced journal.
    let jc = journal_commitment_of(j.debits, j.credits);
    assert(jc == journal_commitment_pub, "journal_commitment is not the schema image of the event");
}

// -- the honest public inputs, shared by the tests --
fn ec(e: GoodsReceiptInvoice) -> Field {
    event_commitment(e)
}
fn jc(e: GoodsReceiptInvoice) -> Field {
    let j = compile_goods_receipt_invoice(e);
    journal_commitment_of(j.debits, j.credits)
}

#[test]
fn accepts_the_schema_image() {
    let e = GoodsReceiptInvoice { usd_cents: 10000, fabric_meters: 50 };
    main(ec(e), jc(e), 10000, 50);
}

// The decisive property: you cannot pair an event commitment with a journal
// commitment that is not the schema's image of THAT event.
#[test(should_fail_with = "journal_commitment is not the schema image of the event")]
fn rejects_journal_commitment_from_a_different_event() {
    let a = GoodsReceiptInvoice { usd_cents: 10000, fabric_meters: 50 };
    let b = GoodsReceiptInvoice { usd_cents: 99999, fabric_meters: 7 };
    main(ec(a), jc(b), 10000, 50); // event A's commitment, event B's journal
}

#[test(should_fail_with = "event_commitment does not commit the event")]
fn rejects_tampered_event_commitment() {
    let e = GoodsReceiptInvoice { usd_cents: 10000, fabric_meters: 50 };
    main(ec(e) + 1, jc(e), 10000, 50);
}

#[test]
fn print_public_inputs() {
    let e = GoodsReceiptInvoice { usd_cents: 10000, fabric_meters: 50 };
    println(ec(e));
    println(jc(e));
}
