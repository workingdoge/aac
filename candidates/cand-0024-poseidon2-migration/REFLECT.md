# Reflection: cand-0024-poseidon2-migration

Intent: PERF: migrate the circuits' commitment hash from pedersen_hash to a Poseidon2 sponge (vendored over std::hash::poseidon2_permutation, t=3/rate=2/cap=1, capacity initialized with input length for arity domain-separation -- AAC's own commitment hash, deterministic + collision-resistant, no external value to match). New shared circuits/hash lib; swap all 18 pedersen_hash sites across ledger(4)/rulebook(1)/transition(7)/nullify(6); event-complete + pacioli inherit/unchanged. Commitment VALUES change by design (breaks cand-0016 byte-identity -- the point); the registry fixtures/verifiers + web roots regenerate in follow-ups. Headline: pedersen ~3,586 gates/2:1-hash vs poseidon2_permutation ~75 (~48x) on the pedersen-dominated 40,511-gate transition. Witnessed: nargo test green across the workspace + measured bb gates drop.
Status at reflection: landed
Reflected at: 2026-06-13T20:15:34Z

## Scores

```json
{
  "schema": "boat.eval-self.v0",
  "candidate": "cand-0024-poseidon2-migration",
  "evaluated_at": "2026-06-13T20:15:19Z",
  "task": "migrate the circuits commitment hash from pedersen_hash to a Poseidon2 sponge (new shared hash crate over std::hash::poseidon2_permutation); swap all 18 sites across ledger/rulebook/transition/nullify; regenerate the transition/nullify/event-complete Prover.tomls; nargo test green across the workspace, all sample witnesses solve, and the transition gate count collapses from 40,511",
  "checks": {
    "logic": "pass",
    "prove": "pass"
  },
  "verdict": "pass"
  ,"provenance": {
    "harness": "eval-self.sh",
    "harness_sha256": "b5d7791e9c0e3a820a58538d7ad00f97290f3e9196dc534f9cd9eed0fb152268",
    "traces_sha256": "3f058862cd029d78cd818bc7cd0fc4a1ee9bf1fa2ef086b80125d973e0ca9e3c",
    "body_sha256": "4ede262a4b9639f3bb076f2547f203f5f508abbeeb8ba69ce657cf0c17a92ecc",
    "attestation": "fab86025be6db539ad763265b73f5306d8c65426355de1f83984f884ae1aee68"
  }
}
```

## Comparison (intended vs realized)

Assessment (agent-drafted): witness
Basis: verdict pass (top-level JSON key); evidence attested (chain over scores body, traces, harness)

Operator may override by editing this file; obstruction receipts proper
remain Tusk-recorded threshold denials per the charter.
