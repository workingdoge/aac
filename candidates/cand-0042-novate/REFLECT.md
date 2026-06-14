# Reflection: cand-0042-novate

Intent: Build NOVATE/1 -- promote Design Note 0004 S3 to an application-target spec + a circuits/novate proof: central-counterparty novation. The whole relation collapses to ONE vector equation over the (account x dimension) grid: net(J_AC) + net(J_CB) == net(J_AB); the bilateral never touches the CCP's accounts, so on C's slice the equation reads net(J_AC)[C]+net(J_CB)[C]==0 -- the CCP is FLAT (the matched book). Conservation (A,B economics preserved) and CCP-flat (C slice vanishes) are the SAME equation read on different accounts; CCP-flat is a THEOREM of balanced faithful interposition, not an extra assumption. New app lib circuits/novate (net_grid + novate + canonical compile_bilateral/compile_novation_legs over a fixed 6-account {A,B,C}x{asset,cash} chart, generic in basis B); new bin circuits/event-novate witnesses a trade, recomputes the three journal_commitments, binds them to the public ABI, and discharges novate. NOVATE-1.md (Raw, application target, cites 1/PACI 3/PROOF 4/REG, policy-gated never base 4/REG S5, NO new domain tag -- it is a balanced decomposition over existing journal leaves). App-side: kernel boundary law holds. Multilateral net of many legs = VNET/1 (operator) + NET/1; out of scope, no VNET files touched. Witnessed: nargo test --workspace green (novate 5/5 incl. tampered-leg / unbalanced-leg / non-bilateral rejects + event_novate 4/4 + existing crates value-preserving), event_novate witness solves, kernel-boundary-check clean, NOVATE-1.md carries the obligations + ABI + the matched-book theorem, applications/README indexes it.
Status at reflection: landed
Reflected at: 2026-06-14T06:23:26Z

## Scores

```json
{
  "schema": "boat.eval-self.v0",
  "candidate": "cand-0042-novate",
  "evaluated_at": "2026-06-14T06:23:13Z",
  "task": "Build NOVATE/1: promote Design Note 0004 S3 to an application-target spec (NOVATE-1.md, Raw, cites 1/PACI 3/PROOF 4/REG, policy-gated never base, no new domain tag) + a circuits/novate proof of central-counterparty novation. The obligation is one vector equation net(J_AC)+net(J_CB)==net(J_AB) over the account x dim grid; the bilateral never touches C so on C the equation is net(J_AC)[C]+net(J_CB)[C]==0 -- the CCP is flat (matched book), a theorem of balanced faithful interposition. circuits/novate = net_grid + novate + canonical compile; circuits/event-novate binds the three journal_commitments and discharges novate. App-side; multilateral net of many legs = VNET/1 (operator), out of scope, no VNET files touched. Witnessed: structural; nargo test --workspace green (novate 5/5 incl. tampered/unbalanced/non-bilateral rejects + event_novate 4/4); event_novate witness solves; existing crates value-preserving; the cand-0033 boundary law still passes; NOVATE-1.md carries the obligations + ABI + the matched-book theorem; README indexes it; DN0004 references it.",
  "checks": {
    "logic": "pass",
    "prove": "pass",
    "boundary": "pass",
    "spec": "pass"
  },
  "verdict": "pass"
  ,"provenance": {
    "harness": "eval-self.sh",
    "harness_sha256": "991af8980fb79dd767124d0adf5013b41b102eec849be96fd13f4f99f42fc3f7",
    "traces_sha256": "d5b9005fce4017ebcc1dfad580e81be9a22934122b09a1437c2c7a2ce7e4a043",
    "body_sha256": "c7406cfd270d04a9e70b0a333f3acfb7f036e63c13545755711c255a26a68d0e",
    "attestation": "a766a49d641f6564525f66155363eb62bc86bcd1a031371016a7d996beeab22d"
  }
}
```

## Comparison (intended vs realized)

Assessment (agent-drafted): witness
Basis: verdict pass (top-level JSON key); evidence attested (chain over scores body, traces, harness)

Operator may override by editing this file; obstruction receipts proper
remain Tusk-recorded threshold denials per the charter.
