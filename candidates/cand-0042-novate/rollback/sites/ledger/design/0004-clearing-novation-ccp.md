# Design Note 0004 — AAC as a Privacy-Preserving CCP: Novation and the Clearing Composition

- Status: **non-normative design sketch** (NOT an RFC; takes no permanent number)
- Editor: Arjun Velagapudi
- Touches: 1/PACI, 3/PROOF, 4/REG, 5/NET; the EVENT/1 and VNET/1 application targets; 12/OTC; `circuits/repo`; the cand-0033 kernel-boundary law
- Provenance: records a clearing-flows conversation, 2026-06-14, after the first
  real clearing instrument landed (cand-0040: a FICC/GSD repo, both legs, on the
  EVENT/1 harness). It maps FICC/DTCC clearing onto the existing primitive stack,
  models the one piece that is missing — **novation** — and fixes where it lives.
  It changes no normative text and instantiates no prover.

> **One line.** A central counterparty's whole job is to *interpose itself* (novation)
> and *net the book down* (multilateral netting) under a guaranty that *conserves
> obligations*. AAC already has the conservation guaranty as a checked invariant
> (the Pⁿ zero-account a registry refuses to violate) and the netting as an
> application target (VNET/1); novation is the missing transform. Add it and AAC is
> a **CCP whose matched book is *proven*, not audited — and provable without
> revealing the trades.**

## 1. Why AAC is already shaped like a clearing house

A CCP (FICC for Treasuries and repo; NSCC for equities; DTC as the depository)
does three things: **novates** every bilateral trade so members face the CCP and
not each other; **multilaterally nets** each member's trades in a security to one
position per settlement date; and stands behind the result with a guaranty whose
precondition is that **the book is matched** — every long has an offsetting short,
no value created or destroyed.

That last property — conservation — is not something AAC bolts on. It *is* the
**Pⁿ zero-account** of 1/PACI: a journal balances when, in every incommensurable
basis dimension, total debits equal total credits. Vector Pacioli (Ellerman) makes
this per-dimension, so cash conserves against cash and a security's par against its
par — exactly a clearing invariant. The registry of 4/REG, which "refuses
unbalanced state," is therefore already a clearinghouse that **refuses to clear an
unmatched book**. Netting *preserves* the property (a sum of balanced vectors is
balanced), and VNET/1 proves the net is the faithful compression of the gross
*without revealing the gross* (Pedersen vector commitments). So the natural
endpoint is not "AAC plus a clearing module" but **AAC as a privacy-preserving
CCP**.

## 2. The clearing pipeline → the primitive stack

The FICC/GSD flow, stage by stage, against what already exists:

```
  bilateral trade        novation            multilateral net        net DVP settle
  capture                (interpose CCP)      (per CUSIP / date)      (atomic)
  ───────────────        ───────────────      ─────────────────       ──────────────
  A ⇄ B  (sec ⇄ cash)    A ⇄ C   C ⇄ B        Σ over C's legs →        deliver net sec
  a balanced Pⁿ          two balanced legs    one net position         vs net cash;
  journal per trade      that SUM to A⇄B,     per member/security      registry refuses
                         leaving C flat                                an unmatched book
  ───────────────        ───────────────      ─────────────────       ──────────────
  EVENT/1                NOVATE/1             NET/1  +  VNET/1         TRANSITION/1
  (posting programs:     (PROPOSED —          (5/NET ℤ[X] obligation   (consumes the net
   repo ✓, trade-goods,   this note)          closure, enshrined; +    journal; 4/REG
   UST cash, TBA…)                            VNET/1 amount-vector,    refuses unbalanced)
                                              private)
                          margin / clearing fund overlay: 12/OTC (separate concern)
```

What is **live**: the trade-capture layer (the EVENT/1 harness, cand-0037, with
posting programs `rulebook`, `bom-receipt`, and the repo `circuits/repo`,
cand-0040); the settlement surface (TRANSITION/1); the obligation-closure netting
(NET/1, enshrined in 4/REG). What is the **operator's active work**: VNET/1, the
amount-vector multilateral net. What is **missing**: novation — and it is the piece
that makes the counterparty *central*.

## 3. Novation, modeled

Take a single cleared bilateral trade as a balanced journal `J_AB` — say the open
leg of a repo: A delivers securities to B, B delivers cash to A, each dimension
conserved. **Novation** interposes the CCP `C` and replaces `J_AB` with two
journals:

```
  J_AC :  A delivers securities → C ,  C delivers cash → A     (A's economics: unchanged)
  J_CB :  C delivers securities → B ,  B delivers cash → C     (B's economics: unchanged)
```

Two facts make this exactly right, and both are *provable*:

1. **Conservation (the decomposition is faithful).** Summing the two legs, every
   coordinate that touches `C` appears once as a debit and once as a credit and
   cancels; what remains is precisely A-delivers-securities / A-receives-cash and
   the mirror for B — i.e. `J_AC ⊕ J_CB` reproduces `J_AB`'s effect on A and B.
   Novation neither creates nor destroys obligations.
