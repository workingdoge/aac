//! VNET/1 netting circuit for ProveKit (PEDERSEN-VECTOR/1 profile).
//!
//! This proves that a selected batch of posted journal atoms clears per basis
//! dimension while keeping the amount vectors private. The public surface is the
//! transition-link commitments, the profile/generator-set id, the aggregate
//! zero-opening point, and the Pedersen commitments returned by the circuit.

use std::embedded_curve_ops::{multi_scalar_mul, EmbeddedCurvePoint, EmbeddedCurveScalar};

mod hash;

global N_ATOMS: u32 = 2;
global N_BASIS: u32 = 3;
global MAX_COORD: u64 = 1000000000000;
global PROFILE_TAG: Field = 5205201;

fn sc(x: Field) -> EmbeddedCurveScalar {
    EmbeddedCurveScalar::from_field(x)
}

fn neg(p: EmbeddedCurvePoint) -> EmbeddedCurvePoint {
    EmbeddedCurvePoint { x: p.x, y: -p.y, is_infinite: p.is_infinite }
}

fn generators() -> ([EmbeddedCurvePoint; N_BASIS], EmbeddedCurvePoint) {
    let points: [EmbeddedCurvePoint; N_BASIS + 1] =
        [EmbeddedCurvePoint::generator(), EmbeddedCurvePoint::generator(), EmbeddedCurvePoint::generator(), EmbeddedCurvePoint::generator()];
    ([points[0], points[1], points[2]], points[3])
}

fn generator_set_id() -> Field {
    hash::hash([PROFILE_TAG, N_ATOMS as Field, N_BASIS as Field, MAX_COORD as Field])
}

fn assert_coord(x: u64) {
    assert(x <= MAX_COORD, "coordinate exceeds PEDERSEN-VECTOR/1 profile bound");
}

fn journal_commitment(debit: [u64; N_BASIS], credit: [u64; N_BASIS]) -> Field {
    hash::hash([
        debit[0] as Field,
        debit[1] as Field,
        debit[2] as Field,
        credit[0] as Field,
        credit[1] as Field,
        credit[2] as Field,
    ])
}

fn transition_set_commitment(journal_commitments: [Field; N_ATOMS]) -> Field {
    let mut fold: Field = 0;
    for i in 0..N_ATOMS {
        fold = hash::hash2(fold, journal_commitments[i]);
    }
    fold
}

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

fn aggregate_opening(
    c_debit: [EmbeddedCurvePoint; N_ATOMS],
    c_credit: [EmbeddedCurvePoint; N_ATOMS],
) -> EmbeddedCurvePoint {
    multi_scalar_mul(
        [c_debit[0], c_debit[1], neg(c_credit[0]), neg(c_credit[1])],
        [sc(1), sc(1), sc(1), sc(1)],
    )
}

fn blinding_opening(
    h: EmbeddedCurvePoint,
    r_debit: [Field; N_ATOMS],
    r_credit: [Field; N_ATOMS],
) -> EmbeddedCurvePoint {
    multi_scalar_mul(
        [h, h, neg(h), neg(h)],
        [sc(r_debit[0]), sc(r_debit[1]), sc(r_credit[0]), sc(r_credit[1])],
    )
}

fn main(
    journal_commitments_pub: pub [Field; N_ATOMS],
    transition_set_commitment_pub: pub Field,
    generator_set_id_pub: pub Field,
    aggregate_opening_x_pub: pub Field,
    aggregate_opening_y_pub: pub Field,
    aggregate_opening_is_infinite_pub: pub bool,
    debit: [[u64; N_BASIS]; N_ATOMS],
    credit: [[u64; N_BASIS]; N_ATOMS],
    r_debit: [Field; N_ATOMS],
    r_credit: [Field; N_ATOMS],
) -> pub ([EmbeddedCurvePoint; N_ATOMS], [EmbeddedCurvePoint; N_ATOMS]) {
    assert(generator_set_id_pub == generator_set_id(), "wrong PEDERSEN-VECTOR/1 generator set");
    assert(
        transition_set_commitment_pub == transition_set_commitment(journal_commitments_pub),
        "transition_set_commitment does not fold the supplied journals",
    );

    let (gs, h) = generators();
    let mut c_debit: [EmbeddedCurvePoint; N_ATOMS] =
        [EmbeddedCurvePoint::point_at_infinity(); N_ATOMS];
    let mut c_credit: [EmbeddedCurvePoint; N_ATOMS] =
        [EmbeddedCurvePoint::point_at_infinity(); N_ATOMS];

    for i in 0..N_ATOMS {
        for j in 0..N_BASIS {
            assert_coord(debit[i][j]);
            assert_coord(credit[i][j]);
        }

        let jc = journal_commitment(debit[i], credit[i]);
        assert(jc == journal_commitments_pub[i], "journal commitment does not match atom vector");

        c_debit[i] = commit(gs, h, debit[i], r_debit[i]);
        c_credit[i] = commit(gs, h, credit[i], r_credit[i]);
    }

    for j in 0..N_BASIS {
        let mut net: Field = 0;
        for i in 0..N_ATOMS {
            net += debit[i][j] as Field - credit[i][j] as Field;
        }
        assert(net == 0, "basis dimension does not net to zero");
    }

    let a = aggregate_opening(c_debit, c_credit);
    assert(a.x == aggregate_opening_x_pub, "aggregate opening x mismatch");
    assert(a.y == aggregate_opening_y_pub, "aggregate opening y mismatch");
    assert(
        a.is_infinite == aggregate_opening_is_infinite_pub,
        "aggregate opening infinity flag mismatch",
    );

    let r_h = blinding_opening(h, r_debit, r_credit);
    assert(a.x == r_h.x, "aggregate opening is not a pure blinding commitment");
    assert(a.y == r_h.y, "aggregate opening is not a pure blinding commitment");
    assert(a.is_infinite == r_h.is_infinite, "aggregate opening infinity mismatch");

    (c_debit, c_credit)
}

