# cand-0016-ledger-composition

Makes the three-proof spine **compose**. A new shared `circuits/ledger` lib
carries the canonical commitments — `journal_commitment`, `participant_set`,
`event_nullifier` — so the enshrined **TRANSITION/1** and the application target
**EVENT-COMPLETE/1** agree by construction rather than diverging.

- **`ledger`** — `journal_commitment(accounts, debits, credits)` lifted verbatim
  from TRANSITION/1 (so its value is **byte-identical**), plus `participant_set`
  and `event_nullifier`.
- **`rulebook`** — the compiled journal now carries **account indices**, and the
  schema's `event_commitment` lives here.
- **`transition`** — uses `ledger::journal_commitment` (value unchanged; its
  `Prover.toml` and the `aac-transition` UI value stay valid), and gains a
  **composition test**: it posts the journal `Φ_R(event)` produces to a fresh
  state and consumes the BVR's `event_nullifier`.
- **`event-complete`** — adopts the shared primitives; its `journal_commitment`
  is now the canonical one — **exactly what TRANSITION/1 posts** (`0x014292…`).

So a BalancedVectorReceipt's `(journal_commitment, event_nullifier)` are
precisely what the registry posts and consumes: BVR → TRANSITION → registry,
composing. Proven end-to-end on this arm64 Mac (`bb verify` ok).

## Evidence (`eval-self.sh`, attested)

- shared — ledger carries the canonical primitives; both circuits use them; the
  composition test is present; the workspace lists `ledger`.
- prove — `nargo test` green across all five crates (25 tests, incl.
  `composition_transition_posts_the_bvr_journal`); **TRANSITION/1 byte-identity**
  (its landed `Prover.toml`, jc `0x2d80c1…`, still solves); event-complete solves.

Status: open (pre-threshold).
