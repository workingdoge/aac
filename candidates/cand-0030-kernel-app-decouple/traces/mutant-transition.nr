//! TRANSITION/1 -- 3/PROOF S4.1, profile `uh-bn254/1`, journal-level locality
//! (1/PACI S3). One of the three targets the registry enshrines: the complete
//! trusted state-transition surface of 4/REG.
//!
//! Statement: a private journal, balanced per the deployment's locality option,
//! applied to a committed private account state, yields the committed next
//! state; the consumed rights' nullifiers chain the nullifier root; the emitted
//! channel facts fold into `fact_fold` in journal order. Every public commitment
//! is recomputed in-circuit from the witness and equated to the claimed input
//! (the Recomputation idiom, 3/PROOF S3).
//!
//! Soundness is carrier injectivity (Annex C): every amount-bearing witness is a
//! u64, so the per-basis sums the balance constraint forms cannot wrap the BN254
//! scalar order -- exactly the obligation `journal_sum_field_sound` discharges in
//! sites/ledger/statements/Core.lean.

use pacioli::{assert_u64, journal_balanced};

// ---- profile shape (a deployment fixes these; recorded in Register R1) ----
global N_BASIS: u32 = 3; // basis dimension B (atomic-unit coordinates)
global N_ROWS: u32 = 4; // journal rows
global N_ACCT: u32 = 4; // accounts in the touched sub-state (depth-2 tree)
global N_NULL: u32 = 2; // consumed-right slots (0 = empty)
global N_FACT: u32 = 2; // emitted channel-fact slots

// ---- domain tags (3/PROOF Annex A, TRANSITION family 0-63; R1 assigns) ----
global TAG_ACCOUNT: Field = 1;
global TAG_NULLIFIER: Field = 2;
global TAG_JOURNAL: Field = 3;
global TAG_FACT_FOLD: Field = 4;
// fold0 := H(tag || "fact_fold/1") -- Annex B label as its big-endian bytes.
global FACT_FOLD_LABEL: Field = 123770337762727488584429361;

/// A journal row: a posting of (debit, credit) vectors to one account.
struct Posting {
    account: u32,
    debit: [u64; N_BASIS],
    credit: [u64; N_BASIS],
}

/// The touched sub-state: per account, per basis, the running debit and credit
/// columns. The Pacioli class of an account is [debit - credit].
struct AcctState {
    debit: [[u64; N_BASIS]; N_ACCT],
    credit: [[u64; N_BASIS]; N_ACCT],
}

/// An emitted channel fact (2/FACT S1), as it enters the fold: the factId
/// d2f-mapped into the field, an oriented side (push/pull), a multiplicity.
struct Fact {
    fact_id: Field,
    side: Field, // 0 = push, 1 = pull
    multiplicity: u32, // >= 1 when active
}

/// The private witness behind a transition.
struct Witness {
    journal: [Posting; N_ROWS],
    prev_state: AcctState,
    nullifiers: [Field; N_NULL], // 0 = empty slot; nonzero = a consumed right
    facts: [Fact; N_FACT],
}

// -------------------------------------------------------------------------
// Recomputation helpers -- pure functions of the witness. `main` and the
// honest prover (`public_inputs`, used by the tests) share these so the
// circuit and its witnesses can never drift.
// -------------------------------------------------------------------------

/// Leaf commitment for one account: H(TAG_ACCOUNT || idx || debit || credit).
fn account_leaf(idx: u32, debit: [u64; N_BASIS], credit: [u64; N_BASIS]) -> Field {
    let mut buf: [Field; 2 + 2 * N_BASIS] = [0; 2 + 2 * N_BASIS];
    buf[0] = TAG_ACCOUNT;
    buf[1] = idx as Field;
    for b in 0..N_BASIS {
        buf[2 + b] = debit[b] as Field;
        buf[2 + N_BASIS + b] = credit[b] as Field;
    }
    hash::poseidon_hash(buf)
}

/// Depth-2 binary Merkle root over the N_ACCT account leaves (N_ACCT == 4).
/// Every node carries the TAG_ACCOUNT domain tag.
fn root_of_leaves(leaves: [Field; N_ACCT]) -> Field {
    let l = hash::poseidon_hash([TAG_ACCOUNT, leaves[0], leaves[1]]);
    let r = hash::poseidon_hash([TAG_ACCOUNT, leaves[2], leaves[3]]);
    hash::poseidon_hash([TAG_ACCOUNT, l, r])
}

