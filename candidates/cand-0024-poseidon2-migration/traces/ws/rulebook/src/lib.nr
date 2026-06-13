//! rulebook -- a Phi_R event-to-journal compiler.
//!
//! Phi_R is the deterministic rulebook of Design Note 0001 / EVENT-COMPLETE/1:
//! `J = Phi_R(E, q, evidence, roles)`. This crate realizes one schema --
//! goods-receipt-invoice -- and closes "fraud can balance" with running code:
//! the journal is the schema's image, not an arbitrary input. Because every
//! quantity is posted once as a debit and once as a credit, `compile(q)` is a
//! P^n zero-account for ANY q -- balance is a theorem of the schema.

use pacioli::journal_balanced;

global N_BASIS: u32 = 3; // basis [USD_cents, fabric_meters, garment_units]
global N_ROWS: u32 = 4; // the goods-receipt-invoice schema posts four rows
global USD: u32 = 0;
global FABRIC: u32 = 1;

// The schema's accounts (indices into the chart; a deployment records R1).
global ACC_BUYER_INVENTORY: u32 = 0;
global ACC_SUPPLIER_RECEIVABLE: u32 = 1;
global ACC_SUPPLIER_INVENTORY: u32 = 2;
global ACC_BUYER_PAYABLE: u32 = 3;

// Schema event-commitment tag (application range; R1 assigns).
global TAG_EVENT: Field = 120;

/// A typed commercial event: a buyer receives goods from a supplier under an
/// invoice. The private quantities `q` of `Phi_R(E, q, ...)`.
pub struct GoodsReceiptInvoice {
    pub usd_cents: u64,
    pub fabric_meters: u64,
}

/// The compiled vector journal: account index + debit/credit vectors per row.
pub struct CompiledJournal {
    pub accounts: [u32; N_ROWS],
    pub debits: [[u64; N_BASIS]; N_ROWS],
    pub credits: [[u64; N_BASIS]; N_ROWS],
}

/// The schema's canonical event commitment over the typed quantities.
pub fn event_commitment(e: GoodsReceiptInvoice) -> Field {
    hash::poseidon_hash([TAG_EVENT, e.usd_cents as Field, e.fabric_meters as Field])
}

/// Phi_R for the goods-receipt-invoice schema. Each quantity is posted once Dr
/// and once Cr across the schema's accounts, so the result is a zero-account.
///
///   row 0  Buyer * Inventory       Dr  goods in   (fabric)
///   row 1  Supplier * Receivable   Dr  money owed (USD)
///   row 2  Supplier * Inventory    Cr  goods out  (fabric)
///   row 3  Buyer * Payable         Cr  obligation (USD)
pub fn compile_goods_receipt_invoice(e: GoodsReceiptInvoice) -> CompiledJournal {
    let accounts = [
        ACC_BUYER_INVENTORY,
        ACC_SUPPLIER_RECEIVABLE,
        ACC_SUPPLIER_INVENTORY,
        ACC_BUYER_PAYABLE,
    ];
    let mut debits: [[u64; N_BASIS]; N_ROWS] = [[0; N_BASIS]; N_ROWS];
    let mut credits: [[u64; N_BASIS]; N_ROWS] = [[0; N_BASIS]; N_ROWS];
    debits[0][FABRIC] = e.fabric_meters;
    debits[1][USD] = e.usd_cents;
    credits[2][FABRIC] = e.fabric_meters;
    credits[3][USD] = e.usd_cents;
    CompiledJournal { accounts, debits, credits }
}

#[test]
fn phi_reproduces_the_conformance_vector() {
    let j = compile_goods_receipt_invoice(GoodsReceiptInvoice { usd_cents: 10000, fabric_meters: 50 });
    let exp_d = [[0, 50, 0], [10000, 0, 0], [0, 0, 0], [0, 0, 0]];
    let exp_c = [[0, 0, 0], [0, 0, 0], [0, 50, 0], [10000, 0, 0]];
    assert(j.accounts == [0, 1, 2, 3]);
    for r in 0..N_ROWS {
        for b in 0..N_BASIS {
            assert(j.debits[r][b] == exp_d[r][b]);
            assert(j.credits[r][b] == exp_c[r][b]);
        }
    }
    assert(journal_balanced(j.debits, j.credits));
}

#[test]
fn phi_is_balanced_for_all_quantities() {
    let cases = [[0, 0], [1, 1], [10000, 50], [99, 250000], [18446744073709551615, 123]];
    for i in 0..5 {
        let j = compile_goods_receipt_invoice(GoodsReceiptInvoice { usd_cents: cases[i][0], fabric_meters: cases[i][1] });
        assert(journal_balanced(j.debits, j.credits), "schema compiled to an unbalanced journal");
    }
}
