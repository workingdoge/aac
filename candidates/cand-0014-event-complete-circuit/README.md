# cand-0014-event-complete-circuit

The **EVENT-COMPLETE/1 circuit** at `circuits/event-complete` — Φ_R wired into a
proof. The prover witnesses the **typed event** (its private quantities); the
circuit runs the `rulebook` compiler **in-circuit** and binds `journal_commitment`
to the *compiled* journal. So the proof attests:

> `journal_commitment` commits to **Φ_R(event)** — the schema's deterministic
> image of the committed event — and that journal is a Pⁿ zero-account.

…never merely "some balanced journal exists." That closes "fraud can balance":
the journal is not a free input. Realizes EVENT-COMPLETE/1 obligations 4
(canonical compilation), 5 (zero-account), 10 (recomputation). Also makes
`rulebook`'s struct fields `pub` for cross-crate use.

Proven end-to-end on this arm64 Mac: `bb verify` → "Proof verified successfully"
(14,348 UltraHonk gates).

## Evidence (`eval-self.sh`, attested)

- binds — the circuit runs Φ_R in-circuit, recomputes `journal_commitment` over
  the compiled journal, checks the zero-account, and carries the negative tests;
  workspace lists the crate.
- prove — `nargo test` green (accept the schema image; **reject a journal
  commitment from a different event**; reject a tampered event commitment) and
  the sample witness solves (`nargo execute`).

Status: open (pre-threshold).
