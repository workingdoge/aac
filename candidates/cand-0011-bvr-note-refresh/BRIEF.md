# Threshold Brief: cand-0011-bvr-note-refresh

Generated: 2026-06-13T16:37:47Z
Status: validated
Intent: Refresh Design Note 0001 to fold in the user's sketch deltas: point §4/§5 to the now-landed EVENT-COMPLETE/1 application-target spec; add the coSNARK-pragmatism nuance (coSNARK only for genuinely distributed witnesses, not a universal proving mode); add the vector-commitment 'require a zero-opening proof, not inspect an arbitrary point' requirement and the fuller BVR object fields.
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=a324246e80c0202d95f4e3a4b88dc8b048e92e49a9326a4e6bccd1e76b94cba1

## Cargo (what lands if admitted)

- `cargo/sites/ledger/design/0001-bvr-clearing-kernel.md` replaces `sites/ledger/design/0001-bvr-clearing-kernel.md`: +27/-6 lines vs live

## Witnessed behavioral delta (task: Refresh Design Note 0001 — point to the landed EVENT-COMPLETE/1 spec, add the coSNARK not-a-universal-mode nuance and the vector-commitment zero-opening requirement; stays non-normative)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
