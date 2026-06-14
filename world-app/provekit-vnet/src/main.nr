//! VNET/1 netting circuit (PEDERSEN-VECTOR/1 profile), right-sized for the demo.
//!
//! Proves a SET of posted journals nets to zero per basis dimension WITHOUT
//! revealing amounts, via homomorphic Grumpkin Pedersen commitments. This is the
//! confidential multilateral-clearing differentiator: each atom's debit/credit
//! coordinates stay private (witness); only the Pedersen commitments and the
//! aggregate opening are public.
//!
//! MSM-ONLY (PEDERSEN-VECTOR/1 S4): ProveKit implements `MultiScalarMul` over
//! Grumpkin but NOT `EmbeddedCurveAdd`, so the aggregate `sum C_debit - sum
//! C_credit` is one unit-scalar MSM, with point subtraction done by the FREE
//! coordinate negation (x, -y) -- never a point-add opcode.
//!
//! Demo shape: N_ATOMS posted journals over a fixed N_BASIS basis. The canonical
//! case is a novation/clearing chain (A->C, C->B) where the intermediary nets
//! flat: every basis dimension's debits and credits cancel across the set.
use std::embedded_curve_ops::{multi_scalar_mul, EmbeddedCurvePoint, EmbeddedCurveScalar};

mod hash;

global N_ATOMS: u32 = 2;
global N_BASIS: u32 = 3;

fn sc(x: Field) -> EmbeddedCurveScalar {
    EmbeddedCurveScalar::from_field(x)
}

// Point subtraction helper: -P = (x, -y). Free (no EmbeddedCurveAdd / blackbox).
fn neg(p: EmbeddedCurvePoint) -> EmbeddedCurvePoint {
    EmbeddedCurvePoint { x: p.x, y: -p.y, is_infinite: p.is_infinite }
}

// DEMO stand-in generators. A real deployment derives DL-INDEPENDENT per-basis
// generators offline by PEDERSEN-VECTOR/1 S2 (domain-separated hash-to-curve),
// pinned and verifier-checked. These stand-ins have known DL relations, so the
// zero-opening alone would NOT certify the net here -- which is exactly why the
// circuit ALSO asserts the per-basis net is zero from the witness (below). With
// profile-grade generators the witness assertion becomes redundant and the
// zero-opening certifies the net with amounts never revealed.
fn generators() -> ([EmbeddedCurvePoint; N_BASIS], EmbeddedCurvePoint) {
    let g = EmbeddedCurvePoint::generator();
    let gs = [
        multi_scalar_mul([g], [sc(101)]),
        multi_scalar_mul([g], [sc(103)]),
        multi_scalar_mul([g], [sc(107)]),
    ];
    let h = multi_scalar_mul([g], [sc(7)]);
    (gs, h)
}

// Commit_B(v, r) = sum_j v_j * G_j + r * H -- one MSM (PEDERSEN-VECTOR/1 S3).
fn commit(
    gs: [EmbeddedCurvePoint; N_BASIS],
    h: EmbeddedCurvePoint,
    v: [u64; N_BASIS],
    r: Field,
) -> EmbeddedCurvePoint {
    multi_scalar_mul(
        [gs[0], gs[1], gs[2], h],
        [sc(v[0] as Field), sc(v[1] as Field), sc(v[2] as Field), sc(r)],
    )
}

fn main(
    // Private witness: per-atom per-basis debit/credit coordinates + blindings.
    debit: [[u64; N_BASIS]; N_ATOMS],
    credit: [[u64; N_BASIS]; N_ATOMS],
    r_debit: [Field; N_ATOMS],
    r_credit: [Field; N_ATOMS],
) -> pub (
    [EmbeddedCurvePoint; N_ATOMS], // published debit commitments
    [EmbeddedCurvePoint; N_ATOMS], // published credit commitments
    EmbeddedCurvePoint,            // aggregate opening A = sum C_D - sum C_C
    Field,                         // transition_set_commitment (journal linkage)
) {
    let (gs, h) = generators();

    // Per-atom Pedersen commitments (the points a clearing venue would publish).
    let mut c_debit: [EmbeddedCurvePoint; N_ATOMS] =
        [EmbeddedCurvePoint::point_at_infinity(); N_ATOMS];
    let mut c_credit: [EmbeddedCurvePoint; N_ATOMS] =
        [EmbeddedCurvePoint::point_at_infinity(); N_ATOMS];
    for i in 0..N_ATOMS {
        c_debit[i] = commit(gs, h, debit[i], r_debit[i]);
        c_credit[i] = commit(gs, h, credit[i], r_credit[i]);
    }

    // P^n zero-account: every basis dimension nets to zero (1/PACI, no numeraire).
    // Sound regardless of generator independence (asserted from the witness).
    for j in 0..N_BASIS {
        let mut net: Field = 0;
        for i in 0..N_ATOMS {
            net += debit[i][j] as Field - credit[i][j] as Field;
        }
        assert(net == 0);
    }

    // Aggregate A = sum C_debit - sum C_credit as a SINGLE MSM with unit scalars
    // (point subtraction via neg()). No EmbeddedCurveAdd.
    let a = multi_scalar_mul(
        [c_debit[0], c_debit[1], neg(c_credit[0]), neg(c_credit[1])],
        [sc(1), sc(1), sc(1), sc(1)],
    );

    // Zero opening: with every net_j = 0 the value generators cancel, so A must
    // open to pure blinding. Build that H-only opening with the SAME curve-group
    // arithmetic as `a` (scalar-muls + point negation), NOT a Field subtraction
    // of blindings: Noir's Field is Grumpkin's BASE field, whose order differs
    // from Grumpkin's SCALAR field, so a negative Field difference would not
    // match the group scalar that point negation produces.
    let r_h = multi_scalar_mul(
        [h, h, neg(h), neg(h)],
        [sc(r_debit[0]), sc(r_debit[1]), sc(r_credit[0]), sc(r_credit[1])],
    );
    assert(a.x == r_h.x);
    assert(a.y == r_h.y);

    // Transition linkage: fold each atom's journal_commitment (Poseidon2 over its
    // coordinates) so a verifier knows which posted journals were netted.
    let mut fold: Field = 0;
    for i in 0..N_ATOMS {
        let jc = hash::hash([
            debit[i][0] as Field, debit[i][1] as Field, debit[i][2] as Field,
            credit[i][0] as Field, credit[i][1] as Field, credit[i][2] as Field,
        ]);
        fold = hash::hash2(fold, jc);
    }

    (c_debit, c_credit, a, fold)
}

#[test]
fn accepts_true_net() {
    // Novation chain: atom 0 = A->C, atom 1 = C->B; the intermediary nets flat.
    let debit = [[100, 0, 0], [0, 50, 0]];
    let credit = [[0, 50, 0], [100, 0, 0]];
    let _ = main(debit, credit, [11, 13], [17, 19]);
}

#[test(should_fail)]
fn rejects_false_net() {
    // Tamper: atom 0 debit on basis 0 becomes 101 -> net_0 = 1 (not zero).
    let debit = [[101, 0, 0], [0, 50, 0]];
    let credit = [[0, 50, 0], [100, 0, 0]];
    let _ = main(debit, credit, [11, 13], [17, 19]);
}
