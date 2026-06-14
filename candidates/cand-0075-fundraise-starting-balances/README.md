# cand-0075-fundraise-starting-balances

Intent: make the fundraise presentation console show the opening private order
state before the two fills run.

Scope:
- Adds a `Starting balances` panel to the order ticket.
- Names the opening balances as 0 USDC collected, 0 receipt units issued, and
  the full order quantity still open.
- Updates the fundraise page copy so the presentation narrative matches the
  component.

Boundary:
- This is a presentation coherence change only.
- It does not change the ProveKit witness, runner, contracts, specs, or queue
  law surfaces.

Intent: show starting balances in the private order-fill demo

Status: open (pre-threshold).
