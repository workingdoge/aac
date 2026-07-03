//! VNET/1 netting circuit for ProveKit (PEDERSEN-VECTOR/1 profile).
//!
//! This demo instance proves two posted journal atoms clear over the declared
//! ["USD", "fabric", "shares"] basis while keeping amount vectors private.
//! Its public inputs follow the VNET/1 section 5 order.

use std::embedded_curve_ops::{multi_scalar_mul, EmbeddedCurvePoint, EmbeddedCurveScalar};

mod hash;

global N_ATOMS: u32 = 2;
global N_BASIS: u32 = 3;
global MAX_COORD: u64 = 1000000000000;

global PROFILE_ID: Field = 38246398409996331787205124593264425578289;
global BASIS_COMMITMENT: Field =
    3199263021048886800067584263637418741171169451581946816529327257071282393363;
global SAMPLE_CONTEXT_COMMITMENT: Field = 9001;
global GRUMPKIN_B: Field =
    21888242871839275222246405745257275088548364400416034343698204186575808495600;

// PEDERSEN-VECTOR/1 sections 2 and 7: verifier-derived constants for
// profile_id="pedersen-vector/1", basis ["USD", "fabric", "shares"], and
// BASIS_COMMITMENT above. The prover never supplies generators.
global H_X: Field = 4442116937809428038466015586910822967980340166078939661906387952790413686754;
global H_Y: Field = 4817294039429267488105969530543855969668900749954483897040948903322607393472;
global G0_X: Field = 21378867110033115454839947600763369042167635625733880473869229047765030521928;
global G0_Y: Field = 8543745247798408310630292543307850943452724989093895241541507109679289712694;
global G1_X: Field = 15744486407527661081054625781727663178874265897862468867830629516418152836222;
global G1_Y: Field = 1205556853403814078068855613005326727425376491567528311964745933406350166466;
global G2_X: Field = 6215747075525991822894217274899096128320508540089587382936458111022554489410;
global G2_Y: Field = 17447054944361757926801073249828699265838738136270834167682343104825010839236;

global OLD_C_DEBIT_0_X: Field =
    9529120122049344670021134232047097586986821842302095553955227643395905214537;
global OLD_C_DEBIT_0_Y: Field =
    89235024537878343623044128056513415327538288254995216972256003134019170955;
global OLD_C_DEBIT_1_X: Field =
    1695212990003351635704733989851413035529487203771941295796036263960160480525;
global OLD_C_DEBIT_1_Y: Field =
    4269376179203881014739113560143678377981565198328848303109963834705424703935;
global OLD_C_CREDIT_0_X: Field =
    19780824456364739589915261888918536391227079978382518018521719838385770470920;
global OLD_C_CREDIT_0_Y: Field =
    21071807258955469859904211092024390114880663874277083831283671999063636059806;
global OLD_C_CREDIT_1_X: Field =
    17893994504964082885675620299805933622242568423639340153213367565551110623188;
global OLD_C_CREDIT_1_Y: Field =
    12622876599620063543160278835232859606460770401389085475258148957569693422707;

fn sc(x: Field) -> EmbeddedCurveScalar {
    EmbeddedCurveScalar::from_field(x)
}

fn point(x: Field, y: Field) -> EmbeddedCurvePoint {
    EmbeddedCurvePoint { x: x, y: y, is_infinite: false }
}

fn neg(p: EmbeddedCurvePoint) -> EmbeddedCurvePoint {
    EmbeddedCurvePoint { x: p.x, y: -p.y, is_infinite: p.is_infinite }
}

fn h_generator() -> EmbeddedCurvePoint {
    point(H_X, H_Y)
}

fn generators() -> ([EmbeddedCurvePoint; N_BASIS], EmbeddedCurvePoint) {
    ([point(G0_X, G0_Y), point(G1_X, G1_Y), point(G2_X, G2_Y)], h_generator())
}

