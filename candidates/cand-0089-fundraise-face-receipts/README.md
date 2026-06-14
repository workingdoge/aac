# cand-0089-fundraise-face-receipts

Intent: Generate FUNDRAISE-CLEARING/1 simplicial face receipts from the runtime packet and expose them through the demo summary.

Status: open (pre-threshold).

This candidate turns the cand-0088 simplicial profile into a visible runtime
receipt layer. The fundraise runtime now emits named face receipts for the
capacity, payment, agreement, transition, VNET, statement, settlement, and
nullifier faces. The demo runner includes that receipt bundle in the receipt
and summary, and the web component renders it as a verifier checklist.

Boundary: this is not a new Noir circuit or public ABI. The live ProveKit
package still proves the existing VNET and balance-sheet packets; these face
receipts are deterministic runtime/public-input receipts over the selected
fundraise packet.
