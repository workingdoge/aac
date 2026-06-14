//! novate -- NOVATE/1, the central-counterparty interposition (Design Note 0004 S3).
//!
//! Novation replaces a bilateral cleared trade J_AB with two CCP-legs J_AC and
//! J_CB so that A and B each face the CCP C instead of each other. NOVATE/1 proves
//! the interposition is faithful and the CCP takes no position. The whole relation
//! collapses to ONE vector equation over the (account x dimension) grid:
//!
//!     net(J_AC) (+) net(J_CB)  ==  net(J_AB)
//!
//! where net(J)[account][dim] = sum over that account's rows of (debit - credit).
//! The bilateral is genuinely bilateral -- it never touches C's accounts
//! (net(J_AB)[C] = 0) -- so on C's slice the equation reads
//! net(J_AC)[C] + net(J_CB)[C] == 0: the CCP is FLAT, the matched book at the single
//! trade. Conservation (the legs reproduce A's and B's positions) and CCP-flat (C's
//! slice vanishes) are the SAME equation read on different accounts. (CCP-flat is in
//! fact FORCED: each leg is a zero-account, so its net sums to 0 across all accounts;
//! once A's and B's slices match the bilateral, C's slice has nowhere to go but 0.
//! The matched book is a theorem of balanced faithful interposition, not an extra
//! assumption.)
//!
//! APPLICATION-LAYER, policy-gated (4/REG S5, applications/README): a clearing venue
//! MAY require a NOVATE/1 proof to admit a trade to its matched book; the base
//! registry MUST NOT. It introduces NO new primitive -- it is a balanced
//! decomposition over the same P^n algebra (1/PACI) the kernel already proves.
//!
//! This v1 fixes a party-grouped 6-account chart {A,B,C} x {asset,cash} and a basis
//! B=2 bilateral; net_grid/novate are generic in the basis so a richer schema reuses
//! the obligation. The account->party labelling is the chart convention below.

use pacioli::journal_balanced;
use event_harness::CompiledJournal;

global NACCT: u32 = 6; // {A,B,C} x {asset, cash}
global N_ROWS: u32 = 4; // a bilateral exchange posts four rows

// Party-grouped chart: even index = asset account, odd = cash account.
global A_ASSET: u32 = 0;
global A_CASH: u32 = 1;
global B_ASSET: u32 = 2;
global B_CASH: u32 = 3;
global C_ASSET: u32 = 4; // the CCP's accounts
global C_CASH: u32 = 5;

global ASSET: u32 = 0; // basis dimensions for the concrete B=2 bilateral
global CASH: u32 = 1;

/// Net position grid: net[account][dim] = sum over that account's rows of
/// (debit - credit), in Field (positions are signed). Generic in rows R and basis B.
pub fn net_grid<let R: u32, let B: u32>(j: CompiledJournal<R, B>) -> [[Field; B]; NACCT] {
    let mut g: [[Field; B]; NACCT] = [[0; B]; NACCT];
    for aa in 0..NACCT {
        for r in 0..R {
            if j.accounts[r] == aa {
                for d in 0..B {
                    g[aa][d] += j.debits[r][d] as Field - j.credits[r][d] as Field;
                }
            }
        }
    }
    g
}

/// NOVATE/1: prove that (leg_ac, leg_cb) is a faithful novation of bilateral. All
/// three are zero-accounts; the bilateral genuinely does not touch the CCP; and the
/// two legs compose to the bilateral position on every account -- which on C's
/// accounts is exactly the matched book (CCP flat).
pub fn novate<let B: u32>(
    bilateral: CompiledJournal<N_ROWS, B>,
    leg_ac: CompiledJournal<N_ROWS, B>,
    leg_cb: CompiledJournal<N_ROWS, B>,
) {
    // (i) each journal is a P^n zero-account.
    assert(journal_balanced(bilateral.debits, bilateral.credits), "bilateral is not a zero-account");
    assert(journal_balanced(leg_ac.debits, leg_ac.credits), "leg A-C is not a zero-account");
    assert(journal_balanced(leg_cb.debits, leg_cb.credits), "leg C-B is not a zero-account");

    let nb = net_grid(bilateral);
    let nac = net_grid(leg_ac);
    let ncb = net_grid(leg_cb);

    // (ii) the input is genuinely BILATERAL: it must not touch the CCP's accounts.
    // This is what makes the composition's C-slice mean "matched book".
    for d in 0..B {
        assert(nb[C_ASSET][d] == 0, "the bilateral touches a CCP account");
        assert(nb[C_CASH][d] == 0, "the bilateral touches a CCP account");
    }

    // (iii) the one novation equation: the two legs compose to the bilateral on EVERY
    // account. On A and B this is conservation (their economics are unchanged); on C,
    // where nb is 0, it reads net(leg_ac)[C] + net(leg_cb)[C] == 0 -- the CCP is flat.
    for a in 0..NACCT {
        for d in 0..B {
            assert(nac[a][d] + ncb[a][d] == nb[a][d], "novation does not reproduce the bilateral position");
        }
    }
}