/// The account root of a state: commit every account, then Merkleize.
fn account_root(state: AcctState) -> Field {
    let mut leaves: [Field; N_ACCT] = [0; N_ACCT];
    for a in 0..N_ACCT {
        leaves[a] = account_leaf(a as u32, state.debit[a], state.credit[a]);
    }
    root_of_leaves(leaves)
}

/// begin + posted = end, per account, per basis (the state arithmetic). The
/// end amounts are roundtripped back into u64 -- a balance that overflows the
/// carrier is rejected here, which keeps every committed amount bounded.
fn end_state(w: Witness) -> AcctState {
    let mut end = AcctState { debit: [[0; N_BASIS]; N_ACCT], credit: [[0; N_BASIS]; N_ACCT] };
    for a in 0..N_ACCT {
        for b in 0..N_BASIS {
            let mut sd = w.prev_state.debit[a][b] as Field;
            let mut sc = w.prev_state.credit[a][b] as Field;
            for r in 0..N_ROWS {
                let sel = (w.journal[r].account == a as u32) as Field;
                sd += sel * (w.journal[r].debit[b] as Field);
                sc += sel * (w.journal[r].credit[b] as Field);
            }
            end.debit[a][b] = assert_u64(sd);
            end.credit[a][b] = assert_u64(sc);
        }
    }
    end
}

/// Chain the nullifier root over the consumed rights: each nonzero slot is
/// inserted, empty slots leave the root untouched (so the root is unchanged
/// unless a right is consumed). Real nullifiers must be pairwise distinct.
fn next_nullifier_root(prev_root: Field, nullifiers: [Field; N_NULL]) -> Field {
    for i in 0..N_NULL {
        for j in 0..N_NULL {
            if i < j {
                let both = (nullifiers[i] != 0) as Field * (nullifiers[j] != 0) as Field;
                let eq = (nullifiers[i] == nullifiers[j]) as Field;
                assert(both * eq == 0, "duplicate nullifier insertion");
            }
        }
    }
    let mut acc = prev_root;
    for i in 0..N_NULL {
        let active = (nullifiers[i] != 0) as Field;
        let step = hash::poseidon_hash([TAG_NULLIFIER, acc, nullifiers[i]]);
        acc = active * step + (1 - active) * acc;
    }
    acc
}

/// fact_fold over the first `count` emitted facts, in journal order
/// (3/PROOF Annex B). Side is constrained binary; an active fact's
/// multiplicity must be >= 1 (1/PACI S4).
fn fact_fold_of(facts: [Fact; N_FACT], count: u32) -> Field {
    assert(count <= N_FACT, "fact_count exceeds the emitted-fact slots");
    let mut fold = hash::poseidon_hash([TAG_FACT_FOLD, FACT_FOLD_LABEL]);
    for i in 0..N_FACT {
        let f = facts[i];
        assert(f.side * (f.side - 1) == 0, "fact side is not binary");
        let active = (i < count) as Field;
        assert(active * ((f.multiplicity == 0) as Field) == 0, "active fact has multiplicity 0");
        let step = hash::poseidon_hash(
            [TAG_FACT_FOLD, fold, f.fact_id, f.side, f.multiplicity as Field],
        );
        fold = active * step + (1 - active) * fold;
    }
    fold
}

/// journal_commitment: the canonical order-binding fold, via the shared ledger
/// lib -- so EVENT-COMPLETE/1 produces the SAME commitment for the journal it
/// certifies as Phi_R(event). (Construction unchanged; value byte-identical.)
fn journal_commitment_of(journal: [Posting; N_ROWS]) -> Field {
    let mut accounts: [u32; N_ROWS] = [0; N_ROWS];
    let mut debits: [[u64; N_BASIS]; N_ROWS] = [[0; N_BASIS]; N_ROWS];
    let mut credits: [[u64; N_BASIS]; N_ROWS] = [[0; N_BASIS]; N_ROWS];
    for r in 0..N_ROWS {
        accounts[r] = journal[r].account;
        debits[r] = journal[r].debit;
        credits[r] = journal[r].credit;
    }
    ledger::journal_commitment(accounts, debits, credits)
}

