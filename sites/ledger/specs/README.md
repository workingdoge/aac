# AAC RFC — Specification Suite

AAC is a proof-native double-entry accounting system: entities keep private
books, publish provable claims at names, and anchor ledger roots in a
registry that refuses unbalanced state. These specifications define that
system. **They are prescriptive: implementations conform to the
specifications; the specifications do not describe any implementation.**

Process: 1/C4 and 2/COSS of <https://rfc.unprotocols.org> are adopted by
reference. RFC 2119 key words throughout. Specification text is licensed
GPL-3.0-or-later; implementation code is licensed independently.

## Catalog

| # | Name | Title | Status |
|--:|------|-------|--------|
| 1 | PACI | Ledger Semantics | Raw |
| 2 | FACT | Attested Facts and Canonical Form | Raw |
| 3 | PROOF | Proof Targets and the Verifier Contract | Raw |
| 4 | REG | The Root Registry | Raw |
| 5 | NET | Epoch Netting | Raw |
| 6 | NAME | Namespace Binding | Raw |
| 7 | DATA | Evidence and Availability | Raw |
| 8 | SESS | Bilateral Payment Sessions | Raw |
| 9 | PROV | Commercial Objects and Physical Provenance | Reserved |
| 10 | ADMIT | Admissibility and the Nerve | Reserved |
| 11 | GRADE | Evidence Grading | Reserved |
| 12 | OTC | Margined Bilateral Contingent Contracts | **Raw (drafted)** |

Numbers are permanent; specifications are superseded, never renumbered.
Reserved numbers fix scope only.

## Layering

```
        8/SESS            9/PROV  11/GRADE      applications & protocols
           \                /
   6/NAME — 4/REG — 5/NET                       identity & settlement
                \    /
               3/PROOF                          proof
               /      \
          2/FACT     7/DATA                     boundary & evidence
               \      /
               1/PACI                           semantics
                  |
              10/ADMIT                          coordination substrate
```

Dependencies point downward. A specification MUST NOT cite a specification
above it.

## Profile doctrine

No core specification names an algorithm, curve, hash, encoding, vendor,
network, or wire protocol except inside a Profile definition. Concrete
bindings are named, versioned profiles, content-addressed per 2/FACT §3
(handles are informative; `profileId` is identity). Deployed facts —
assigned domain tags, governance addresses, measured costs, handle→id
tables — live in **Registers**: append-only, non-normative documents
(R1: Deployment Register). Conformance is claimed against a
(core, profile-set) pair.

## Lifecycle gates

- Raw → Draft: executable conformance exists (test vectors or a reference
  suite) for every MUST.
- Draft → Stable: a formal companion exists for every soundness-bearing
  MUST, with no open obligation (`sorry` or equivalent); at least two
  independent implementations of the boundary specifications (2/FACT)
  interoperate.
- A Stable specification changes only by supersession.

## One-paragraph map

1/PACI fixes what "balanced" means and nothing else. 2/FACT fixes the one
object that crosses every boundary and the bytes it canonically becomes.
3/PROOF fixes what a proof target is, the targets the system
enshrines (three, plus a reserved aggregation target so batching never
needs a consensus change), and the contract any verifier must discharge —
a proof alone
conveys nothing. 4/REG fixes the only shared infrastructure: a contract
mapping names to roots that accepts exactly the proof-gated transitions of
3/PROOF, singly or in permissionless batches. 5/NET fixes the one global condition: cross-entity channel
balance, demonstrated once per epoch. 6/NAME fixes how entities, charts,
and claims live at names. 7/DATA fixes where evidence lives and what its
loss means. 8/SESS fixes how two parties transact directly with no
intermediary, netting privately and settling publicly. 9–11 are reserved
for the provenance profile, the coordination layer, and evidence grading.
12/OTC fixes how two parties trade on margin instead of full escrow:
collateral is a posting, not a promise — non-negative books make
double-pledging arithmetically infeasible — and default is worn as
visible residuals that every future counterparty's underwriting reads.