fn sample_debit() -> [[u64; N_BASIS]; N_ATOMS] {
    [[100, 0, 0], [0, 50, 0]]
}

fn sample_credit() -> [[u64; N_BASIS]; N_ATOMS] {
    [[0, 50, 0], [100, 0, 0]]
}

fn sample_publics(
    debit: [[u64; N_BASIS]; N_ATOMS],
    credit: [[u64; N_BASIS]; N_ATOMS],
    r_debit: [Field; N_ATOMS],
    r_credit: [Field; N_ATOMS],
) -> ([Field; N_ATOMS], Field, Field, EmbeddedCurvePoint) {
    let (gs, h) = generators();
    let mut jcs: [Field; N_ATOMS] = [0; N_ATOMS];
    let mut c_debit: [EmbeddedCurvePoint; N_ATOMS] =
        [EmbeddedCurvePoint::point_at_infinity(); N_ATOMS];
    let mut c_credit: [EmbeddedCurvePoint; N_ATOMS] =
        [EmbeddedCurvePoint::point_at_infinity(); N_ATOMS];
    for i in 0..N_ATOMS {
        jcs[i] = journal_commitment(debit[i], credit[i]);
        c_debit[i] = commit(gs, h, debit[i], r_debit[i]);
        c_credit[i] = commit(gs, h, credit[i], r_credit[i]);
    }
    (jcs, transition_set_commitment(jcs), generator_set_id(), aggregate_opening(c_debit, c_credit))
}

#[test]
fn accepts_true_net() {
    let debit = sample_debit();
    let credit = sample_credit();
    let r_debit = [11, 13];
    let r_credit = [17, 19];
    let (jcs, fold, gid, a) = sample_publics(debit, credit, r_debit, r_credit);
    let _ = main(jcs, fold, gid, a.x, a.y, a.is_infinite, debit, credit, r_debit, r_credit);
}

#[test(should_fail_with = "basis dimension does not net to zero")]
fn rejects_false_net() {
    let debit = [[101, 0, 0], [0, 50, 0]];
    let credit = sample_credit();
    let r_debit = [11, 13];
    let r_credit = [17, 19];
    let (jcs, fold, gid, a) = sample_publics(debit, credit, r_debit, r_credit);
    let _ = main(jcs, fold, gid, a.x, a.y, a.is_infinite, debit, credit, r_debit, r_credit);
}

#[test(should_fail_with = "journal commitment does not match atom vector")]
fn rejects_mismatched_transition_link() {
    let debit = sample_debit();
    let credit = sample_credit();
    let r_debit = [11, 13];
    let r_credit = [17, 19];
    let (mut jcs, _fold, gid, a) = sample_publics(debit, credit, r_debit, r_credit);
    jcs[0] += 1;
    let _ = main(
        jcs,
        transition_set_commitment(jcs),
        gid,
        a.x,
        a.y,
        a.is_infinite,
        debit,
        credit,
        r_debit,
        r_credit,
    );
}

#[test(should_fail_with = "transition_set_commitment does not fold the supplied journals")]
fn rejects_mismatched_transition_set_commitment() {
    let debit = sample_debit();
    let credit = sample_credit();
    let r_debit = [11, 13];
    let r_credit = [17, 19];
    let (jcs, fold, gid, a) = sample_publics(debit, credit, r_debit, r_credit);
    let _ = main(jcs, fold + 1, gid, a.x, a.y, a.is_infinite, debit, credit, r_debit, r_credit);
}

#[test(should_fail_with = "wrong PEDERSEN-VECTOR/1 generator set")]
fn rejects_wrong_generator_set_id() {
    let debit = sample_debit();
    let credit = sample_credit();
    let r_debit = [11, 13];
    let r_credit = [17, 19];
    let (jcs, fold, gid, a) = sample_publics(debit, credit, r_debit, r_credit);
    let _ = main(jcs, fold, gid + 1, a.x, a.y, a.is_infinite, debit, credit, r_debit, r_credit);
}

#[test(should_fail_with = "aggregate opening x mismatch")]
fn rejects_bad_opening() {
    let debit = sample_debit();
    let credit = sample_credit();
    let r_debit = [11, 13];
    let r_credit = [17, 19];
    let (jcs, fold, gid, a) = sample_publics(debit, credit, r_debit, r_credit);
    let _ = main(jcs, fold, gid, a.x + 1, a.y, a.is_infinite, debit, credit, r_debit, r_credit);
}

#[test(should_fail_with = "coordinate exceeds PEDERSEN-VECTOR/1 profile bound")]
fn rejects_out_of_bound_coordinate() {
    let debit = [[MAX_COORD + 1, 0, 0], [0, 50, 0]];
    let credit = [[0, 50, 0], [MAX_COORD + 1, 0, 0]];
    let r_debit = [11, 13];
    let r_credit = [17, 19];
    let (jcs, fold, gid, a) = sample_publics(debit, credit, r_debit, r_credit);
    let _ = main(jcs, fold, gid, a.x, a.y, a.is_infinite, debit, credit, r_debit, r_credit);
}

#[test]
fn print_public_inputs() {
    let debit = sample_debit();
    let credit = sample_credit();
    let r_debit = [11, 13];
    let r_credit = [17, 19];
    let (jcs, fold, gid, a) = sample_publics(debit, credit, r_debit, r_credit);
    println(jcs[0]);
    println(jcs[1]);
    println(fold);
    println(gid);
    println(a.x);
    println(a.y);
    println(a.is_infinite);
}
