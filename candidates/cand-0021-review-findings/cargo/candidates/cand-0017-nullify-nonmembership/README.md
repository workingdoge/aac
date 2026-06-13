# cand-0017-nullify-nonmembership

**NULLIFY/1** (3/PROOF §4.2) at `circuits/nullify` — the registry's
historical-set anti-replay guard, the piece that turns "consumes the nullifier"
into "…and provably hasn't been consumed before."

Non-membership of a nullifier `v` is the **low-leaf range bracket** over a
strictly-sorted set: `v` lies strictly between two consecutive consumed members
(Field ordering by `bn254::lt`), so it is provably absent — and an already-spent
`v` has no such gap (it equals a neighbour), so the bracket fails. ABI
`[first_root, last_root, sequence_commitment, count]`.

The decisive correctness checks (a vacuous non-membership is the classic ZK bug):
- **accept** a genuine non-member insertion (and before-first / after-last);
- **reject** an **already-spent** value, a **wrong low-leaf**, a tampered root;
- the **sorted invariant** is enforced in-circuit, so the low-leaf is unique.

**Anti-replay composition:** consumes a fresh **EVENT-COMPLETE/1** `event_nullifier`
and **rejects replaying a spent one** — completing the spine (EVENT-COMPLETE/1
derives the nullifier value; NULLIFY/1 enforces single-use against history).

Proven end-to-end on this arm64 Mac (`bb verify` ok). **Bound (honest):** one
insertion, a sorted-array fold root; a production NULLIFY/1 uses a binary indexed
Merkle tree with succinct low-leaf path proofs (Aztec, depth ~32); a sequence
chains single insertions — the non-membership logic is identical.

## Evidence (`eval-self.sh`, attested)

- logic — the sorted invariant + low-leaf bracket + already-spent rejection +
  the EVENT-COMPLETE/1 anti-replay composition are present; workspace lists `nullify`.
- prove — `nargo test` green (7 tests), the sample witness solves, and the whole
  workspace compiles with the new crate.

Status: open (pre-threshold).

## Correction (cand-0021-review-findings, 2026-06-13)

A post-landing review found the evidence above claimed accept coverage for
"before-first" while the landed tests only witnessed middle + after-last
insertion. cand-0021 closes the gap by adding an explicit before-first
(`low_index = 0`) accept test, so the claim is now witnessed rather than
asserted. cand-0021 also hardens NULLIFY/1 to refuse `new_value == 0` (the
empty-slot sentinel TRANSITION/1 reserves), which this candidate did not guard.
