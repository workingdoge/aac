# Threshold Brief: cand-0009-pn-conformance

Generated: 2026-06-13T16:28:44Z
Status: validated
Intent: P^n conformance vectors in circuits/pacioli (Design Note 0001 §11.2; advances 1/PACI Raw->Draft 'executable conformance for every MUST'): a multi-dimensional buyer/supplier event over basis [USD,fabric,garment] is accepted as a vector zero-account, and a 'dollars balance but fabric vanishes' journal is rejected — the incommensurability thesis baked into the shipped test suite.
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=a324246e80c0202d95f4e3a4b88dc8b048e92e49a9326a4e6bccd1e76b94cba1

## Cargo (what lands if admitted)

- `cargo/circuits/pacioli/src/lib.nr` replaces `circuits/pacioli/src/lib.nr`: +29/-0 lines vs live

## Witnessed behavioral delta (task: P^n conformance vectors in pacioli: a multi-dimensional vector event is accepted as a zero-account; a numeraire-collapse journal (dollars net, fabric vanishes) is rejected. nargo test green.)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
