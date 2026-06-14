# Threshold Brief: cand-0036-naming-layering

Generated: 2026-06-14T02:50:33Z
Status: validated
Intent: Land Design Note 0003 -- Naming and Layering: the kernel/app vocabulary after the cand-0033 boundary law. NON-NORMATIVE. Settles the names for the now-enforced kernel/app split: EVENT-COMPLETE/1 -> EVENT/1 (statement: 'EVENT/1 proves a typed Event, under a pinned Posting Program, compiles to the committed P^n journal'); rulebook -> posting program (Phi_R is the posting program's compile function); kernel layer {pacioli,hash,ledger,transition,nullify} vs application layer {posting-program, receipt, event}; the circuits crate/package rename plan (circuits/rulebook->circuits/posting-program, circuits/event-complete->circuits/event); and records NET/1 (fact closure over channel facts, Z[X]) vs VNET/1 (amount-vector clearing over posted TRANSITION/1 journals, P^n per-basis Pedersen -- binds to TRANSITION/1 journal_commitments, lives OUTSIDE TRANSITION/1). The actual spec/code renames are sequenced execution follow-ons (EVENT-COMPLETE-1.md spec rename coordinated with the active VNET work). Steers clear of VNET implementation. Witnessed: the note carries the vocabulary decisions + the EVENT/1 statement + the layer sets + NET/VNET separation, and all cross-references resolve.
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=a324246e80c0202d95f4e3a4b88dc8b048e92e49a9326a4e6bccd1e76b94cba1

## Cargo (what lands if admitted)

- `cargo/sites/ledger/design/0003-naming-and-layering.md` is NEW at `sites/ledger/design/0003-naming-and-layering.md`:      143 lines
- `cargo/sites/ledger/design/README.md` replaces `sites/ledger/design/README.md`: +1/-0 lines vs live

## Witnessed behavioral delta (task: land Design Note 0003 (non-normative): the kernel/app naming + layering vocabulary after the cand-0033 boundary law -- EVENT-COMPLETE/1 -> EVENT/1 (+ its statement), rulebook -> Posting Program, kernel {pacioli,hash,ledger,transition,nullify} vs application {posting-program,receipt,event} layer sets, the circuits crate rename plan, and NET/1 vs VNET/1 placement (VNET binds to TRANSITION/1 journal_commitments but lives outside it). Witnessed: the note carries the decided vocabulary + the EVENT/1 statement + the non-normative marker, every referenced artifact resolves in the live tree, the README indexes 0003, and a mutant stripped of the statement is caught.)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