/// The honest prover: derive the public ABI vector from the private witness and
/// the trusted context (the prior nullifier root and the deployment context
/// commitment). This is also the validity gate -- it asserts journal balance,
/// amount bounds, nullifier distinctness, and fact well-formedness. Returned in
/// the normative ABI order of 3/PROOF S4.1.
fn public_inputs(
    w: Witness,
    prev_nullifier_root: Field,
    context_commitment: Field,
    fact_count: u32,
) -> [Field; 8] {
    // valid account indices
    for r in 0..N_ROWS {
        assert(w.journal[r].account < N_ACCT, "account index out of range");
    }
    // journal balance (per basis) -- the K(M) class is zero
    let mut debits: [[u64; N_BASIS]; N_ROWS] = [[0; N_BASIS]; N_ROWS];
    let mut credits: [[u64; N_BASIS]; N_ROWS] = [[0; N_BASIS]; N_ROWS];
    for r in 0..N_ROWS {
        debits[r] = w.journal[r].debit;
        credits[r] = w.journal[r].credit;
    }
    assert(journal_balanced(debits, credits), "journal is not balanced");

    [
        account_root(w.prev_state),
        account_root(end_state(w)),
        prev_nullifier_root,
        next_nullifier_root(prev_nullifier_root, w.nullifiers),
        journal_commitment_of(w.journal),
        context_commitment,
        fact_fold_of(w.facts, fact_count),
        fact_count as Field,
    ]
}

/// TRANSITION/1. Public ABI order (normative, 3/PROOF S4.1):
///   0 prev_account_root      1 next_account_root
///   2 prev_nullifier_root    3 next_nullifier_root
///   4 journal_commitment     5 context_commitment (unconstrained, 4/REG)
///   6 fact_fold              7 fact_count
fn main(
    prev_account_root: pub Field,
    next_account_root: pub Field,
    prev_nullifier_root: pub Field,
    next_nullifier_root: pub Field,
    journal_commitment: pub Field,
    context_commitment: pub Field,
    fact_fold: pub Field,
    fact_count: pub u32,
    w: Witness,
) {
    let want = public_inputs(w, prev_nullifier_root, context_commitment, fact_count);

    // Recompute every commitment from the witness and equate to the claim.
    assert(prev_account_root == want[0], "prev_account_root does not commit prev_state");
    assert(next_account_root == want[1], "next_account_root does not commit the next state");
    // want[2] == prev_nullifier_root by construction (trusted context).
    assert(next_nullifier_root == want[3], "next_nullifier_root not chained from prev");
    assert(journal_commitment == want[4], "journal_commitment does not commit the journal");
    // want[5] == context_commitment: ABI #5 is `unconstrained` (4/REG S2 binds it).
    assert(fact_fold == want[6], "fact_fold does not fold the emitted facts");
    assert((fact_count as Field) == want[7], "fact_count disagrees");
}

// -------------------------------------------------------------------------
// Tests -- the eval gate. nargo executes these on the ACVM (no prover needed).
// -------------------------------------------------------------------------

/// A balanced two-row transfer: row 0 debits account 1 by (10,0,0); row 1
/// credits account 2 by (10,0,0). Journal columns agree (10 = 10); accounts 1
/// and 2 move; one right is consumed; one push fact is emitted.
fn sample() -> Witness {
    let zero3: [u64; N_BASIS] = [0, 0, 0];
    let ten: [u64; N_BASIS] = [10, 0, 0];
    Witness {
        journal: [
            Posting { account: 1, debit: ten, credit: zero3 },
            Posting { account: 2, debit: zero3, credit: ten },
            Posting { account: 0, debit: zero3, credit: zero3 },
            Posting { account: 0, debit: zero3, credit: zero3 },
        ],
        prev_state: AcctState {
            debit: [[0, 0, 0], [5, 0, 0], [0, 0, 0], [0, 0, 0]],
            credit: [[0, 0, 0], [0, 0, 0], [3, 0, 0], [0, 0, 0]],
        },
        nullifiers: [777, 0],
        facts: [
            Fact { fact_id: 0xabc, side: 0, multiplicity: 1 },
            Fact { fact_id: 0, side: 0, multiplicity: 0 },
        ],
    }
}

#[test]
fn balanced_transition_accepts() {
    let w = sample();
    let p = public_inputs(w, 100, 42, 1);
    main(p[0], p[1], p[2], p[3], p[4], p[5], p[6], 1, w);
}

#[test(should_fail_with = "journal is not balanced")]
fn unbalanced_journal_rejects() {
    let mut w = sample();
    w.journal[1].credit = [9, 0, 0]; // 10 debits vs 9 credits -- class != 0
    let p = public_inputs(w, 100, 42, 1);
    main(p[0], p[1], p[2], p[3], p[4], p[5], p[6], 1, w);
}

