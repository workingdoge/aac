//! rulebook -- a Phi_R event-to-journal compiler.
//!
//! Phi_R is the deterministic rulebook of Design Note 0001 / EVENT-COMPLETE/1:
//! `J = Phi_R(E, q, evidence, roles)`. This crate realizes one schema --
//! goods-receipt-invoice -- and closes the "fraud can balance" problem with
//! running code. A balanced journal is not a complete one: parties could submit
//! arbitrary offsetting entries that net to zero yet describe no real event.
//! Completeness comes from *deriving* the journal from a typed event, so the
//! journal is the schema's image, not an arbitrary input.
//!
//! Correspondence to EVENT-COMPLETE/1 (sites/ledger/specs/applications):
//!   compile_*  <-> obligation 4 (canonical compilation Phi_R(E,q,...) = J)
//!   the tests  <-> obligation 5 (J is a P^n zero-account)
//!
//! The structural guarantee: because every quantity is posted exactly once as a
//! debit and once as a credit, `compile(q)` is a zero-account in P^n for ANY
//! quantities q -- balance is a theorem of the schema, not a check on inputs.

use pacioli::journal_balanced;

global N_BASIS: u32 = 3; // basis [USD_cents, fabric_meters, garment_units]
global N_ROWS: u32 = 4; // the goods-receipt-invoice schema posts four rows

// Basis dimension indices (a deployment records the basis in Register R1).
global USD: u32 = 0;
global FABRIC: u32 = 1;

/// A typed commercial event: a buyer receives goods from a supplier under an
/// invoice. The private quantities `q` of `Phi_R(E, q, ...)`.
pub struct GoodsReceiptInvoice {
    usd_cents: u64, // the invoice amount (USD dimension)
    fabric_meters: u64, // the goods received (fabric dimension)
}

/// The compiled vector journal: per-row debit and credit vectors over the basis.
pub struct CompiledJournal {
    debits: [[u64; N_BASIS]; N_ROWS],
    credits: [[u64; N_BASIS]; N_ROWS],
}

/// Phi_R for the goods-receipt-invoice schema. Deterministic: the journal is a
/// pure function of the event's quantities. Double-entry is structural -- each
/// quantity is posted once as a debit and once as a credit:
///
///   row 0  Buyer * Inventory       Dr  goods in   (fabric)
///   row 1  Supplier * Receivable   Dr  money owed (USD)
///   row 2  Supplier * Inventory    Cr  goods out  (fabric)
///   row 3  Buyer * Payable         Cr  obligation (USD)
///
/// so the result is a P^n zero-account for ANY input (see the tests).
pub fn compile_goods_receipt_invoice(e: GoodsReceiptInvoice) -> CompiledJournal {
    let mut debits: [[u64; N_BASIS]; N_ROWS] = [[0; N_BASIS]; N_ROWS];
    let mut credits: [[u64; N_BASIS]; N_ROWS] = [[0; N_BASIS]; N_ROWS];
    debits[0][FABRIC] = e.fabric_meters; // Buyer * Inventory
    debits[1][USD] = e.usd_cents; // Supplier * Receivable
    credits[2][FABRIC] = e.fabric_meters; // Supplier * Inventory
    credits[3][USD] = e.usd_cents; // Buyer * Payable
    CompiledJournal { debits, credits }
}

#[test]
fn phi_reproduces_the_conformance_vector() {
    // compile({usd: 100.00, fabric: 50m}) must equal the P^n conformance journal
    // the pacioli crate hard-codes -- the journal is DERIVED, not asserted.
    let j = compile_goods_receipt_invoice(
        GoodsReceiptInvoice { usd_cents: 10000, fabric_meters: 50 },
    );
    let exp_d = [[0, 50, 0], [10000, 0, 0], [0, 0, 0], [0, 0, 0]];
    let exp_c = [[0, 0, 0], [0, 0, 0], [0, 50, 0], [10000, 0, 0]];
    for r in 0..N_ROWS {
        for b in 0..N_BASIS {
            assert(j.debits[r][b] == exp_d[r][b], "compiled debit diverges from the conformance vector");
            assert(j.credits[r][b] == exp_c[r][b], "compiled credit diverges from the conformance vector");
        }
    }
    assert(journal_balanced(j.debits, j.credits));
}

#[test]
fn phi_is_balanced_for_all_quantities() {
    // The schema guarantees a zero-account regardless of the private quantities,
    // because each quantity is posted once Dr and once Cr. This is the
    // completeness guarantee: fraud cannot balance, since the journal is the
    // schema's deterministic image -- you cannot inject fictitious offsetting
    // entries without changing the event quantities.
    let cases = [[0, 0], [1, 1], [10000, 50], [99, 250000], [18446744073709551615, 123]];
    for i in 0..5 {
        let j = compile_goods_receipt_invoice(
            GoodsReceiptInvoice { usd_cents: cases[i][0], fabric_meters: cases[i][1] },
        );
        assert(journal_balanced(j.debits, j.credits), "schema compiled to an unbalanced journal");
    }
}
