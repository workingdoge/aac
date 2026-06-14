# cand-0076-fundraise-book-verification

Intent: make the fundraise presentation console verify the issuer books after
the private order fill/swap.

Scope:
- Adds a `Book verification` reconciliation band after the order ticket.
- Shows opening state, swap deltas, and closing balances for USDC collected,
  receipt units issued, and order units left open.
- Updates fundraise page copy so the narrative mentions post-swap book
  verification.

Boundary:
- Presentation coherence only.
- Does not alter the ProveKit witness, runner, contracts, specs, or queue-law
  surfaces.

Intent: show issuer book verification after the private order fill

Status: open (pre-threshold).