2. **The CCP is flat per trade (matched book at the unit).** `C` receives `par`
   securities from A and delivers `par` to B (net 0 in the security dimension); it
   delivers `cash` to A and receives `cash` from B (net 0 in cash). A single
   novated trade leaves `C` with **no position** — interposition only.

So the novation obligation, call it **NOVATE/1**, is: *given a balanced bilateral
journal and a CCP identity, the two produced legs are well-formed balanced
journals whose composition reproduces the bilateral effect and leaves the CCP flat.*
It is a balanced-decomposition identity over the same Pⁿ algebra the kernel
already proves — no new primitive, a new *composition*.

## 4. Where novation lives: the application layer, not the kernel

Novation does **not** belong in the kernel. The kernel surface (TRANSITION/1)
consumes balanced *committed* journals plus *opaque* nullifier progress; it learns
nothing about trades, parties, or counterparties (the cand-0033 boundary law makes
this a checked fact). Novation *produces* the CCP-legs as balanced journals that
the kernel then posts like any others. It is a transform **on** journals, sitting
beside EVENT/1 and VNET/1 in the **application layer**.

It is therefore **policy-gated, never base** (4/REG §5; `applications/README`): a
clearing venue MAY require a NOVATE/1 proof as a condition of admission to its
matched book, but the base registry MUST NOT. This keeps the trust base of the
registry fixed (TRANSITION/1, NULLIFY/1, NET/1, plus the reserved aggregation
target) while letting a venue layer the central-counterparty discipline on top —
the same shape EVENT/1 and VNET/1 already take. NOVATE/1 would claim its own event
tag(s) in R1 in the 120–255 application range.

## 5. The closure: a CCP is a participant whose book the registry forces to balance

The three stages compose into one statement:

- **Per trade**, novation interposes `C` and leaves it flat (NOVATE/1, §3).
- **Across trades**, the multilateral net of the membership's positions *against `C`*
  in a security, over a settlement date, is the net delivery/receipt obligation —
  this is the VNET/1 amount-vector net (and, on the obligation side, NET/1's ℤ[X]
  closure).
- **The CCP's own book stays matched** because the registry refuses unbalanced
  state: `C`'s net across all novated legs is a Pⁿ zero-account, or it does not
  clear (TRANSITION/1 / 4/REG).

That is the whole of central clearing expressed in primitives AAC already has plus
one transform: **the CCP is just a participant whose matched book the registry
enforces; novation is the conservation-preserving interposition that makes every
trade face it; netting is the private multilateral compression of the membership's
positions against it.**

## 6. Why "privacy-preserving" is the actual differentiator

FICC is a *trusted* intermediary: it sees every member's positions and its matched
book is an audited fact. AAC inverts that. With VNET's Pedersen commitments and the
EVENT/NOVATE proofs, a member can prove its trades novate and net correctly, and
the CCP can prove its book is matched and the net is the faithful compression of
the gross — **without revealing the constituent trades or member positions**. The
guaranty's precondition (a matched book) becomes a *proof obligation* rather than a
trust assumption. That is a structurally different object from FICC: a CCP you do
not have to see inside of to believe.

## 7. Non-goals (what this note does NOT claim)

- **Risk, not modeled.** Margin / VaR, the guaranty-fund mutualization, and the
  **default waterfall** are where real CCPs are most sophisticated, and AAC models
  none of it here. 12/OTC (margined bilateral contingent contracts) is the only
  toehold. AAC models the clearing *accounting* — conservation, matched book, DVP —
  not the credit risk that sits on top.
- **Fails, only sketched.** CNS-style fail-to-deliver roll-forward (an unsettled
  position becomes the next day's opening position) maps to a nullifier-chained
  carry over TRANSITION/1, but is not built.
- **Legal vs accounting novation.** The legal guaranty — `C` becoming principal to
  both sides by contract — is out of scope; this note models the *accounting*
  novation (the balanced journal decomposition), which is the part AAC can prove.
- **No instantiation.** NOVATE/1 is specified here in prose only; no circuit, no
  verifier, no R1 tag is claimed by this note.

## 8. Status and the buildable next steps

Landed: the repo instrument (cand-0040, `circuits/repo` + `event-repo-open` /
`event-repo-close`, R1 tags 127/128) — the first real clearing input. Specced and
enshrined: TRANSITION/1, NULLIFY/1, NET/1. Specced, in progress (operator): VNET/1.
**Specified by this note, unbuilt: NOVATE/1.**

VNET-safe next slices (the layers *around* the multilateral net, which is the
operator's VNET work):

1. **More posting programs** — a UST cash trade (security ⇄ cash, the simplest
   input), then agency MBS / TBA — extending the EVENT/1 capture layer.
2. **NOVATE/1** — promote this note's §3 to an application-target spec + a
   `circuits/novate` proof: the balanced two-leg decomposition with the CCP-flat
   obligation, policy-gated. The conceptual keystone; it gives VNET a clean
   matched-book interface to net against.
3. **Fails carry** — the nullifier-chained roll-forward over TRANSITION/1.

Related: Design Note [0001](0001-bvr-clearing-kernel.md) (the Pⁿ clearing kernel),
the diagram `0004-clearing-flow.html`, and the repo posting program at
`circuits/repo`.
