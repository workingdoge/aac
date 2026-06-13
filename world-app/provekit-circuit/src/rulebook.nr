//! rulebook.nr -- a Phi_R event-to-journal compiler, re-expressed for ProveKit.
//!
//! Phi_R is the deterministic rulebook of EVENT-COMPLETE/1:
//! `J = Phi_R(E, q, evidence, roles)`. This realizes ONE schema --
//! goods-receipt-invoice -- and closes "fraud can balance" with running code: the
//! journal is the schema's IMAGE, not an arbitrary input. Because every quantity is
//! posted exactly once as a debit and once as a credit, `compile(q)` is a P^n
//! zero-account for ANY q -- balance is a theorem of the schema, not a check on the
//! prover. Mirrors `circuits/rulebook` (beta.14) but on a 3-dim basis / 4-row schema
//! kept deliberately small for ProveKit (Design Note 0002 S5).

use crate::hash::hash;

// --- right-sized basis: 3 incommensurable dimensions (Design Note 0001 S1) ---
pub global N_BASIS: u32 = 3; // [USD_cents, fabric_meters, garment_units]
pub global N_ROWS: u32 = 4; // the goods-receipt-invoice schema posts four rows

pub global USD: u32 = 0;
pub global FABRIC: u32 = 1;
// dimension 2 (garment_units) is in the basis but unused by THIS schema -- it
// exists so the basis is genuinely multi-dimensional and a future schema can post
// to it without a basis change.

// the schema's accounts (indices into the chart; a deployment records R1)
pub global ACC_BUYER_INVENTORY: u32 = 0;
pub global ACC_SUPPLIER_RECEIVABLE: u32 = 1;
pub global ACC_SUPPLIER_INVENTORY: u32 = 2;
pub global ACC_BUYER_PAYABLE: u32 = 3;

// schema event-commitment domain tag (application range 120-255; R1 assigns).
// Same tag value as the beta.14 reference for cross-reading convenience, though the
// hash primitive differs so the resulting field image differs.
pub global TAG_EVENT: Field = 120;

/// A typed commercial event: a buyer receives goods from a supplier under an invoice.
/// The private quantities `q` of `Phi_R(E, q, ...)`.
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
    hash([TAG_EVENT, e.usd_cents as Field, e.fabric_meters as Field])
}

/// Phi_R for goods-receipt-invoice. Each quantity is posted once Dr and once Cr,
/// so the result is a P^n zero-account by construction:
///
///   row 0  Buyer.Inventory       Dr  goods in   (fabric)
///   row 1  Supplier.Receivable   Dr  money owed (USD)
///   row 2  Supplier.Inventory    Cr  goods out  (fabric)
///   row 3  Buyer.Payable         Cr  obligation (USD)
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
