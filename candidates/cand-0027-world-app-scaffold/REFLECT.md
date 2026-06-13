# Reflection: cand-0027-world-app-scaffold

Intent: Land the World-stack MVP scaffold (Design Note 0002) onto main as a clearly-labeled prototype: world-app/ = a MiniKit Mini App (walletAuth + World ID uniqueness -> one-per-human starter credits + AgentBook + client-side ProveKit proof + HITL approval) + an AgentKit x402 gateway (per-human SHARED counter, free/free-trial/discount, persistent-storage interface, replay nonces) + a beta.19 ProveKit receipt circuit (a right-sized EVENT-COMPLETE/1 BVR). Reviewed by a 4-lens adversarial panel (no critical/soundness findings; honest stubs). Applies 4 pre-landing fixes: (1) add the numeraire-collapse rejection test to the provekit circuit; (2) production guard on the dev-only in-memory gateway storage; (3) a .env.example; (4) make the provekit server-fallback party-ID-leak caveat loud. External SDKs are stubbed (verify-at-integration); the beta.19 circuit does not compile in this beta.14 env (documented).
Status at reflection: landed
Reflected at: 2026-06-13T20:50:47Z

## Scores

```json
{
  "schema": "boat.eval-self.v0",
  "candidate": "cand-0027-world-app-scaffold",
  "evaluated_at": "2026-06-13T20:50:34Z",
  "task": "land the World-stack MVP scaffold (Design Note 0002) onto main as a labeled prototype after a 4-lens review + 5 fixes (numeraire-collapse test, in-memory storage production guard, .env.example, opt-in+loud server-fallback, ASCII circuit); honest stubs + caveats; node_modules uncommitted; the Pn no-numeraire-collapse property executes green on beta.14",
  "checks": {
    "fixes": "pass",
    "honesty": "pass",
    "circuit": "pass"
  },
  "verdict": "pass"
  ,"provenance": {
    "harness": "eval-self.sh",
    "harness_sha256": "b26a1d7a1609df685fffef8dd51ca2c69b292c634b4b8038fd146b62186f6401",
    "traces_sha256": "81a618cb13fc8e9a29297e78cc205c0bbeac005a50af633d0f70a6e8bdfc9059",
    "body_sha256": "9e4fcdfd2b819a8d953f8f6ce3f868381209b9f266e7ff2ef1ce6e177e33a5ae",
    "attestation": "86fe1f4e67668a438d1ec74852fe6cb02701b714805d17bcf346224e3c74fe3b"
  }
}
```

## Comparison (intended vs realized)

Assessment (agent-drafted): witness
Basis: verdict pass (top-level JSON key); evidence attested (chain over scores body, traces, harness)

Operator may override by editing this file; obstruction receipts proper
remain Tusk-recorded threshold denials per the charter.
