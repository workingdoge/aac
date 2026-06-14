# Threshold Brief: cand-0041-clearing-novation-note

Generated: 2026-06-14T06:04:58Z
Status: validated
Intent: Land Design Note 0004 (non-normative): AAC as a privacy-preserving CCP -- map FICC/DTCC clearing onto the existing primitive stack and model the one missing piece, NOVATION. Thesis: the spec stack IS a clearing-house decomposition because vector Pacioli's Pⁿ zero-account is the CCP conservation guaranty; netting preserves it; VNET/1 makes the net provable without revealing the gross. Novation modeled as a conservation-preserving DECOMPOSITION: a bilateral balanced journal J_AB becomes two CCP-legs J_AC + J_CB that sum back to J_AB and leave the CCP FLAT per trade (matched book at the unit) -- a NOVATE/1 application target (policy-gated, never base, 4/REG S5), NOT kernel. The closure: a CCP is a participant whose matched book the registry forces to balance; novation interposes; netting (NET/1 + VNET/1) is the private multilateral compression. Honest non-goals: risk/margin/default-waterfall, fails/CNS carry, legal novation, no instantiation. Plus a house-style flow->primitive diagram (0004-clearing-flow.html). Coordinates WITH VNET (the multilateral net is the operator's VNET work); touches no VNET files. Witnessed: the note carries the thesis + the novation decomposition + the application-layer placement + the non-goals + the non-normative marker, every referenced artifact resolves, the README indexes 0004, the diagram carries the stage+primitive labels, and a mutant stripped of the decomposition claim is caught.
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=a324246e80c0202d95f4e3a4b88dc8b048e92e49a9326a4e6bccd1e76b94cba1

## Cargo (what lands if admitted)

- `cargo/sites/ledger/design/0004-clearing-novation-ccp.md` is NEW at `sites/ledger/design/0004-clearing-novation-ccp.md`:      182 lines
- `cargo/sites/ledger/design/0004-clearing-flow.html` is NEW at `sites/ledger/design/0004-clearing-flow.html`:      208 lines
- `cargo/sites/ledger/design/README.md` replaces `sites/ledger/design/README.md`: +1/-0 lines vs live

## Witnessed behavioral delta (task: land Design Note 0004 (non-normative) + its house-style flow diagram: AAC as a privacy-preserving CCP. Maps FICC/DTCC clearing onto the primitive stack (EVENT/1 capture, NET/1 + VNET/1 netting, TRANSITION/1 DVP, 12/OTC margin) and models the missing piece -- NOVATION -- as a conservation-preserving decomposition (J_AB -> J_AC + J_CB summing back, CCP left flat per trade), a NOVATE/1 application target (policy-gated, never base, 4/REG §5; NOT kernel). The closure: a CCP is a participant whose matched book the registry forces to balance. Honest non-goals: risk/margin/default-waterfall, fails/CNS carry, legal novation, no instantiation. Coordinates with VNET (the multilateral net is the operator work); touches no VNET files. Witnessed: the note carries the thesis + novation decomposition + application-layer placement + non-goals + non-normative marker; every referenced artifact resolves; README indexes 0004 + the diagram; the diagram carries the stage + primitive labels; a mutant stripped of the decomposition claim is caught.)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
