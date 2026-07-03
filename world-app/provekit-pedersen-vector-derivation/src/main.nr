//! Offline PEDERSEN-VECTOR/1 derivation harness.
//!
//! This harness uses the same beta.19 Noir stdlib Poseidon2 permutation family
//! as the ProveKit VNET circuit. It is a generator/vector derivation harness,
//! not a production circuit.

global P2_WIDTH: u32 = 4;
global P2_RATE: u32 = 3;
global N_BASIS: u32 = 3;
global VECTOR_FIELD_COUNT: u32 = 22;

global DOMAIN: Field = 459866030074855593094961; // field_of("aac/vnet/1")
global DOMAIN_BASIS: Field = 129440780105341809738746541662016858483; // field_of("aac/vnet/1/basis")
global PROFILE_ID: Field = 38246398409996331787205124593264425578289; // field_of("pedersen-vector/1")
global LABEL_G: Field = 71; // field_of("G")
global LABEL_H: Field = 72; // field_of("H")
global BASIS_USD: Field = 5591876; // field_of("USD")
global BASIS_FABRIC: Field = 112568449526115; // field_of("fabric")
global BASIS_SHARES: Field = 126892148680051; // field_of("shares")
global GRUMPKIN_B: Field =
    21888242871839275222246405745257275088548364400416034343698204186575808495600; // -17 mod p

global H_CTR: Field = 0;
global G0_CTR: Field = 0;
global G1_CTR: Field = 3;
global G2_CTR: Field = 2;

global H_X: Field = 4442116937809428038466015586910822967980340166078939661906387952790413686754;
global H_Y: Field = 4817294039429267488105969530543855969668900749954483897040948903322607393472;
global G0_X: Field = 21378867110033115454839947600763369042167635625733880473869229047765030521928;
global G0_Y: Field = 8543745247798408310630292543307850943452724989093895241541507109679289712694;
global G1_X: Field = 15744486407527661081054625781727663178874265897862468867830629516418152836222;
global G1_Y: Field = 1205556853403814078068855613005326727425376491567528311964745933406350166466;
global G2_X: Field = 6215747075525991822894217274899096128320508540089587382936458111022554489410;
global G2_Y: Field = 17447054944361757926801073249828699265838738136270834167682343104825010839236;

global G1_REJECT_X0: Field = 18837131402071869779766844760642287374611721961215320825196291318210211150722;
global G1_REJECT_X1: Field = 10031925338206342119142486843643176383543856228302668194737762425013733900838;
global G1_REJECT_X2: Field = 18581320709101111413160556824421141095590389932681230357320958354115628599091;
global G2_REJECT_X0: Field = 12518534194171219408560021445335756534617882374640378025736432831328421135403;
global G2_REJECT_X1: Field = 20194159965587348953575573870308688812046731342255711018359364030924714058014;

fn hash<let N: u32>(input: [Field; N]) -> Field {
    let mut state: [Field; 4] = [0, 0, 0, N as Field];
    for k in 0..N {
        state[k % P2_RATE] = state[k % P2_RATE] + input[k];
        if (k % P2_RATE) == (P2_RATE - 1) {
            state = std::hash::poseidon2_permutation(state, P2_WIDTH);
        }
    }
    if (N % P2_RATE) != 0 {
        state = std::hash::poseidon2_permutation(state, P2_WIDTH);
    }
    state[0]
}

fn basis_commitment() -> Field {
    hash([DOMAIN_BASIS, PROFILE_ID, N_BASIS as Field, BASIS_USD, BASIS_FABRIC, BASIS_SHARES])
}

fn seed(label: Field, basis_type_id_j: Field, j: Field) -> Field {
    hash([DOMAIN, PROFILE_ID, basis_commitment(), basis_type_id_j, label, j])
}

fn x_from_seed(s: Field, ctr: Field) -> Field {
    hash([s, ctr])
}

fn assert_curve(x: Field, y: Field) {
    assert(y * y == (x * x * x) + GRUMPKIN_B, "point is not on Grumpkin");
}

fn assert_even(y: Field) {
    let bits: [u1; 254] = y.to_le_bits();
    assert(bits[0] == 0, "point y is not even");
}

fn vector_fields() -> [Field; VECTOR_FIELD_COUNT] {
    let bc = basis_commitment();
    let h_seed = seed(LABEL_H, BASIS_USD, 0);
    let g0_seed = seed(LABEL_G, BASIS_USD, 0);
    let g1_seed = seed(LABEL_G, BASIS_FABRIC, 1);
    let g2_seed = seed(LABEL_G, BASIS_SHARES, 2);

    assert(x_from_seed(h_seed, H_CTR) == H_X, "H x mismatch");
    assert(x_from_seed(g0_seed, G0_CTR) == G0_X, "G0 x mismatch");
    assert(x_from_seed(g1_seed, G1_CTR) == G1_X, "G1 x mismatch");
    assert(x_from_seed(g2_seed, G2_CTR) == G2_X, "G2 x mismatch");
    assert(x_from_seed(g1_seed, 0) == G1_REJECT_X0, "G1 rejected x0 mismatch");
    assert(x_from_seed(g1_seed, 1) == G1_REJECT_X1, "G1 rejected x1 mismatch");
    assert(x_from_seed(g1_seed, 2) == G1_REJECT_X2, "G1 rejected x2 mismatch");
    assert(x_from_seed(g2_seed, 0) == G2_REJECT_X0, "G2 rejected x0 mismatch");
    assert(x_from_seed(g2_seed, 1) == G2_REJECT_X1, "G2 rejected x1 mismatch");

    assert_curve(H_X, H_Y);
    assert_curve(G0_X, G0_Y);
    assert_curve(G1_X, G1_Y);
    assert_curve(G2_X, G2_Y);
    assert_even(H_Y);
    assert_even(G0_Y);
    assert_even(G1_Y);
    assert_even(G2_Y);

    [
        bc,
        h_seed,
        g0_seed,
        g1_seed,
        g2_seed,
        H_CTR,
        H_X,
        H_Y,
        G0_CTR,
        G0_X,
        G0_Y,
        G1_CTR,
        G1_X,
        G1_Y,
        G2_CTR,
        G2_X,
        G2_Y,
        G1_REJECT_X0,
        G1_REJECT_X1,
        G1_REJECT_X2,
        G2_REJECT_X0,
        G2_REJECT_X1,
    ]
}

fn main() -> pub [Field; VECTOR_FIELD_COUNT] {
    vector_fields()
}

#[test]
fn prints_vector_fields() {
    let fields = vector_fields();
    for i in 0..VECTOR_FIELD_COUNT {
        println(fields[i]);
    }
}
