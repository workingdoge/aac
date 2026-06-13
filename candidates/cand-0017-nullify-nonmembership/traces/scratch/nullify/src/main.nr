// NULLIFY/1 (3/PROOF S4.2) -- non-membership + insertion into the nullifier set.
//
// The set is an indexed structure: a strictly-ascending list of consumed
// nullifiers (the sorted-leaf invariant; +infinity closes the top range).
// Non-membership of a new nullifier v is a LOW-LEAF range bracket: v lies
// strictly between two consecutive members (or beyond the last / before the
// first), so v is provably absent -- and an already-spent v has no such gap
// (it equals a neighbour), so the bracket fails. This is the anti-replay guard
// against the HISTORICAL set, not just the batch-local distinctness of
// TRANSITION/1. Nullifier values are full Field elements, ordered as 254-bit
// integers via std::field::bn254::lt.
//
// Bound (honest): one insertion (count = 1) into a fixed set of N_OLD members,
// the root a Pedersen fold over the sorted members. A production NULLIFY/1 uses
// a binary indexed Merkle tree with succinct low-leaf path proofs (Aztec, depth
// ~32, leaf {value, next_index, next_value}); a sequence chains single
// insertions. The non-membership LOGIC here is identical: the low-leaf range
// bracket over a sorted-invariant set.

use ledger::{event_nullifier, participant_set};
use rulebook::{compile_goods_receipt_invoice, event_commitment, GoodsReceiptInvoice};
use std::field::bn254::lt;

global N_OLD: u32 = 4;
global N_NEW: u32 = 5; // = N_OLD + 1
global TAG_SET: Field = 64; // NULLIFY family (3/PROOF Annex A, 64-95)
global TAG_SEQ: Field = 65;

fn set_root(values: [Field; N_OLD]) -> Field {
    let mut acc = std::hash::pedersen_hash([TAG_SET, 0]);
    for i in 0..N_OLD {
        acc = std::hash::pedersen_hash([TAG_SET, acc, values[i]]);
    }
    acc
}
fn set_root_new(values: [Field; N_NEW]) -> Field {
    let mut acc = std::hash::pedersen_hash([TAG_SET, 0]);
    for i in 0..N_NEW {
        acc = std::hash::pedersen_hash([TAG_SET, acc, values[i]]);
    }
    acc
}

fn main(
    first_root: pub Field,
    last_root: pub Field,
    sequence_commitment: pub Field,
    count: pub u32,
    // witness
    old_values: [Field; N_OLD], // the consumed-nullifier set, strictly ascending
    new_value: Field, // the nullifier to consume (a non-member)
    low_index: u32, // insertion position in [0, N_OLD]: the low-leaf bracket
) {
    assert(count == 1, "this NULLIFY/1 bound proves a single insertion");
    assert(low_index <= N_OLD, "low_index out of range");

    // (a) the indexed-set invariant: strictly ascending (so the low-leaf is unique).
    for i in 0..N_OLD - 1 {
        assert(lt(old_values[i], old_values[i + 1]), "nullifier set is not strictly sorted");
    }

    // (b) non-membership via the low-leaf range bracket. low_index is the count of
    //     members below new_value; the bracket is (lower, upper) with lower the
    //     member just below (if any) and upper the member just above (if any).
    let has_lower = low_index != 0;
    let has_upper = low_index != N_OLD;
    if has_lower {
        assert(lt(old_values[low_index - 1], new_value), "low-leaf does not bracket below");
    }
    if has_upper {
        assert(lt(new_value, old_values[low_index]), "low-leaf does not bracket above");
    }
    // new_value strictly between neighbours over a strictly-sorted set => non-member.

    // (c) splice new_value in at low_index, preserving sort order.
    let mut new_values: [Field; N_NEW] = [0; N_NEW];
    for i in 0..N_NEW {
        if i < low_index {
            new_values[i] = old_values[i];
        } else if i == low_index {
            new_values[i] = new_value;
        } else {
            new_values[i] = old_values[i - 1];
        }
    }

    // (d) roots: first over the old set, last over the new; sequence_commitment
    //     folds the resulting (single) intermediate root.
    assert(set_root(old_values) == first_root, "first_root does not commit the set");
    let lr = set_root_new(new_values);
    assert(lr == last_root, "last_root does not commit the post-insertion set");
    let sc = std::hash::pedersen_hash([TAG_SEQ, lr]);
    assert(sc == sequence_commitment, "sequence_commitment mismatch");
}

