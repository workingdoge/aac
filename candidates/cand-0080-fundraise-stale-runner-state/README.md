# cand-0080-fundraise-stale-runner-state

Intent: Treat missing reconciliation/verifier fields from a live runner response as stale runner state, not a book mismatch.

Status: open (pre-threshold).

Scope: presentation component only. Accepted live-runner responses that do not
carry the current summary display fields are treated as stale runner state, not
as a failed book reconciliation.
