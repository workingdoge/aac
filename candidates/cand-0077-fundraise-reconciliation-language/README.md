# cand-0077-fundraise-reconciliation-language

Intent: remove the verifier overclaim from the fundraise closing-books UI.

Scope:
- Renames the post-swap panel from `Book verification` to
  `Book reconciliation`.
- Changes closing-book states from verify/verified vocabulary to
  reconcile/reconciled vocabulary.
- Rewrites the fundraise page sentence so it says the console reconciles the
  issuer books rather than verifies them.

Boundary:
- Presentation-language correction only.
- Does not remove legitimate `verify` language for ProveKit prepare/prove/verify
  or contract signature/replay checks.
- Does not implement the real proof-level book verifier; that remains the
  order-fill proof-binding follow-up.

Intent: remove verifier overclaim from the fundraise closing-books UI

Status: open (pre-threshold).