// honest-prover helpers
fn fr(old_values: [Field; N_OLD]) -> Field {
    set_root(old_values)
}
fn lr_sc(old_values: [Field; N_OLD], v: Field, low: u32) -> (Field, Field) {
    let mut nv: [Field; N_NEW] = [0; N_NEW];
    for i in 0..N_NEW {
        if i < low {
            nv[i] = old_values[i];
        } else if i == low {
            nv[i] = v;
        } else {
            nv[i] = old_values[i - 1];
        }
    }
    let r = set_root_new(nv);
    (r, std::hash::pedersen_hash([TAG_SEQ, r]))
}

#[test]
fn accepts_a_non_member_insertion() {
    let s = [10, 20, 30, 40];
    let v = 25; // strictly between 20 and 30 -> low_index 2
    let (lr, sc) = lr_sc(s, v, 2);
    main(fr(s), lr, sc, 1, s, v, 2);
}

#[test]
fn accepts_insert_after_last() {
    let s = [10, 20, 30, 40];
    let v = 99; // beyond the last -> low_index 4
    let (lr, sc) = lr_sc(s, v, 4);
    main(fr(s), lr, sc, 1, s, v, 4);
}

#[test(should_fail_with = "low-leaf does not bracket above")]
fn rejects_already_spent_nullifier() {
    // v == an existing member (already consumed): no gap brackets it -> rejected.
    let s = [10, 20, 30, 40];
    let v = 30; // equals member 30; claim low_index 2 -> 30 < 30 fails
    let (lr, sc) = lr_sc(s, v, 2);
    main(fr(s), lr, sc, 1, s, v, 2);
}

#[test(should_fail_with = "low-leaf does not bracket below")]
fn rejects_wrong_low_index() {
    let s = [10, 20, 30, 40];
    let v = 25; // claim low_index 3 (between 30 and 40) -> 30 < 25 fails
    let (lr, sc) = lr_sc(s, v, 3);
    main(fr(s), lr, sc, 1, s, v, 3);
}

#[test(should_fail_with = "last_root does not commit")]
fn rejects_tampered_last_root() {
    let s = [10, 20, 30, 40];
    let v = 25;
    let (lr, sc) = lr_sc(s, v, 2);
    main(fr(s), lr + 1, sc, 1, s, v, 2);
}

// -- composition with EVENT-COMPLETE/1: the anti-replay spine ----------------

// A fresh BVR event nullifier is consumable (a non-member of the spent set).
#[test]
fn consumes_a_fresh_event_nullifier() {
    let e = GoodsReceiptInvoice { usd_cents: 10000, fabric_meters: 50 };
    let n = event_nullifier(7, event_commitment(e), participant_set(111, 222));
    let spent = [0, 1, 2, 3]; // n (a large hash) is not present
    let (lr, sc) = lr_sc(spent, n, 4); // consume n after the last member
    main(fr(spent), lr, sc, 1, spent, n, 4);
}

// Replaying a SPENT event nullifier is rejected: once n is in the set, no gap
// brackets it. This is the historical-set anti-replay guard EVENT-COMPLETE/1
// relies on -- its in-circuit derivation only fixes the nullifier value.
#[test(should_fail_with = "low-leaf does not bracket below")]
fn rejects_replaying_a_spent_event_nullifier() {
    let e = GoodsReceiptInvoice { usd_cents: 10000, fabric_meters: 50 };
    let n = event_nullifier(7, event_commitment(e), participant_set(111, 222));
    let spent = [0, 1, 2, n]; // n already consumed (n > 2)
    let (lr, sc) = lr_sc(spent, n, 4); // try to consume n again
    main(fr(spent), lr, sc, 1, spent, n, 4);
}

#[test]
fn print_public_inputs() {
    let s = [10, 20, 30, 40];
    let v = 25;
    let (lr, sc) = lr_sc(s, v, 2);
    println(fr(s));
    println(lr);
    println(sc);
    // silence unused-import warning: the compiler exercises the rulebook compile path.
    let _ = compile_goods_receipt_invoice(GoodsReceiptInvoice { usd_cents: 1, fabric_meters: 1 });
}
