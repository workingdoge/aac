//! repo -- a THIRD posting program (Phi_P): a classic FICC/GSD repurchase
//! agreement, modeled as the clearing kernel sees it. A repo is the canonical
//! collateralized financing leg and the bread-and-butter of the Government
//! Securities Division, so it is the natural first real clearing instrument on
//! top of the EVENT/1 harness (after the toy `bom-receipt`).
//!
//! A repo is TWO balanced exchanges, time-separated:
//!   - OPEN  (T0): the borrower delivers collateral (securities) to the lender and
//!                 receives cash (the principal). Securities out, cash in.
//!   - CLOSE (T1): the borrower repurchases the collateral, returning principal +
//!                 repo interest; the lender returns the securities.
//! Each leg INDIVIDUALLY is a per-dimension zero-account: a leg merely TRANSFERS
//! cash one way and securities the other, so every basis coordinate is conserved
//! (pacioli::journal_balanced holds for ANY quantities -- balance is a theorem of
//! the schema, as for `rulebook`/`bom-receipt`). The repo INTEREST is not a
//! within-leg imbalance: it is the cash DELTA between the two legs (close cash =
//! open cash + interest). Over the pair the borrower nets -interest and the lender
//! +interest -- the P&L emerges across legs, not inside a leg.
//!
//! WHY par and cash are SEPARATE incommensurable dimensions (not a valued amount).
//! A repo is over-collateralized: collateral market value = principal / (1 -
//! haircut). That haircut/valuation is a PRICING relationship, NOT a balance
//! condition -- it relates two incommensurable dimensions (security par vs cash
//! cents) and lives OUTSIDE the zero-account. The journal conserves what is
//! actually conserved: par units delivered == par units returned, cash out ==
//! cash in, each in its own dimension. This is exactly why vector Pacioli (1/PACI,
//! Ellerman) is the right model for collateral -- you track the conserved par, not
//! the fluctuating value. Marks/margining ride on top as a separate concern (12/OTC).
//!
//! CROSS-LEG SEQUENCING (open must clear before close; close consumes the open
//! position) is a registry/TRANSITION-1 concern, not a posting-program one -- the
//! two legs are two EVENTs sharing the parties + collateral_par + principal. This
//! crate proves each leg is a well-formed balanced BVR and that the legs LINK; the
//! anti-replay/ordering binding is left to the kernel (and to VNET for the
//! multilateral net of many such legs).

use pacioli::journal_balanced;
use event_harness::CompiledJournal;

global N_BASIS: u32 = 2; // basis [USD_cents, security_par]
global N_ROWS: u32 = 4;
global CASH: u32 = 0;
global SEC: u32 = 1;

// Chart: the two parties' securities and cash accounts.
global ACC_BORROWER_SECURITIES: u32 = 0;
global ACC_LENDER_SECURITIES: u32 = 1;
global ACC_LENDER_CASH: u32 = 2;
global ACC_BORROWER_CASH: u32 = 3;

// Distinct event tags per leg (R1 = 127 open, 128 close); event_commitment does
// not bind program_id, so each leg-schema takes its own tag (3/PROOF S3).
global TAG_REPO_OPEN: Field = 127;
global TAG_REPO_CLOSE: Field = 128;

/// The OPEN leg: principal cash in, collateral par out (borrower's view).
pub struct RepoOpen {
    pub principal_cents: u64,
    pub collateral_par: u64,
}

/// The CLOSE leg: principal + interest cash returned, collateral par back.
pub struct RepoClose {
    pub principal_cents: u64,
    pub interest_cents: u64,
    pub collateral_par: u64,
}

pub fn event_commitment_open(e: RepoOpen) -> Field {
    hash::poseidon_hash([TAG_REPO_OPEN, e.principal_cents as Field, e.collateral_par as Field])
}

pub fn event_commitment_close(e: RepoClose) -> Field {
    hash::poseidon_hash([
        TAG_REPO_CLOSE,
        e.principal_cents as Field,
        e.interest_cents as Field,
        e.collateral_par as Field,
    ])
}

