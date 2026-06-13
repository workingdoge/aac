//! EVENT-COMPLETE/1 -- the schema-complete event-compilation proof, with role
//! coverage and the one-shot event nullifier.
//!
//! Phi_R wired into a proof: the prover witnesses the TYPED EVENT and its PARTIES,
//! the circuit runs the rulebook compiler in-circuit and binds journal_commitment
//! to the compiled journal. A verifier learns that journal_commitment commits to
//! Phi_R(event) -- the schema's image of the committed event, a P^n zero-account.
//!
//! This revision adds two obligations toward a complete BalancedVectorReceipt:
//!   - role coverage (obligation 2): the schema's required roles -- Buyer and
//!     Supplier -- are present and distinct; participant_set commits them.
//!   - the event nullifier (obligation 9): a one-shot identity
//!     N = H(rulebook_id, event_commitment, participant_set), derived IN-CIRCUIT.
//!     Because N is bound to the committed event and parties, a prover cannot
//!     replay the same event under a fresh nullifier -- the registry inserts N
//!     once and refuses it thereafter (1/PACI S5, 2/FACT S3/S8). This is the
//!     anti-double-application guard.
//!
//! Realizes EVENT-COMPLETE/1 obligations 2, 4, 5, 9, 10 (sites/ledger/specs/
//! applications). Attestations (3), event_id-in-facts (7), and fact_fold (8) are
//! follow-on. Public ABI (a subset of the BVR, spec S5): rulebook_id,
//! event_commitment, participant_set, journal_commitment, event_nullifier.
//! Proven end-to-end under UltraHonk (bb) on Apple Silicon.

use pacioli::journal_balanced;
use rulebook::{compile_goods_receipt_invoice, GoodsReceiptInvoice};

global N_BASIS: u32 = 3;
global N_ROWS: u32 = 4;
// Application-target domain tags (3/PROOF Annex A range 120-255; R1 assigns).
global TAG_EVENT: Field = 120;
global TAG_JOURNAL: Field = 121;
global TAG_PARTY: Field = 122;
global TAG_NULL: Field = 123;

fn event_commitment(e: GoodsReceiptInvoice) -> Field {
    std::hash::pedersen_hash([TAG_EVENT, e.usd_cents as Field, e.fabric_meters as Field])
}

/// Commit the parties filling the schema's roles (Buyer, Supplier).
fn participant_set(buyer: Field, supplier: Field) -> Field {
    std::hash::pedersen_hash([TAG_PARTY, buyer, supplier])
}

/// The one-shot event identity: scoped to the rulebook, the event, and the
/// parties so distinct scopes cannot collide (2/FACT S8 identity-stuffing).
fn nullifier(rulebook_id: Field, ec: Field, ps: Field) -> Field {
    std::hash::pedersen_hash([TAG_NULL, rulebook_id, ec, ps])
}

/// journal_commitment over the rows (the order-binding fold). Over the COMPILED
/// journal it commits to Phi_R(event).
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
    rulebook_id: pub Field, // #0 unconstrained -- bound by deployment policy
    event_commitment_pub: pub Field, // #1
    participant_set_pub: pub Field, // #2
    journal_commitment_pub: pub Field, // #3
    event_nullifier_pub: pub Field, // #4
    // private witness: the typed event quantities and the parties
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

    // obligation 10: journal_commitment recomputed over the COMPILED journal --
    // it provably commits to Phi_R(E), not an arbitrary balanced journal.
    assert(
        journal_commitment_of(j.debits, j.credits) == journal_commitment_pub,
        "journal_commitment is not the schema image of the event",
    );

    // obligation 9: the one-shot nullifier, derived in-circuit from the committed
    // event and parties -- a replay cannot mint a fresh identity for this event.
    assert(
        nullifier(rulebook_id, event_commitment_pub, ps) == event_nullifier_pub,
        "event_nullifier incorrectly derived",
    );
}

// shared honest-prover helpers for the tests
fn ec(e: GoodsReceiptInvoice) -> Field {
    event_commitment(e)
}
fn jc(e: GoodsReceiptInvoice) -> Field {
    let j = compile_goods_receipt_invoice(e);
    journal_commitment_of(j.debits, j.credits)
}

#[test]
fn accepts_a_complete_receipt() {
    let e = GoodsReceiptInvoice { usd_cents: 10000, fabric_meters: 50 };
    let ps = participant_set(111, 222);
    main(7, ec(e), ps, jc(e), nullifier(7, ec(e), ps), 10000, 50, 111, 222);
}

#[test(should_fail_with = "one party fills both roles")]
fn rejects_self_dealing() {
    let e = GoodsReceiptInvoice { usd_cents: 10000, fabric_meters: 50 };
    let ps = participant_set(111, 111);
    main(7, ec(e), ps, jc(e), nullifier(7, ec(e), ps), 10000, 50, 111, 111);
}

#[test(should_fail_with = "missing Buyer role")]
fn rejects_missing_role() {
    let e = GoodsReceiptInvoice { usd_cents: 10000, fabric_meters: 50 };
    let ps = participant_set(0, 222);
    main(7, ec(e), ps, jc(e), nullifier(7, ec(e), ps), 10000, 50, 0, 222);
}

// The anti-replay binding: same event+parties, but a nullifier from a DIFFERENT
// event is rejected -- you cannot apply this event under a foreign identity.
#[test(should_fail_with = "event_nullifier incorrectly derived")]
fn rejects_replay_under_a_foreign_nullifier() {
    let e = GoodsReceiptInvoice { usd_cents: 10000, fabric_meters: 50 };
    let other = GoodsReceiptInvoice { usd_cents: 1, fabric_meters: 1 };
    let ps = participant_set(111, 222);
    main(7, ec(e), ps, jc(e), nullifier(7, ec(other), ps), 10000, 50, 111, 222);
}

#[test]
fn nullifier_is_event_and_party_distinguishing() {
    // different event OR parties OR rulebook => a different one-shot identity, so
    // a replay cannot disguise itself (2/FACT S8 identity-stuffing).
    let a = GoodsReceiptInvoice { usd_cents: 10000, fabric_meters: 50 };
    let b = GoodsReceiptInvoice { usd_cents: 10000, fabric_meters: 51 };
    let ps1 = participant_set(111, 222);
    let ps2 = participant_set(111, 333);
    assert(nullifier(7, ec(a), ps1) != nullifier(7, ec(b), ps1), "same nullifier for different events");
    assert(nullifier(7, ec(a), ps1) != nullifier(7, ec(a), ps2), "same nullifier for different parties");
    assert(nullifier(7, ec(a), ps1) != nullifier(8, ec(a), ps1), "same nullifier across rulebooks");
}

#[test]
fn print_public_inputs() {
    let e = GoodsReceiptInvoice { usd_cents: 10000, fabric_meters: 50 };
    let ps = participant_set(111, 222);
    println(ec(e));
    println(ps);
    println(jc(e));
    println(nullifier(7, ec(e), ps));
}
