//! bom-receipt -- a SECOND posting program (Phi_P), to validate that the EVENT/1
//! harness (`circuits/event-harness`) is genuinely reusable and not accidentally
//! fit to the goods-receipt-invoice schema. Where `rulebook` compiles a 2-good
//! trade over basis B=3, this compiles a BILL-OF-MATERIALS receipt over basis B=4
//! and DENSE debit/credit vectors -- so it exercises `discharge<R, B>` at a
//! different B and a different journal shape with the SAME glue.
//!
//! WHY a kit RECEIPT and not an assembly TRANSFORM. The harness requires a
//! per-dimension zero-account (pacioli::journal_balanced): for every basis
//! coordinate, total debits == total credits. An EXCHANGE has this -- each good
//! is conserved, merely transferred (supplier -> buyer), and cash flows the other
//! way. A literal assembly (fabric + thread -> garment) does NOT: it CONSUMES
//! incommensurable input dimensions and PRODUCES a different output dimension, and
//! incommensurable coordinates cannot offset (Ellerman vector Pacioli, 1/PACI).
//! So an assembly transform is not a balanced BVR; only a transfer/exchange is.
//! A cut-and-sew shop's materials purchase IS an exchange: a kit of fabric +
//! thread + trim moves supplier -> buyer against USD. Each of the four
//! coordinates is conserved -> a zero-account, for ANY quantities -- balance is a
//! theorem of the schema, exactly as for `rulebook`.

use pacioli::journal_balanced;
use event_harness::CompiledJournal;

global N_BASIS: u32 = 4; // basis [USD_cents, fabric_meters, thread_spools, trim_units]
global N_ROWS: u32 = 4; // the kit-receipt schema posts four rows (same chart as rulebook)
global USD: u32 = 0;
global FABRIC: u32 = 1;
global THREAD: u32 = 2;
global TRIM: u32 = 3;

// The schema's accounts (indices into the chart; a deployment records R1). The
// buyer/supplier inventory + receivable/payable chart is shared with `rulebook`.
global ACC_BUYER_INVENTORY: u32 = 0;
global ACC_SUPPLIER_RECEIVABLE: u32 = 1;
global ACC_SUPPLIER_INVENTORY: u32 = 2;
global ACC_BUYER_PAYABLE: u32 = 3;

// Schema event-commitment tag. A DISTINCT tag (R1 = 126), not rulebook's 120:
// event_commitment does not bind the posting_program_id, so a per-schema tag is
// what keeps two schemas' commitments from sharing a preimage (3/PROOF S3).
global TAG_EVENT: Field = 126;

/// A typed commercial event: a garment maker (buyer) receives a kit of materials
/// -- fabric, thread, trim -- from a supplier under an invoice. The private
/// quantities `q` of `Phi_P(E, q, ...)`.
pub struct MaterialsKitReceipt {
    pub usd_cents: u64,
    pub fabric_meters: u64,
    pub thread_spools: u64,
    pub trim_units: u64,
}

/// The schema's canonical event commitment over the typed quantities.
pub fn event_commitment(e: MaterialsKitReceipt) -> Field {
    hash::poseidon_hash([
        TAG_EVENT,
        e.usd_cents as Field,
        e.fabric_meters as Field,
        e.thread_spools as Field,
        e.trim_units as Field,
    ])
}

/// Phi_P for the materials-kit-receipt schema. The three materials are posted as
/// ONE dense Dr vector into buyer inventory and the matching Cr vector out of
/// supplier inventory; cash is posted Dr supplier-receivable / Cr buyer-payable.
/// Every basis coordinate is posted once Dr and once Cr, so the result is a
/// zero-account for ANY quantities.
///
///   row 0  Buyer * Inventory       Dr  [_, fabric, thread, trim]  (kit in)
///   row 1  Supplier * Receivable   Dr  [usd, _, _, _]             (money owed)
///   row 2  Supplier * Inventory    Cr  [_, fabric, thread, trim]  (kit out)
///   row 3  Buyer * Payable         Cr  [usd, _, _, _]             (obligation)
pub fn compile_materials_kit_receipt(e: MaterialsKitReceipt) -> CompiledJournal<N_ROWS, N_BASIS> {
    let accounts = [
        ACC_BUYER_INVENTORY,
        ACC_SUPPLIER_RECEIVABLE,
        ACC_SUPPLIER_INVENTORY,
        ACC_BUYER_PAYABLE,
    ];
    let mut debits: [[u64; N_BASIS]; N_ROWS] = [[0; N_BASIS]; N_ROWS];
    let mut credits: [[u64; N_BASIS]; N_ROWS] = [[0; N_BASIS]; N_ROWS];
    debits[0][FABRIC] = e.fabric_meters;
    debits[0][THREAD] = e.thread_spools;
    debits[0][TRIM] = e.trim_units;
    debits[1][USD] = e.usd_cents;
    credits[2][FABRIC] = e.fabric_meters;
    credits[2][THREAD] = e.thread_spools;
    credits[2][TRIM] = e.trim_units;
    credits[3][USD] = e.usd_cents;
    CompiledJournal { accounts, debits, credits }
}

#[test]
fn phi_reproduces_the_conformance_vector() {
    let j = compile_materials_kit_receipt(MaterialsKitReceipt {
        usd_cents: 10000,
        fabric_meters: 50,
        thread_spools: 8,
        trim_units: 120,
    });
    // basis order: [USD, fabric, thread, trim]
    let exp_d = [[0, 50, 8, 120], [10000, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]];
    let exp_c = [[0, 0, 0, 0], [0, 0, 0, 0], [0, 50, 8, 120], [10000, 0, 0, 0]];
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
    let cases = [
        [0, 0, 0, 0],
        [1, 1, 1, 1],
        [10000, 50, 8, 120],
        [99, 250000, 3, 7],
        [18446744073709551615, 123, 18446744073709551615, 1],
    ];
    for i in 0..5 {
        let j = compile_materials_kit_receipt(MaterialsKitReceipt {
            usd_cents: cases[i][0],
            fabric_meters: cases[i][1],
            thread_spools: cases[i][2],
            trim_units: cases[i][3],
        });
        assert(journal_balanced(j.debits, j.credits), "schema compiled to an unbalanced journal");
    }
}
