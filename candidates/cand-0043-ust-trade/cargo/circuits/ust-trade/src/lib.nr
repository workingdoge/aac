//! ust-trade -- a posting program for a US Treasury CASH trade: the seller delivers
//! Treasuries (par) against the buyer's cash. The simplest and most fundamental
//! FICC/GSD clearing input, and -- deliberately -- the canonical BILATERAL that
//! NOVATE/1 novates. compile_ust_trade builds the journal in the SAME party-grouped
//! chart as `novate::compile_bilateral`, so a UST trade that EVENT/1 captures is
//! exactly the bilateral that NOVATE/1 interposes the CCP into. The two proofs
//! compose at the journal_commitment seam (a conformance test in `event-ust` checks
//! the commitments are byte-identical).
//!
//! It is a balanced exchange (each dimension conserved -- securities one way, cash
//! the other), so it is a P^n zero-account for any quantities, as for every other
//! posting program. Basis B=2 {security par, cash}.

use pacioli::journal_balanced;
use event_harness::CompiledJournal;

global N_BASIS: u32 = 2; // basis [security_par, cash_cents]
global N_ROWS: u32 = 4;
global PAR: u32 = 0; // the security par dimension
global CASH: u32 = 1;

// Party-grouped chart, IDENTICAL to novate's: seller = A = {0,1}, buyer = B = {2,3}.
global SELLER_SECURITIES: u32 = 0;
global SELLER_CASH: u32 = 1;
global BUYER_SECURITIES: u32 = 2;
global BUYER_CASH: u32 = 3;

// Schema event-commitment tag (R1 = 129), distinct per posting program.
global TAG_EVENT: Field = 129;

/// A typed UST cash trade: `par` of a Treasury changes hands for `cash_cents`.
pub struct UstTrade {
    pub par: u64,
    pub cash_cents: u64,
}

pub fn event_commitment(e: UstTrade) -> Field {
    hash::poseidon_hash([TAG_EVENT, e.par as Field, e.cash_cents as Field])
}

/// Phi_P for the UST cash trade. Securities move seller -> buyer; cash moves
/// buyer -> seller. Each dimension conserved -> a zero-account.
///   row 0  Seller.securities   Cr par    (seller delivers Treasuries)
///   row 1  Buyer.securities    Dr par    (buyer receives them)
///   row 2  Buyer.cash          Cr cash   (buyer delivers cash)
///   row 3  Seller.cash         Dr cash   (seller receives it)
///
/// NB: the (account, debit, credit) layout is byte-identical to
/// `novate::compile_bilateral` -- this journal IS NOVATE/1's bilateral.
pub fn compile_ust_trade(e: UstTrade) -> CompiledJournal<N_ROWS, N_BASIS> {
    let accounts = [SELLER_SECURITIES, BUYER_SECURITIES, BUYER_CASH, SELLER_CASH];
    let mut debits: [[u64; N_BASIS]; N_ROWS] = [[0; N_BASIS]; N_ROWS];
    let mut credits: [[u64; N_BASIS]; N_ROWS] = [[0; N_BASIS]; N_ROWS];
    credits[0][PAR] = e.par;
    debits[1][PAR] = e.par;
    credits[2][CASH] = e.cash_cents;
    debits[3][CASH] = e.cash_cents;
    CompiledJournal { accounts, debits, credits }
}

#[test]
fn phi_is_balanced_for_all_quantities() {
    let cases = [[0, 0], [1, 1], [1000000, 100000000], [123, 250000], [18446744073709551615, 7]];
    for i in 0..5 {
        let j = compile_ust_trade(UstTrade { par: cases[i][0], cash_cents: cases[i][1] });
        assert(journal_balanced(j.debits, j.credits), "UST trade compiled to an unbalanced journal");
    }
}
