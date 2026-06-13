//! pacioli -- the K(M) balance primitives, in the BN254 scalar field.
//!
//! These are the in-circuit faces of the machine-checked statements in
//! `sites/ledger/statements/Core.lean`. The correspondence is exact:
//!
//!   pacioli_equal      <-> Term.pacioliEqual   (cross-addition equality)
//!   term_balanced      <-> Term.balanced       (debit = credit <=> class zero)
//!   journal_balanced   <-> Journal.balanced    (per-basis sums agree)
//!   assert_u64         <-> the Field->u64->Field roundtrip whose soundness is
//!                        `pacioli_equal_field_sound` / `journal_sum_field_sound`
//!
//! Soundness rests on carrier injectivity (3/PROOF S3, Annex C): every amount
//! is a u64, so every cross-sum the balance constraints form is < 2^65 << r and
//! field equality of the cross-sums decides N equality -- with no wraparound.

/// The Pacioli relation, decided in-field exactly as Core.lean defines it:
/// `(ld,lc) ~ (rd,rc) <=> ld + rc = lc + rd`, pointwise over the basis.
/// Amounts are u64, so each cross-sum (< 2^65) is far below the BN254 order;
/// the field equality therefore reflects the integer equality.
pub fn pacioli_equal<let B: u32>(
    ld: [u64; B],
    lc: [u64; B],
    rd: [u64; B],
    rc: [u64; B],
) -> bool {
    let mut ok = true;
    for b in 0..B {
        let lhs = ld[b] as Field + rc[b] as Field;
        let rhs = lc[b] as Field + rd[b] as Field;
        ok = ok & (lhs == rhs);
    }
    ok
}

/// A term is balanced iff its class is zero, i.e. debit = credit per basis
/// (Core.lean `Term.balanced` and `balanced_iff_class_zero`).
pub fn term_balanced<let B: u32>(debit: [u64; B], credit: [u64; B]) -> bool {
    let mut ok = true;
    for b in 0..B {
        ok = ok & (debit[b] == credit[b]);
    }
    ok
}

/// Per-basis (debit, credit) totals of a journal -- the two sides of
/// `Journal.total` in Core.lean, accumulated in the field. The result holds
/// only because each summand is a u64 (see `journal_sum_field_sound`).
pub fn journal_sums<let R: u32, let B: u32>(
    debits: [[u64; B]; R],
    credits: [[u64; B]; R],
) -> ([Field; B], [Field; B]) {
    let mut sd: [Field; B] = [0; B];
    let mut sc: [Field; B] = [0; B];
    for r in 0..R {
        for b in 0..B {
            sd[b] += debits[r][b] as Field;
            sc[b] += credits[r][b] as Field;
        }
    }
    (sd, sc)
}

/// A journal is balanced iff its class is zero -- per basis, the total of the
/// debit column equals the total of the credit column (1/PACI S3,
/// journal-level locality; Core.lean `Journal.balanced`).
pub fn journal_balanced<let R: u32, let B: u32>(
    debits: [[u64; B]; R],
    credits: [[u64; B]; R],
) -> bool {
    let (sd, sc) = journal_sums(debits, credits);
    let mut ok = true;
    for b in 0..B {
        ok = ok & (sd[b] == sc[b]);
    }
    ok
}

/// The carrier-injectivity discipline of 3/PROOF Annex C, made explicit: take
/// a field witness, roundtrip it through u64, and assert nothing was lost.
/// Returns the bounded amount. A value carrying any bit above 2^64 fails here,
/// which is what keeps every sum below the modulus.
pub fn assert_u64(x: Field) -> u64 {
    let u = x as u64; // truncates to the low 64 bits
    assert(u as Field == x, "amount exceeds the u64 carrier bound");
    u
}

#[test]
fn balanced_term_is_pacioli_equal_to_zero() {
    // Core.lean balanced_iff_class_zero: debit = credit <=> (d,c) ~ (0,0).
    let d = [3, 0, 5];
    let c = [3, 0, 5];
    assert(term_balanced(d, c));
    assert(pacioli_equal(d, c, [0, 0, 0], [0, 0, 0]));
}

#[test]
fn cross_addition_decides_equality() {
    // (10,3) ~ (12,5) since 10+5 = 3+12. Off-diagonal, not componentwise.
    assert(pacioli_equal([10], [3], [12], [5]));
    assert(!pacioli_equal([10], [3], [12], [6]));
}

#[test]
fn journal_balances_when_columns_agree() {
    // two rows: debits (7,0)+(0,4); credits (0,4)+(7,0). Columns: (7,4)=(7,4).
    let debits = [[7, 0], [0, 4]];
    let credits = [[0, 4], [7, 0]];
    assert(journal_balanced(debits, credits));

    let bad = [[7, 0], [0, 5]];
    assert(!journal_balanced(debits, bad));
}

#[test]
fn u64_roundtrip_accepts_bounded() {
    let _ = assert_u64(0);
    let _ = assert_u64(18446744073709551615); // 2^64 - 1
}

#[test(should_fail_with = "amount exceeds the u64 carrier bound")]
fn u64_roundtrip_rejects_overflow() {
    let _ = assert_u64(18446744073709551616); // 2^64
}
