# cand-0087-fundraise-ledger-language

Intent: Bind FUNDRAISE-CLEARING/1 and the fundraise demo presentation to LEDGER/1 ledger-state and statement vocabulary.

Status: open (pre-threshold).

## Cargo

- Reframe FUNDRAISE-CLEARING/1 as a statement target over LEDGER/1 ledger
  state: pre-state capacity statement, transition-linked private settlement,
  post-state balance-sheet statement, and receipt-issuance statement.
- Reword the fundraise page and demo component so the primary product path is
  issuer private ledger -> round capacity statement -> selected subscription
  batch -> statement verifier -> receipt issuance.
- Keep BCC/1, VNET/1, and ProveKit as agreement/proof-engine details in the
  verifier drawer rather than the first concept shown to users.
