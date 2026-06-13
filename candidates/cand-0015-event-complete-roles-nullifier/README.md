# cand-0015-event-complete-roles-nullifier

Grows the EVENT-COMPLETE/1 circuit (`circuits/event-complete`) toward a complete
BalancedVectorReceipt by adding two obligations:

- **Role coverage (obligation 2)** — the schema's required roles (Buyer,
  Supplier) must be present and **distinct**; `participant_set` commits them. No
  self-dealing, no missing party.
- **The event nullifier (obligation 9)** — a one-shot identity
  `N = H(rulebook_id, event_commitment, participant_set)`, derived **in-circuit**.
  Because N is bound to the committed event *and* parties, a prover cannot replay
  the event under a fresh nullifier; the registry inserts N once and refuses it
  thereafter (1/PACI §5, 2/FACT §3/§8). This is the anti-double-application guard.

Now realizes obligations 2, 4, 5, 9, 10. Public ABI grows to
`[rulebook_id, event_commitment, participant_set, journal_commitment,
event_nullifier]`. Proven end-to-end on this arm64 Mac (`bb verify` ok; ~14k
padded UltraHonk gates, 39 ACIR opcodes).

## Evidence (`eval-self.sh`, attested)

- obligations — role coverage + the in-circuit nullifier (recomputed/equated) +
  the journal binding are present, with the anti-replay and distinctness tests.
- prove — `nargo test` green (accept a complete receipt; reject self-dealing,
  a missing role, a **foreign nullifier**; nullifier is event/party/rulebook-
  distinguishing) and the sample witness solves (`nargo execute`).

Status: open (pre-threshold).
