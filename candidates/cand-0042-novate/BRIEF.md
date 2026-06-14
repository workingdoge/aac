# Threshold Brief: cand-0042-novate

Generated: 2026-06-14T06:23:25Z
Status: validated
Intent: Build NOVATE/1 -- promote Design Note 0004 S3 to an application-target spec + a circuits/novate proof: central-counterparty novation. The whole relation collapses to ONE vector equation over the (account x dimension) grid: net(J_AC) + net(J_CB) == net(J_AB); the bilateral never touches the CCP's accounts, so on C's slice the equation reads net(J_AC)[C]+net(J_CB)[C]==0 -- the CCP is FLAT (the matched book). Conservation (A,B economics preserved) and CCP-flat (C slice vanishes) are the SAME equation read on different accounts; CCP-flat is a THEOREM of balanced faithful interposition, not an extra assumption. New app lib circuits/novate (net_grid + novate + canonical compile_bilateral/compile_novation_legs over a fixed 6-account {A,B,C}x{asset,cash} chart, generic in basis B); new bin circuits/event-novate witnesses a trade, recomputes the three journal_commitments, binds them to the public ABI, and discharges novate. NOVATE-1.md (Raw, application target, cites 1/PACI 3/PROOF 4/REG, policy-gated never base 4/REG S5, NO new domain tag -- it is a balanced decomposition over existing journal leaves). App-side: kernel boundary law holds. Multilateral net of many legs = VNET/1 (operator) + NET/1; out of scope, no VNET files touched. Witnessed: nargo test --workspace green (novate 5/5 incl. tampered-leg / unbalanced-leg / non-bilateral rejects + event_novate 4/4 + existing crates value-preserving), event_novate witness solves, kernel-boundary-check clean, NOVATE-1.md carries the obligations + ABI + the matched-book theorem, applications/README indexes it.
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=a324246e80c0202d95f4e3a4b88dc8b048e92e49a9326a4e6bccd1e76b94cba1

## Cargo (what lands if admitted)

- `cargo/circuits/Nargo.toml` replaces `circuits/Nargo.toml`: +1/-1 lines vs live
- `cargo/circuits/novate/Nargo.toml` is NEW at `circuits/novate/Nargo.toml`:        8 lines
- `cargo/circuits/novate/src/lib.nr` is NEW at `circuits/novate/src/lib.nr`:      187 lines
- `cargo/circuits/event-novate/Nargo.toml` is NEW at `circuits/event-novate/Nargo.toml`:        8 lines
- `cargo/circuits/event-novate/src/main.nr` is NEW at `circuits/event-novate/src/main.nr`:       79 lines
- `cargo/circuits/event-novate/Prover.toml` is NEW at `circuits/event-novate/Prover.toml`:        7 lines
- `cargo/sites/ledger/specs/applications/NOVATE-1.md` is NEW at `sites/ledger/specs/applications/NOVATE-1.md`:      129 lines
- `cargo/sites/ledger/specs/applications/README.md` replaces `sites/ledger/specs/applications/README.md`: +1/-0 lines vs live
- `cargo/sites/ledger/design/0004-clearing-novation-ccp.md` replaces `sites/ledger/design/0004-clearing-novation-ccp.md`: +8/-7 lines vs live

## Witnessed behavioral delta (task: Build NOVATE/1: promote Design Note 0004 S3 to an application-target spec (NOVATE-1.md, Raw, cites 1/PACI 3/PROOF 4/REG, policy-gated never base, no new domain tag) + a circuits/novate proof of central-counterparty novation. The obligation is one vector equation net(J_AC)+net(J_CB)==net(J_AB) over the account x dim grid; the bilateral never touches C so on C the equation is net(J_AC)[C]+net(J_CB)[C]==0 -- the CCP is flat (matched book), a theorem of balanced faithful interposition. circuits/novate = net_grid + novate + canonical compile; circuits/event-novate binds the three journal_commitments and discharges novate. App-side; multilateral net of many legs = VNET/1 (operator), out of scope, no VNET files touched. Witnessed: structural; nargo test --workspace green (novate 5/5 incl. tampered/unbalanced/non-bilateral rejects + event_novate 4/4); event_novate witness solves; existing crates value-preserving; the cand-0033 boundary law still passes; NOVATE-1.md carries the obligations + ABI + the matched-book theorem; README indexes it; DN0004 references it.)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
