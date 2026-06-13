//! pacioli.nr -- the K(M) balance primitives, re-expressed minimally for the
//! ProveKit (beta.19) circuit. These mirror `circuits/pacioli` (beta.14), which are
//! the in-circuit faces of `Core.lean`:
//!
//!   journal_balanced  <-> Journal.balanced  (per-basis debit sum = credit sum)
//!   assert_u64        <-> the Field->u64->Field carrier-injectivity roundtrip
//!
//! Soundness rests on carrier injectivity (3/PROOF Annex C): every coordinate is a
//! u64, so each cross-sum a balance constraint forms is < 2^(64 + log2 ROWS), far
//! below the BN254 order r ~ 2^254. Field equality of the sums therefore decides the
//! integer equality with NO wraparound -- as long as ROWS is small (here 4).

/// Per-basis (debit, credit) column totals of a journal, accumulated in-field.
/// Correct only because each summand is a bounded u64 (see assert_u64 / the
/// `journal_sum_field_sound` argument in Core.lean).
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

/// A journal is a P^n zero-account iff, per basis dimension, the debit column total
/// equals the credit column total (1/PACI S3; Core.lean `Journal.balanced`). USD
/// cancels with USD, fabric with fabric -- never one collapsed through another.
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

/// The carrier-injectivity discipline of 3/PROOF Annex C made explicit: a value that
/// fits in u64 is non-negative and below the profile bound 2^64. In Noir the `u64`
/// type already enforces the range, so a witnessed `u64` coordinate is non-negative
/// and bounded by construction; this helper documents the obligation and gives a
/// place to TIGHTEN the bound below 2^64 (EVENT-COMPLETE/1 obligation 6's
/// profile-specific MAX_j) if a deployment needs it.
///
/// TODO(profile-bound): obligation 6 wants `< MAX_j` per dimension, not just `< 2^64`.
/// Add the per-dimension carrier bound here when a deployment fixes MAX_j.
pub fn assert_in_carrier(x: u64) {
    // u64 already gives 0 <= x < 2^64. Placeholder for a tighter per-dimension bound.
    assert(x as Field == x as Field); // structural no-op; range is in the type
}

// -- P^n conformance: the no-numeraire-collapse property (1/PACI S6) -----------
// Mirrors `circuits/pacioli` (beta.14) cand-0009 conformance vectors. Basis is
// [USD, fabric]; balance is per-dimension, never collapsed through a numeraire.

#[test]
fn pn_vector_zero_account_balances() {
    // A genuine P^n zero-account: USD cancels with USD, fabric with fabric.
    let debits: [[u64; 2]; 2] = [[100, 5], [0, 0]];
    let credits: [[u64; 2]; 2] = [[0, 0], [100, 5]];
    assert(journal_balanced(debits, credits), "vector zero-account must balance");
}

#[test]
fn pn_numeraire_collapse_is_rejected() {
    // "Dollars net but fabric vanishes": USD debits == USD credits, but fabric is
    // posted on only one side. A scalar (numeraire) view would call this balanced;
    // the P^n rule MUST reject it -- fabric cannot be settled through USD.
    let debits: [[u64; 2]; 2] = [[100, 5], [0, 0]];
    let credits: [[u64; 2]; 2] = [[0, 0], [100, 0]]; // USD 100=100, fabric 5 vs 0
    assert(!journal_balanced(debits, credits), "numeraire collapse must be rejected");
}
