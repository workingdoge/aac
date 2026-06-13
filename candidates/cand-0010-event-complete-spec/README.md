# cand-0010-event-complete-spec

Promotes EVENT-COMPLETE/1 from the Design Note 0001 sketch to an
**application-target spec** at `sites/ledger/specs/applications/` (with an
`applications/README` establishing the non-enshrined directory). The target
proves `J = Φ_R(E, q, evidence, roles)` — a typed, attested 2/FACT event
compiles canonically to a Pⁿ vector zero-account — carried by a
BalancedVectorReceipt.

Holds the line from the design conversation: it **composes** with TRANSITION/1,
the registry **MUST NOT** require it by default (4/REG §5; 3/PROOF §4), and it
proves *completeness, not truth*. Includes the 10-point obligation list, the BVR
public ABI, the projection/coSNARK composition (coSNARK only for genuinely
distributed witnesses), and the VNET/Pedersen-vector-commitment relationship.

## Evidence (`eval-self.sh`, attested)

- present — spec + index exist; declares itself a non-enshrined application
  target with the registry-MUST-NOT-require rule.
- content — Φ_R, Pⁿ zero-account + no-numeraire, ≥10 obligations, the ABI table,
  the completeness-not-truth boundary, and composition all present.
- crossrefs — every cited spec exists; `journal_sum_field_sound` (Core.lean) and
  Annex B `fact_fold` (3/PROOF) verified.

Status: open (pre-threshold).
