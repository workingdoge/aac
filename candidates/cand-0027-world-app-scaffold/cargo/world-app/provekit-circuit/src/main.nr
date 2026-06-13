//! aac_receipt_provekit -- a RIGHT-SIZED EVENT-COMPLETE/1 BalancedVectorReceipt,
//! re-expressed for the ProveKit (Noir beta.19 -> ACIR -> R1CS -> WHIR) toolchain.
//!
//! This is NOT a copy of `circuits/event-complete` (beta.14, bb/UltraHonk). It is a
//! semantic RE-EXPRESSION on a different toolchain (Design Note 0002 S5):
//!   - small fixed basis (3 incommensurable dimensions)
//!   - small fixed schema (4 rows / 2 roles)
//!   - per-dimension vector debit/credit sums proven equal (P^n zero-account)
//!   - range-bounded non-negative coordinates (u64 carrier discipline)
//!   - a one-shot EVENT-scoped nullifier
//!   - one journal commitment / leaf hash
//! and it uses the native sponge hash (Skyscraper at integration; Poseidon2
//! placeholder here) rather than pedersen, so commitment VALUES differ by design.
//!
//! Obligations realized (EVENT-COMPLETE/1 S4), same scoped subset as the beta.14
//! reference: 2 (role coverage), 4 (J = Phi_R(E) in-circuit), 5 (P^n zero-account),
//! 9 in EVENT-SCOPED narrowed form, 10 for the carried commitments. Deferred: 1, 3,
//! 6's per-dimension MAX_j, 7, 8, and the basis/nullifier/evidence recomputations of
//! the full S5 ABI -- identical deferral set to the reference circuit.

mod hash;
mod pacioli;
mod rulebook;
mod ledger;

use pacioli::journal_balanced;
use rulebook::{compile_goods_receipt_invoice, event_commitment, GoodsReceiptInvoice};
use ledger::{event_nullifier, journal_commitment, participant_set};

/// Public ABI (order normative for this right-sized receipt; a SUBSET of the full
/// EVENT-COMPLETE/1 S5 ABI, matching what the beta.14 reference carries):
///   0 rulebook_id            unconstrained (bound by deployment policy)
///   1 event_commitment_pub   recomputed from witnessed E
///   2 participant_set_pub    recomputed; role coverage proven
///   3 journal_commitment_pub recomputed over the COMPILED journal (order-binding)
///   4 event_nullifier_pub    recomputed; one-shot, != 0 sentinel
///
/// Private witness: the typed quantities `q` and the two party ids.
///
/// ProveKit note: with ProveKit, `pub` inputs become the proof's public inputs and
/// the rest are the private witness, exactly as here. `prepare` is run once over
/// THIS `main` to produce the reusable prover/verifier keys; `prove` then takes a
/// witness (built from a Prover.toml or the WASM witness builder) and emits a WHIR
/// proof over these 5 public inputs. See README.
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
    // The journal is the SCHEMA's image (rulebook.nr), not an arbitrary balanced
    // input -- this is the "fraud can balance" defence. journal_balanced then proves
    // the per-dimension vector sums agree (USD with USD, fabric with fabric).
    let j = compile_goods_receipt_invoice(e);
    assert(journal_balanced(j.debits, j.credits), "compiled journal is not a zero-account");

    // obligation 6 (carrier): every coordinate is a u64, hence non-negative and
    // < 2^64. The u64 type enforces the range at witness time; pacioli::assert_in_carrier
    // marks where a tighter per-dimension MAX_j would go.
    pacioli::assert_in_carrier(usd_cents);
    pacioli::assert_in_carrier(fabric_meters);

    // obligation 10: journal_commitment recomputed over the COMPILED journal -- the
    // leaf hash a TRANSITION/1 posting would carry.
    assert(
        journal_commitment(j.accounts, j.debits, j.credits) == journal_commitment_pub,
        "journal_commitment is not the schema image of the event",
    );

    // obligation 9 (event-scoped): the one-shot nullifier, derived in-circuit from
    // the committed event and parties. Asserted != 0 because 0 is the empty-slot
    // sentinel a registry reserves (a 0 nullifier could never be consumed).
    let n = event_nullifier(rulebook_id, event_commitment_pub, ps);
    assert(n != 0, "event_nullifier is the 0 sentinel");
    assert(n == event_nullifier_pub, "event_nullifier incorrectly derived");
}

// ----------------------------------------------------------------------------
// Tests. `nargo test` (beta.19) runs these. They will NOT run in THIS environment
// (no beta.19 nargo; this env's flake pins beta.14 and nargo is not even on PATH).
// Run them where the ProveKit toolchain is installed: `nargo test`.
// ----------------------------------------------------------------------------

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
    // Use this to fill Prover.toml: run `nargo test --show-output print_public_inputs`.
    let e = GoodsReceiptInvoice { usd_cents: 10000, fabric_meters: 50 };
    let ps = participant_set(111, 222);
    println(event_commitment(e));
    println(ps);
    println(jc(e));
    println(event_nullifier(7, event_commitment(e), ps));
}
