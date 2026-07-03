# cand-0078-fundraise-summary-driven-ui

Intent: Make the fundraise presentation render order, fill, balance, and reconciliation data from the runner summary instead of component constants.

Status: open (pre-threshold).

Cargo moves private order-fill facts out of the Lit component and into the
runner summary. The runner projects the packet's round policy and subscriptions
into order, metric, fill, opening-balance, and reconciliation rows. The web
component renders those fields in captured and live modes, while retaining only
presentation state locally.