#[test(should_fail_with = "next_account_root does not commit the next state")]
fn tampered_next_root_rejects() {
    let w = sample();
    let p = public_inputs(w, 100, 42, 1);
    main(p[0], p[1] + 1, p[2], p[3], p[4], p[5], p[6], 1, w); // tamper next root
}

#[test(should_fail_with = "duplicate nullifier insertion")]
fn double_spend_rejects() {
    let mut w = sample();
    w.nullifiers = [777, 777]; // same right consumed twice
    let p = public_inputs(w, 100, 42, 1);
    main(p[0], p[1], p[2], p[3], p[4], p[5], p[6], 1, w);
}

#[test(should_fail_with = "active fact has multiplicity 0")]
fn zero_multiplicity_fact_rejects() {
    let mut w = sample();
    w.facts[0].multiplicity = 0; // an emitted fact with multiplicity 0
    let p = public_inputs(w, 100, 42, 1);
    main(p[0], p[1], p[2], p[3], p[4], p[5], p[6], 1, w);
}

#[test]
fn print_public_inputs() {
    // Prints the sample's public ABI vector (run with --show-output). Used to
    // populate Prover.toml and the docs example; reproducible from `sample()`.
    let w = sample();
    let p = public_inputs(w, 100, 42, 1);
    println(p);
}

#[test]
fn nullifier_root_unchanged_when_no_right_consumed() {
    let mut w = sample();
    w.nullifiers = [0, 0]; // nothing consumed
    let p = public_inputs(w, 100, 42, 1);
    // ABI #2 (prev) and #3 (next) nullifier roots must coincide.
    assert(p[2] == p[3], "nullifier root moved with no consumption");
    main(p[0], p[1], p[2], p[3], p[4], p[5], p[6], 1, w);
}

// -- composition: the BVR journal is what TRANSITION/1 posts ----------------
#[test]
fn composition_transition_posts_the_bvr_journal() {
    // EVENT-COMPLETE/1 certifies journal_commitment = ledger::journal_commitment(
    // Phi_R(event)). Here we post the SAME journal to a fresh state, check that
    // TRANSITION/1 recomputes the same journal_commitment, and advance the
    // nullifier root over an opaque consumed right -- so the two targets compose.
    //
    // The journal is the goods-receipt-invoice Pn conformance vector (cand-0009),
    // inlined as a literal FIXTURE so this enshrined circuit carries no dependency
    // on the rulebook application crate (cand-0030: sever the kernel->app
    // back-edge). That Phi_R actually emits this exact vector is pinned app-side by
    // the rulebook crate's own phi_reproduces_the_conformance_vector test; the
    // fixture re-proves the composition claim here without a code edge. The durable
    // kernel<->app contract is journal_commitment itself plus opaque-nullifier
    // semantics, not this fixture.
    let accounts: [u32; N_ROWS] = [0, 1, 2, 3];
    let debits: [[u64; N_BASIS]; N_ROWS] = [[0, 50, 0], [10000, 0, 0], [0, 0, 0], [0, 0, 0]];
    let credits: [[u64; N_BASIS]; N_ROWS] = [[0, 0, 0], [0, 0, 0], [0, 50, 0], [10000, 0, 0]];
    let journal = [
        Posting { account: accounts[0], debit: debits[0], credit: credits[0] },
        Posting { account: accounts[1], debit: debits[1], credit: credits[1] },
        Posting { account: accounts[2], debit: debits[2], credit: credits[2] },
        Posting { account: accounts[3], debit: debits[3], credit: credits[3] },
    ];
    // An opaque consumed-right nullifier (a hash image): TRANSITION/1 consumes
    // nullifiers as opaque nonzero Fields; their derivation lives app-side.
    let n: Field = 0x1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d;
    let w = Witness {
        journal,
        prev_state: AcctState { debit: [[0; N_BASIS]; N_ACCT], credit: [[0; N_BASIS]; N_ACCT] },
        nullifiers: [n, 0],
        facts: [
            Fact { fact_id: 0, side: 0, multiplicity: 0 },
            Fact { fact_id: 0, side: 0, multiplicity: 0 },
        ],
    };
    let p = public_inputs(w, 100, 42, 0);
    main(p[0], p[1], p[2], p[3], p[4], p[5], p[6], 0, w);
    assert(p[4] == ledger::journal_commitment(accounts, debits, credits), "journal commitments diverge");
    assert(p[2] != p[3], "nullifier root did not advance");
}

use rulebook::GoodsReceiptInvoice;