/// Phi_P, OPEN leg. Securities move borrower -> lender; cash (principal) moves
/// lender -> borrower. Each dimension conserved.
///
///   row 0  Borrower * Securities   Cr  [_, par]    (collateral out)
///   row 1  Lender   * Securities   Dr  [_, par]    (collateral in)
///   row 2  Lender   * Cash         Cr  [prin, _]   (cash out)
///   row 3  Borrower * Cash         Dr  [prin, _]   (cash in)
pub fn compile_repo_open(e: RepoOpen) -> CompiledJournal<N_ROWS, N_BASIS> {
    let accounts = [
        ACC_BORROWER_SECURITIES,
        ACC_LENDER_SECURITIES,
        ACC_LENDER_CASH,
        ACC_BORROWER_CASH,
    ];
    let mut debits: [[u64; N_BASIS]; N_ROWS] = [[0; N_BASIS]; N_ROWS];
    let mut credits: [[u64; N_BASIS]; N_ROWS] = [[0; N_BASIS]; N_ROWS];
    credits[0][SEC] = e.collateral_par;
    debits[1][SEC] = e.collateral_par;
    credits[2][CASH] = e.principal_cents;
    debits[3][CASH] = e.principal_cents;
    CompiledJournal { accounts, debits, credits }
}

/// Phi_P, CLOSE leg. Securities move lender -> borrower; cash (principal +
/// interest) moves borrower -> lender. Each dimension conserved; the interest is
/// the cash delta vs the open leg, not a within-leg imbalance.
///
///   row 0  Lender   * Securities   Cr  [_, par]          (collateral returned)
///   row 1  Borrower * Securities   Dr  [_, par]          (collateral back)
///   row 2  Borrower * Cash         Cr  [prin+int, _]     (repurchase out)
///   row 3  Lender   * Cash         Dr  [prin+int, _]     (repurchase in)
pub fn compile_repo_close(e: RepoClose) -> CompiledJournal<N_ROWS, N_BASIS> {
    let accounts = [
        ACC_LENDER_SECURITIES,
        ACC_BORROWER_SECURITIES,
        ACC_BORROWER_CASH,
        ACC_LENDER_CASH,
    ];
    let repurchase = e.principal_cents + e.interest_cents; // u64 carrier checks overflow
    let mut debits: [[u64; N_BASIS]; N_ROWS] = [[0; N_BASIS]; N_ROWS];
    let mut credits: [[u64; N_BASIS]; N_ROWS] = [[0; N_BASIS]; N_ROWS];
    credits[0][SEC] = e.collateral_par;
    debits[1][SEC] = e.collateral_par;
    credits[2][CASH] = repurchase;
    debits[3][CASH] = repurchase;
    CompiledJournal { accounts, debits, credits }
}

#[test]
fn open_leg_is_balanced_for_all_quantities() {
    let cases = [[0, 0], [1, 1], [100000000, 1000000], [99, 250000], [18446744073709551615, 123]];
    for i in 0..5 {
        let j = compile_repo_open(RepoOpen { principal_cents: cases[i][0], collateral_par: cases[i][1] });
        assert(journal_balanced(j.debits, j.credits), "open leg compiled to an unbalanced journal");
    }
}

#[test]
fn close_leg_is_balanced_for_all_quantities() {
    // [principal, interest, par]
    let cases = [[0, 0, 0], [1, 1, 1], [100000000, 40000, 1000000], [99, 1, 250000]];
    for i in 0..4 {
        let j = compile_repo_close(RepoClose {
            principal_cents: cases[i][0],
            interest_cents: cases[i][1],
            collateral_par: cases[i][2],
        });
        assert(journal_balanced(j.debits, j.credits), "close leg compiled to an unbalanced journal");
    }
}

#[test]
fn legs_link() {
    // The two legs of ONE repo share principal + collateral_par; the close cash is
    // exactly the open cash plus the repo interest, and the same par is returned.
    let principal: u64 = 100000000; // $1,000,000.00
    let interest: u64 = 40000; // $400.00 repo interest
    let par: u64 = 1000000; // 1,000,000 par of the UST collateral
    let open = compile_repo_open(RepoOpen { principal_cents: principal, collateral_par: par });
    let close = compile_repo_close(RepoClose { principal_cents: principal, interest_cents: interest, collateral_par: par });
    // open: borrower receives `principal` cash (row 3 Dr CASH).
    assert(open.debits[3][CASH] == principal, "open cash != principal");
    // close: lender receives `principal + interest` cash (row 3 Dr CASH).
    assert(close.debits[3][CASH] == principal + interest, "close cash != principal + interest");
    // the cash delta across legs is exactly the interest.
    assert(close.debits[3][CASH] - open.debits[3][CASH] == interest, "cross-leg cash delta != interest");
    // the same collateral par is delivered (open row1 Dr SEC) and returned (close row1 Dr SEC).
    assert(open.debits[1][SEC] == par, "open par mismatch");
    assert(close.debits[1][SEC] == par, "close par mismatch");
}
