# Design notes

**Non-normative.** This directory holds design sketches and architecture
notes that inform the RFC suite without being part of it. Nothing here is
prescriptive: the specifications under `../specs` are the normative text, and
a design note carries no conformance force. A note may later be promoted —
in whole or in part — into a numbered RFC, an application-target spec, or a
register entry, at which point the normative version supersedes the sketch.

| # | Title | Touches |
|--:|-------|---------|
| 0001 | [The BalancedVectorReceipt — a Pⁿ Clearing Kernel](0001-bvr-clearing-kernel.md) | 1/PACI, 2/FACT, 3/PROOF, 4/REG, 5/NET; future 9/PROV, 10/ADMIT, 12/OTC |
| 0002 | [The World Stack for AAC: AgentKit + ProveKit](0002-world-stack-agentkit-provekit.md) | 2/FACT, 3/PROOF, 4/REG, EVENT-COMPLETE/1; future 9/PROV, 10/ADMIT, 12/OTC |
| 0003 | [Naming and Layering: the kernel/app vocabulary after the boundary law](0003-naming-and-layering.md) | 1/PACI, 2/FACT, 3/PROOF, 4/REG, EVENT-COMPLETE/1; the `circuits/` crates |
| 0004 | [AAC as a Privacy-Preserving CCP: Novation and the Clearing Composition](0004-clearing-novation-ccp.md) ([diagram](0004-clearing-flow.html)) | 1/PACI, 3/PROOF, 4/REG, 5/NET, EVENT/1, VNET/1, 12/OTC; `circuits/repo` |
