# Design Note 0003 — Naming and Layering: the kernel/app vocabulary after the boundary law

- Status: **non-normative design sketch** (NOT an RFC; takes no permanent number)
- Editor: Arjun Velagapudi
- Touches: 1/PACI, 2/FACT, 3/PROOF, 4/REG; the EVENT-COMPLETE/1 application target; the `circuits/` crates; the cand-0033 kernel-boundary law
- Provenance: records a naming/layering conversation, 2026-06-14, after the
  three-step kernel/app decouple landed (cand-0030 severed the back-edge,
  cand-0032 split `ledger` vs `receipt` and reassigned the colliding tags,
  cand-0033 made the boundary a checked law). This note settles the *names*
  for a split that is now mechanically enforced; it changes no normative text.

> **One line.** The kernel proves *the books balance and the state advances*;
> an application proves *a real event was booked under a pinned program*. Now
> that the boundary between them is a checked invariant, this note fixes the
> vocabulary: **EVENT/1** over a **Posting Program**, sitting in the
> **application layer** on top of the **kernel**, with **VNET/1** clearing
> amount-vectors *beside* the kernel, never inside it.

## 1. Why name things now

Until cand-0033 the kernel/application split was doctrine (4/REG §5: the base
registry MUST NOT require an application target) but not a checked fact. The
boundary law `tools/kernel-boundary-check.sh` now refuses, on every post-land,
any kernel crate that depends on or imports an application crate. A split that
the tooling enforces deserves stable names — otherwise the law guards a
boundary whose two sides are described inconsistently across the specs, the
circuits, and the registers. This note is that vocabulary pass. It is
deliberately *placement and naming only*: no prover, no verifier, no VNET
instantiation.

## 2. The two layers and their members

The kernel set is the stable, enshrined-or-foundational base. The application
set is everything that builds on it. The cand-0033 checker pins the kernel set
literally; the application set is "everything else in the workspace," so it is
auto-covered as new schemas arrive.

```
KERNEL (schema-agnostic; the enforced base)
  pacioli     K(M) balance primitives, the in-circuit face of Core.lean
  hash        the Poseidon2 commitment sponge
  ledger      the canonical commitment seam: journal_commitment + TAG_JOURNAL
  transition  TRANSITION/1 — the trusted state-transition surface of 4/REG
  nullify     NULLIFY/1 — historical anti-replay

APPLICATION (schema-specific; builds ON the kernel, never the reverse)
  posting-program   the deterministic event→journal compiler (was: rulebook)
  receipt           the BVR identities the kernel consumes opaquely
                    (participant_set, event_nullifier; cand-0032)
  event             the schema-complete event proof (was: event-complete)
```

Names for the layers themselves: **the kernel** and **the application layer**
(or **apps**). We avoid "core" for the kernel (1/PACI already uses "core" for
the (core, profile-set) conformance pair) and avoid "library" as a layer name
(it is a Nargo crate *type*, orthogonal to the kernel/app axis — both layers
contain libs and bins).

## 3. EVENT-COMPLETE/1 → EVENT/1

The application target is renamed **EVENT/1**. Its statement, stated plainly:

> **EVENT/1** proves a typed **Event**, under a pinned **Posting Program**,
> compiles to the committed **Pⁿ journal**.

"Complete" was always doing two jobs — naming the target *and* hinting at the
schema-coverage obligation — and the second job is better carried by the
obligation list inside the spec than by the target's name. EVENT/1 is shorter,
parallels TRANSITION/1 and NULLIFY/1, and reads as "the proof *about an
event*." The completeness-not-truth boundary (the registry MUST NOT require it;
it refuses *incomplete* receipts, the kernel refuses *unbalanced* state) is
unchanged — only the label moves.

## 4. rulebook → Posting Program

`rulebook` becomes the **Posting Program**: the deterministic, pinned function
that compiles a typed event into the canonical Pⁿ journal. Φ_R is the posting
program's *compile* step — `J = Φ_R(E, q, evidence, roles)` is read as "the
posting program posts event E to journal J." "Rulebook" undersold it: the
artifact is not a book of rules to consult but an executable program whose
*image* the journal is — which is exactly why "fraud can balance" is closed
(the journal is the program's output on an attested event, not an arbitrary
balanced input). A deployment **pins** a posting program (by content hash — see
`rulebook_id` in EVENT/1's ABI, itself a candidate for renaming to
`program_id`), and EVENT/1 proves the journal is *that* program's image.

## 5. Crate / package rename plan (circuits)

The vocabulary implies two `circuits/` renames, to be executed as follow-ons
(§7), not in this note:

| now (dir / package) | becomes |
|---------------------|---------|
| `circuits/rulebook` / `rulebook` | `circuits/posting-program` / `posting_program` |
| `circuits/event-complete` / `event_complete` | `circuits/event` / `event` |

`receipt` (cand-0032) keeps its name. The kernel crates keep their names. The
cand-0033 boundary checker's `KERNEL` set is unaffected (it lists only kernel
crates); its example comments mentioning `rulebook` update with the rename. The
renames cascade into: each crate's `Nargo.toml` + the workspace members; every
`use rulebook`/`use event_complete`; the `EVENT-COMPLETE-1.md` spec text and
its `applications/` index; Design Note 0001; R1's tag-120 reconciliation note;
and any web component or registry reference. Because `event_nullifier`/
`participant_set` already live in `receipt` and the kernel consumes them
opaquely (cand-0032), **no kernel crate and no commitment value changes** — the
rename is pure relabeling, like a slimmer cand-0032.

## 6. NET/1 vs VNET/1 — distinct, and VNET sits beside the kernel

To keep the layering honest, two netting notions stay separate (this note only
*records* the placement; the VNET instantiation is out of scope and paused):

- **NET/1** — closure over *channel facts*, netting in ℤ[X] (2/FACT lineage).
- **VNET/1** — clearing of *posted amount-vectors* over Pⁿ with per-basis
  Pedersen generators. It **binds to** TRANSITION/1 `journal_commitment`s (ABI
  slot 4) — every netted atom links back to an exact posted journal — but it
  **lives outside** TRANSITION/1: the kernel state-transition stays
  schema-agnostic and does not grow a netting obligation. VNET/1 is an
  application-layer (or a future enshrined-aggregation) target that *reads*
  kernel commitments, in the same "recompute-vs-consume" spirit as the rest of
  the app layer.

## 7. Sequencing (execution is follow-on, and coordinated)

This note decides the names; it does not rename anything normative or in code.
The execution candidates, in order, each modest and reversible:

1. **circuits relabel** — `rulebook → posting-program`, `event-complete →
   event` across `circuits/` + the boundary checker's comments. Circuits-only,
   value-preserving (no commitment changes); witnessed by `nargo test
   --workspace` green and the boundary checker still clean.
2. **spec rename** — `EVENT-COMPLETE-1.md → EVENT-1.md` (+ the `applications/`
   index, the EVENT/1 statement, `rulebook_id → program_id`), and the term
   "posting program" through 1/PACI/2/FACT/3/PROOF where "rulebook" appears.
   **Coordinated with the active VNET work**: `EVENT-COMPLETE-1.md` and the
   `applications/` index are VNET-entangled (VNET-1.md cross-references
   EVENT-COMPLETE/1), so this candidate is sequenced to avoid racing the VNET
   author in the same files, not landed blind.
3. **layer-naming surfacing** (optional) — reflect "kernel" / "application
   layer" in `circuits/`'s top-level README and the web architecture view.

Until those land, the normative specs and crate names are unchanged; this
sketch carries no conformance force (per the design/README boundary).
