# Threshold Brief: cand-0022-world-stack-strategy

Generated: 2026-06-13T19:37:34Z
Status: validated
Intent: Land Design Note 0002 (non-normative): the World stack (World ID / Mini Apps / World Chain) + AgentKit + ProveKit strategy for AAC -- a human-backed clearing copilot Mini App where proof-of-human gates scarce access (free proof-gen, quote/matching trials, financing/settlement slots), an AgentKit x402 gateway meters per-human, ProveKit generates a narrow client-side receipt proof (a right-sized EVENT-COMPLETE/1 BVR), and human-in-the-loop binds irreversible actions (receipt:<nullifier>, settlement:<batch>) to a World ID approval. Flags the toolchain constraint: ProveKit pins Noir v1.0.0-beta.11 vs AAC's beta.14 -- isolate a separate ProveKit circuit, do not migrate the workspace. + a QUEUE roadmap entry pointing to it.
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=a324246e80c0202d95f4e3a4b88dc8b048e92e49a9326a4e6bccd1e76b94cba1

## Cargo (what lands if admitted)

- `cargo/sites/ledger/design/0002-world-stack-agentkit-provekit.md` is NEW at `sites/ledger/design/0002-world-stack-agentkit-provekit.md`: 303 lines
- `cargo/sites/ledger/design/README.md` replaces `sites/ledger/design/README.md`: +1/-0 lines vs live

## Witnessed behavioral delta (task: land non-normative Design Note 0002 (World stack + AgentKit + ProveKit strategy for AAC), fact-checked against a 2026-06-13 deep-research pass: a human-backed clearing copilot Mini App; carries the verified corrections (ProveKit pins Noir beta.19 not beta.11; AgentBook resolves on World Chain eip155:480, the Base-mainnet relay claim refuted; ProveKit default hash Skyscraper; v4 verify endpoint; HITL requestHumanAuthorization; World Chain PBH; perf numbers marked unverified); cross-references resolve)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