fn assert_on_curve(p: EmbeddedCurvePoint) {
    if !p.is_infinite {
        assert(p.y * p.y == (p.x * p.x * p.x) + GRUMPKIN_B, "point is not on Grumpkin");
    }
}

fn assert_generator_constants_on_curve() {
    let (gs, h) = generators();
    assert_on_curve(h);
    for j in 0..N_BASIS {
        assert_on_curve(gs[j]);
    }
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

fn transition_set_commitment(
    transition_refs: [Field; N_ATOMS],
    journal_commitments: [Field; N_ATOMS],
) -> Field {
    let mut fold: Field = 0;
    for i in 0..N_ATOMS {
        fold = hash::hash([fold, transition_refs[i], journal_commitments[i]]);
    }
    fold
}

fn atom_commitment(
    transition_ref: Field,
    journal_commitment: Field,
    basis_commitment: Field,
    debit_commitment: EmbeddedCurvePoint,
    credit_commitment: EmbeddedCurvePoint,
) -> Field {
    hash::hash([
        transition_ref,
        journal_commitment,
        basis_commitment,
        debit_commitment.x,
        debit_commitment.y,
        credit_commitment.x,
        credit_commitment.y,
    ])
}

fn commitment_set_commitment(
    transition_refs: [Field; N_ATOMS],
    journal_commitments: [Field; N_ATOMS],
    c_debit: [EmbeddedCurvePoint; N_ATOMS],
    c_credit: [EmbeddedCurvePoint; N_ATOMS],
) -> Field {
    let mut fold: Field = 0;
    for i in 0..N_ATOMS {
        let atom = atom_commitment(
            transition_refs[i],
            journal_commitments[i],
            BASIS_COMMITMENT,
            c_debit[i],
            c_credit[i],
        );
        fold = hash::hash2(fold, atom);
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

fn assert_same_point(a: EmbeddedCurvePoint, b: EmbeddedCurvePoint) {
    assert(a.x == b.x, "point x mismatch");
    assert(a.y == b.y, "point y mismatch");
    assert(a.is_infinite == b.is_infinite, "point infinity mismatch");
}

fn main(
    profile_id_pub: pub Field,
    basis_commitment_pub: pub Field,
    transition_set_commitment_pub: pub Field,
    commitment_set_commitment_pub: pub Field,
    aggregate_opening_x_pub: pub Field,
    aggregate_opening_y_pub: pub Field,
    atom_count_pub: pub Field,
    context_commitment_pub: pub Field,
    transition_refs: [Field; N_ATOMS],
    journal_commitments: [Field; N_ATOMS],
    debit: [[u64; N_BASIS]; N_ATOMS],
    credit: [[u64; N_BASIS]; N_ATOMS],
    r_debit: [Field; N_ATOMS],
    r_credit: [Field; N_ATOMS],
) {
    assert(profile_id_pub == PROFILE_ID, "wrong PEDERSEN-VECTOR/1 profile_id");
    assert(
        basis_commitment_pub == BASIS_COMMITMENT,
        "wrong PEDERSEN-VECTOR/1 basis_commitment",
    );
    assert(atom_count_pub == N_ATOMS as Field, "wrong VNET/1 atom_count");
    assert(context_commitment_pub == context_commitment_pub, "bad context commitment");
    assert_generator_constants_on_curve();

    assert(
        transition_set_commitment_pub == transition_set_commitment(transition_refs, journal_commitments),
        "transition_set_commitment does not fold the supplied atom refs",
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
        assert(jc == journal_commitments[i], "journal commitment does not match atom vector");

        c_debit[i] = commit(gs, h, debit[i], r_debit[i]);
        c_credit[i] = commit(gs, h, credit[i], r_credit[i]);
    }

    assert(
        commitment_set_commitment_pub
            == commitment_set_commitment(transition_refs, journal_commitments, c_debit, c_credit),
        "commitment_set_commitment does not fold recomputed points",
    );

    for j in 0..N_BASIS {
        let mut net: Field = 0;
        for i in 0..N_ATOMS {
            net += debit[i][j] as Field - credit[i][j] as Field;
        }
        assert(net == 0, "basis dimension does not net to zero");
    }

    let a = aggregate_opening(c_debit, c_credit);
    assert(!a.is_infinite, "aggregate opening point is infinity");
    assert(a.x == aggregate_opening_x_pub, "aggregate opening x mismatch");
    assert(a.y == aggregate_opening_y_pub, "aggregate opening y mismatch");

    let r_h = blinding_opening(h, r_debit, r_credit);
    assert_same_point(a, r_h);
}

fn sample_transition_refs() -> [Field; N_ATOMS] {
    [7001, 7002]
}

fn sample_debit() -> [[u64; N_BASIS]; N_ATOMS] {
    [[100, 0, 0], [0, 50, 0]]
}

fn sample_credit() -> [[u64; N_BASIS]; N_ATOMS] {
    [[0, 50, 0], [100, 0, 0]]
}

fn sample_publics(
    transition_refs: [Field; N_ATOMS],
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
    (
        jcs,
        transition_set_commitment(transition_refs, jcs),
        commitment_set_commitment(transition_refs, jcs, c_debit, c_credit),
        aggregate_opening(c_debit, c_credit),
    )
}

fn call_main(
    transition_refs: [Field; N_ATOMS],
    jcs: [Field; N_ATOMS],
    transition_set: Field,
    commitment_set: Field,
    a: EmbeddedCurvePoint,
    debit: [[u64; N_BASIS]; N_ATOMS],
    credit: [[u64; N_BASIS]; N_ATOMS],
    r_debit: [Field; N_ATOMS],
    r_credit: [Field; N_ATOMS],
) {
    main(
        PROFILE_ID,
        BASIS_COMMITMENT,
        transition_set,
        commitment_set,
        a.x,
        a.y,
        N_ATOMS as Field,
        SAMPLE_CONTEXT_COMMITMENT,
        transition_refs,
        jcs,
        debit,
        credit,
        r_debit,
        r_credit,
    );
}

#[test]
fn accepts_true_net_with_profile_vector_constants() {
    let transition_refs = sample_transition_refs();
    let debit = sample_debit();
    let credit = sample_credit();
    let r_debit = [11, 13];
    let r_credit = [17, 19];
    let (jcs, transition_set, commitment_set, a) =
        sample_publics(transition_refs, debit, credit, r_debit, r_credit);
    call_main(
        transition_refs,
        jcs,
        transition_set,
        commitment_set,
        a,
        debit,
        credit,
        r_debit,
        r_credit,
    );
}

#[test]
fn pinned_constants_match_pedersen_vector_1_json() {
    assert(PROFILE_ID == 38246398409996331787205124593264425578289);
    assert(
        BASIS_COMMITMENT
            == 3199263021048886800067584263637418741171169451581946816529327257071282393363,
    );
    assert(H_X == 4442116937809428038466015586910822967980340166078939661906387952790413686754);
    assert(H_Y == 4817294039429267488105969530543855969668900749954483897040948903322607393472);
    assert(G0_X == 21378867110033115454839947600763369042167635625733880473869229047765030521928);
    assert(G0_Y == 8543745247798408310630292543307850943452724989093895241541507109679289712694);
    assert(G1_X == 15744486407527661081054625781727663178874265897862468867830629516418152836222);
    assert(G1_Y == 1205556853403814078068855613005326727425376491567528311964745933406350166466);
    assert(G2_X == 6215747075525991822894217274899096128320508540089587382936458111022554489410);
    assert(G2_Y == 17447054944361757926801073249828699265838738136270834167682343104825010839236);
}

#[test(should_fail_with = "basis dimension does not net to zero")]
fn rejects_false_net() {
    let transition_refs = sample_transition_refs();
    let debit = [[101, 0, 0], [0, 50, 0]];
    let credit = sample_credit();
    let r_debit = [11, 13];
    let r_credit = [17, 19];
    let (jcs, transition_set, commitment_set, a) =
        sample_publics(transition_refs, debit, credit, r_debit, r_credit);
    call_main(
        transition_refs,
        jcs,
        transition_set,
        commitment_set,
        a,
        debit,
        credit,
        r_debit,
        r_credit,
    );
}

#[test(should_fail_with = "journal commitment does not match atom vector")]
fn rejects_mismatched_transition_link() {
    let transition_refs = sample_transition_refs();
    let debit = sample_debit();
    let credit = sample_credit();
    let r_debit = [11, 13];
    let r_credit = [17, 19];
    let (mut jcs, _transition_set, commitment_set, a) =
        sample_publics(transition_refs, debit, credit, r_debit, r_credit);
    jcs[0] += 1;
    call_main(
        transition_refs,
        jcs,
        transition_set_commitment(transition_refs, jcs),
        commitment_set,
        a,
        debit,
        credit,
        r_debit,
        r_credit,
    );
}

#[test(should_fail_with = "transition_set_commitment does not fold the supplied atom refs")]
fn rejects_mismatched_transition_set_commitment() {
    let transition_refs = sample_transition_refs();
    let debit = sample_debit();
    let credit = sample_credit();
    let r_debit = [11, 13];
    let r_credit = [17, 19];
    let (jcs, transition_set, commitment_set, a) =
        sample_publics(transition_refs, debit, credit, r_debit, r_credit);
    call_main(
        transition_refs,
        jcs,
        transition_set + 1,
        commitment_set,
        a,
        debit,
        credit,
        r_debit,
        r_credit,
    );
}

#[test(should_fail_with = "commitment_set_commitment does not fold recomputed points")]
fn rejects_mismatched_commitment_set_commitment() {
    let transition_refs = sample_transition_refs();
    let debit = sample_debit();
    let credit = sample_credit();
    let r_debit = [11, 13];
    let r_credit = [17, 19];
    let (jcs, transition_set, commitment_set, a) =
        sample_publics(transition_refs, debit, credit, r_debit, r_credit);
    call_main(
        transition_refs,
        jcs,
        transition_set,
        commitment_set + 1,
        a,
        debit,
        credit,
        r_debit,
        r_credit,
    );
}

#[test(should_fail_with = "wrong PEDERSEN-VECTOR/1 profile_id")]
fn rejects_wrong_profile_id() {
    let transition_refs = sample_transition_refs();
    let debit = sample_debit();
    let credit = sample_credit();
    let r_debit = [11, 13];
    let r_credit = [17, 19];
    let (jcs, transition_set, commitment_set, a) =
        sample_publics(transition_refs, debit, credit, r_debit, r_credit);
    main(
        PROFILE_ID + 1,
        BASIS_COMMITMENT,
        transition_set,
        commitment_set,
        a.x,
        a.y,
        N_ATOMS as Field,
        SAMPLE_CONTEXT_COMMITMENT,
        transition_refs,
        jcs,
        debit,
        credit,
        r_debit,
        r_credit,
    );
}

#[test(should_fail_with = "wrong PEDERSEN-VECTOR/1 basis_commitment")]
fn rejects_wrong_basis_commitment() {
    let transition_refs = sample_transition_refs();
    let debit = sample_debit();
    let credit = sample_credit();
    let r_debit = [11, 13];
    let r_credit = [17, 19];
    let (jcs, transition_set, commitment_set, a) =
        sample_publics(transition_refs, debit, credit, r_debit, r_credit);
    main(
        PROFILE_ID,
        BASIS_COMMITMENT + 1,
        transition_set,
        commitment_set,
        a.x,
        a.y,
        N_ATOMS as Field,
        SAMPLE_CONTEXT_COMMITMENT,
        transition_refs,
        jcs,
        debit,
        credit,
        r_debit,
        r_credit,
    );
}

#[test(should_fail_with = "wrong VNET/1 atom_count")]
fn rejects_wrong_atom_count() {
    let transition_refs = sample_transition_refs();
    let debit = sample_debit();
    let credit = sample_credit();
    let r_debit = [11, 13];
    let r_credit = [17, 19];
    let (jcs, transition_set, commitment_set, a) =
        sample_publics(transition_refs, debit, credit, r_debit, r_credit);
    main(
        PROFILE_ID,
        BASIS_COMMITMENT,
        transition_set,
        commitment_set,
        a.x,
        a.y,
        N_ATOMS as Field + 1,
        SAMPLE_CONTEXT_COMMITMENT,
        transition_refs,
        jcs,
        debit,
        credit,
        r_debit,
        r_credit,
    );
}

#[test(should_fail_with = "aggregate opening x mismatch")]
fn rejects_bad_opening() {
    let transition_refs = sample_transition_refs();
    let debit = sample_debit();
    let credit = sample_credit();
    let r_debit = [11, 13];
    let r_credit = [17, 19];
    let (jcs, transition_set, commitment_set, a) =
        sample_publics(transition_refs, debit, credit, r_debit, r_credit);
    main(
        PROFILE_ID,
        BASIS_COMMITMENT,
        transition_set,
        commitment_set,
        a.x + 1,
        a.y,
        N_ATOMS as Field,
        SAMPLE_CONTEXT_COMMITMENT,
        transition_refs,
        jcs,
        debit,
        credit,
        r_debit,
        r_credit,
    );
}

#[test(should_fail_with = "coordinate exceeds PEDERSEN-VECTOR/1 profile bound")]
fn rejects_out_of_bound_coordinate() {
    let transition_refs = sample_transition_refs();
    let debit = [[MAX_COORD + 1, 0, 0], [0, 50, 0]];
    let credit = [[0, 50, 0], [MAX_COORD + 1, 0, 0]];
    let r_debit = [11, 13];
    let r_credit = [17, 19];
    let (jcs, transition_set, commitment_set, a) =
        sample_publics(transition_refs, debit, credit, r_debit, r_credit);
    call_main(
        transition_refs,
        jcs,
        transition_set,
        commitment_set,
        a,
        debit,
        credit,
        r_debit,
        r_credit,
    );
}

#[test(should_fail_with = "commitment_set_commitment does not fold recomputed points")]
fn rejects_commitment_set_from_legacy_free_label_generators() {
    let transition_refs = sample_transition_refs();
    let debit = sample_debit();
    let credit = sample_credit();
    let r_debit = [11, 13];
    let r_credit = [17, 19];
    let (jcs, transition_set, _commitment_set, a) =
        sample_publics(transition_refs, debit, credit, r_debit, r_credit);
    let old_c_debit = [
        point(OLD_C_DEBIT_0_X, OLD_C_DEBIT_0_Y),
        point(OLD_C_DEBIT_1_X, OLD_C_DEBIT_1_Y),
    ];
    let old_c_credit = [
        point(OLD_C_CREDIT_0_X, OLD_C_CREDIT_0_Y),
        point(OLD_C_CREDIT_1_X, OLD_C_CREDIT_1_Y),
    ];
    let old_commitment_set =
        commitment_set_commitment(transition_refs, jcs, old_c_debit, old_c_credit);
    call_main(
        transition_refs,
        jcs,
        transition_set,
        old_commitment_set,
        a,
        debit,
        credit,
        r_debit,
        r_credit,
    );
}

#[test]
fn print_public_inputs() {
    let transition_refs = sample_transition_refs();
    let debit = sample_debit();
    let credit = sample_credit();
    let r_debit = [11, 13];
    let r_credit = [17, 19];
    let (_jcs, transition_set, commitment_set, a) =
        sample_publics(transition_refs, debit, credit, r_debit, r_credit);
    println(PROFILE_ID);
    println(BASIS_COMMITMENT);
    println(transition_set);
    println(commitment_set);
    println(a.x);
    println(a.y);
    println(N_ATOMS as Field);
    println(SAMPLE_CONTEXT_COMMITMENT);
}
