# Reflection: cand-0022-world-stack-strategy

Intent: Land Design Note 0002 (non-normative): the World stack (World ID / Mini Apps / World Chain) + AgentKit + ProveKit strategy for AAC -- a human-backed clearing copilot Mini App where proof-of-human gates scarce access (free proof-gen, quote/matching trials, financing/settlement slots), an AgentKit x402 gateway meters per-human, ProveKit generates a narrow client-side receipt proof (a right-sized EVENT-COMPLETE/1 BVR), and human-in-the-loop binds irreversible actions (receipt:<nullifier>, settlement:<batch>) to a World ID approval. Flags the toolchain constraint: ProveKit pins Noir v1.0.0-beta.11 vs AAC's beta.14 -- isolate a separate ProveKit circuit, do not migrate the workspace. + a QUEUE roadmap entry pointing to it.
Status at reflection: landed
Reflected at: 2026-06-13T19:37:43Z

## Scores

```json
{
  "schema": "boat.eval-self.v0",
  "candidate": "cand-0022-world-stack-strategy",
  "evaluated_at": "2026-06-13T19:37:25Z",
  "task": "land non-normative Design Note 0002 (World stack + AgentKit + ProveKit strategy for AAC), fact-checked against a 2026-06-13 deep-research pass: a human-backed clearing copilot Mini App; carries the verified corrections (ProveKit pins Noir beta.19 not beta.11; AgentBook resolves on World Chain eip155:480, the Base-mainnet relay claim refuted; ProveKit default hash Skyscraper; v4 verify endpoint; HITL requestHumanAuthorization; World Chain PBH; perf numbers marked unverified); cross-references resolve",
  "checks": {
    "structure": "pass",
    "corrections": "pass",
    "xrefs": "pass"
  },
  "verdict": "pass"
  ,"provenance": {
    "harness": "eval-self.sh",
    "harness_sha256": "3b37729bba98d1efe1ee0e6656861a60d073c7abfdb23834aa0889528af3b978",
    "traces_sha256": "a5d6e1117c09f38f3c8ba6317f463ff7d2aa176ad27fe819fbe139c5572f2ab3",
    "body_sha256": "acbd9f974a4a3042334e0ac009e3de1132a10419f67056b37253665561658101",
    "attestation": "a2c6b1c7c60fef1415e5db85bfc90cc36f5fcbcb9f909c3557a4d20f5699571e"
  }
}
```

## Comparison (intended vs realized)

Assessment (agent-drafted): witness
Basis: verdict pass (top-level JSON key); evidence attested (chain over scores body, traces, harness)

Operator may override by editing this file; obstruction receipts proper
remain Tusk-recorded threshold denials per the charter.
