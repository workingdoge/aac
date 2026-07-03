# Application targets

**Non-enshrined.** This directory holds **application-target** and
**application-surface** specifications: proof targets, statement surfaces, and
policy objects that are useful and versioned exactly like the core targets of
3/PROOF, but that are **never a condition of registry state by default**
(3/PROOF section 4). The registry enshrines exactly three targets
(TRANSITION/1, NULLIFY/1, NET/1) plus the reserved aggregation target;
everything here composes *with* those targets without expanding the registry
trust base.

A deployment, market, lender, clearing venue, or admissibility layer **MAY**
require an application-target proof or application-surface statement as a
*policy* condition. The base registry **MUST NOT**. Domain tags for
application targets are assigned in the range 120-255 (3/PROOF Annex A),
first-come via 1/C4 patch, and recorded in the Deployment Register (R1).
Application surfaces that do not define an in-circuit commitment or proof
target do not receive a domain tag merely for being named here.

| surface/target | title | status |
|----------------|-------|--------|
| [BCC/1](BCC-1.md) | Bilateral Cancellation Certificate | Raw |
| [EVENT-COMPLETE/1](EVENT-COMPLETE-1.md) | Schema-Complete Event Compilation (BalancedVectorReceipt) | Raw (promoted from Design Note 0001) |
| [FUNDRAISE-CLEARING/1](FUNDRAISE-CLEARING-1.md) | Private Balance-Sheet Fundraising Settlement | Raw |
| [LEDGER/1](LEDGER-1.md) | Committed Ledger State and Statement Interface | Raw |
| [NOVATE/1](NOVATE-1.md) | Central-Counterparty Novation | Raw (promoted from Design Note 0004 section 3) |
| [VNET/1](VNET-1.md) | Amount-Vector Netting via Pedersen Commitments | Raw (promoted from Design Note 0001 section 7) |
