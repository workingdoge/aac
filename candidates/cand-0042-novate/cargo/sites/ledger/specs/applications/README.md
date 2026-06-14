# Application targets

**Non-enshrined.** This directory holds **application-target** specifications:
proof targets that are useful and versioned exactly like the core targets of
3/PROOF, but that are **never a condition of registry state by default**
(3/PROOF §4). The registry enshrines exactly three targets (TRANSITION/1,
NULLIFY/1, NET/1) plus the reserved aggregation target; everything here composes
*with* those targets without expanding the registry trust base.

A deployment, market, lender, clearing venue, or admissibility layer **MAY**
require an application-target proof as a *policy* condition. The base registry
**MUST NOT**. Domain tags for application targets are assigned in the range
120–255 (3/PROOF Annex A), first-come via 1/C4 patch, and recorded in the
Deployment Register (R1).

| target | title | status |
|--------|-------|--------|
| [EVENT-COMPLETE/1](EVENT-COMPLETE-1.md) | Schema-Complete Event Compilation (BalancedVectorReceipt) | Raw (promoted from Design Note 0001) |
| [VNET/1](VNET-1.md) | Amount-Vector Netting via Pedersen Commitments | Raw (promoted from Design Note 0001 §7) |
| [NOVATE/1](NOVATE-1.md) | Central-Counterparty Novation | Raw (promoted from Design Note 0004 §3) |