/// Compile a canonical bilateral exchange: A delivers asset_amt to B, B delivers
/// cash_amt to A. Each dimension conserved (a transfer), so it is a zero-account.
///   row 0  A.asset   Cr asset   (A delivers the security)
///   row 1  B.asset   Dr asset   (B receives it)
///   row 2  B.cash    Cr cash    (B delivers the cash)
///   row 3  A.cash    Dr cash    (A receives it)
pub fn compile_bilateral(asset_amt: u64, cash_amt: u64) -> CompiledJournal<N_ROWS, 2> {
    let accounts = [A_ASSET, B_ASSET, B_CASH, A_CASH];
    let mut debits: [[u64; 2]; N_ROWS] = [[0; 2]; N_ROWS];
    let mut credits: [[u64; 2]; N_ROWS] = [[0; 2]; N_ROWS];
    credits[0][ASSET] = asset_amt;
    debits[1][ASSET] = asset_amt;
    credits[2][CASH] = cash_amt;
    debits[3][CASH] = cash_amt;
    CompiledJournal { accounts, debits, credits }
}

/// The canonical novation of compile_bilateral: leg A-C keeps A's rows and relabels
/// B's accounts to C's; leg C-B keeps B's rows and relabels A's accounts to C's. The
/// debit/credit vectors are unchanged -- novation re-labels who faces whom, never
/// what moves.
pub fn compile_novation_legs(
    asset_amt: u64,
    cash_amt: u64,
) -> (CompiledJournal<N_ROWS, 2>, CompiledJournal<N_ROWS, 2>) {
    let mut d: [[u64; 2]; N_ROWS] = [[0; 2]; N_ROWS];
    let mut c: [[u64; 2]; N_ROWS] = [[0; 2]; N_ROWS];
    c[0][ASSET] = asset_amt;
    d[1][ASSET] = asset_amt;
    c[2][CASH] = cash_amt;
    d[3][CASH] = cash_amt;
    // leg A-C: A's rows (0,3) keep A's accounts; B's rows (1,2) become C's.
    let leg_ac = CompiledJournal { accounts: [A_ASSET, C_ASSET, C_CASH, A_CASH], debits: d, credits: c };
    // leg C-B: B's rows (1,2) keep B's accounts; A's rows (0,3) become C's.
    let leg_cb = CompiledJournal { accounts: [C_ASSET, B_ASSET, B_CASH, C_CASH], debits: d, credits: c };
    (leg_ac, leg_cb)
}

#[test]
fn canonical_novation_is_accepted() {
    let asset = 1000000; // 1,000,000 par of a security
    let cash = 100000000; // $1,000,000.00
    let bilateral = compile_bilateral(asset, cash);
    let (leg_ac, leg_cb) = compile_novation_legs(asset, cash);
    novate(bilateral, leg_ac, leg_cb);
}

#[test]
fn novation_holds_for_all_quantities() {
    let cases = [[0, 0], [1, 1], [1000000, 100000000], [123, 250000], [18446744073709551615, 7]];
    for i in 0..5 {
        let bilateral = compile_bilateral(cases[i][0], cases[i][1]);
        let (leg_ac, leg_cb) = compile_novation_legs(cases[i][0], cases[i][1]);
        novate(bilateral, leg_ac, leg_cb);
    }
}

#[test(should_fail_with = "novation does not reproduce the bilateral position")]
fn rejects_a_tampered_leg() {
    // A balanced leg whose cash row has been inflated by a cent: A would "receive" more
    // than the bilateral, so the legs no longer compose to it (conservation broken).
    let asset = 1000000;
    let cash = 100000000;
    let bilateral = compile_bilateral(asset, cash);
    let (mut leg_ac, leg_cb) = compile_novation_legs(asset, cash);
    leg_ac.debits[3][CASH] += 1; // A.cash receives one cent more
    leg_ac.credits[2][CASH] += 1; // keep the leg itself balanced
    novate(bilateral, leg_ac, leg_cb);
}

#[test(should_fail_with = "leg A-C is not a zero-account")]
fn rejects_an_unbalanced_leg() {
    let asset = 1000000;
    let cash = 100000000;
    let bilateral = compile_bilateral(asset, cash);
    let (mut leg_ac, leg_cb) = compile_novation_legs(asset, cash);
    leg_ac.debits[3][CASH] += 1; // a debit with no matching credit
    novate(bilateral, leg_ac, leg_cb);
}

#[test(should_fail_with = "the bilateral touches a CCP account")]
fn rejects_a_non_bilateral_input() {
    // A "bilateral" that already names a CCP account is not a bilateral trade to novate.
    let asset = 1000000;
    let cash = 100000000;
    let mut bilateral = compile_bilateral(asset, cash);
    bilateral.accounts[1] = C_ASSET; // B.asset relabelled to C.asset (still balanced)
    let (leg_ac, leg_cb) = compile_novation_legs(asset, cash);
    novate(bilateral, leg_ac, leg_cb);
}
