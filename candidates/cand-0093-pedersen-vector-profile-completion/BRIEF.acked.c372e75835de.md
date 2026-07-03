# Threshold Brief: cand-0093-pedersen-vector-profile-completion

Generated: 2026-07-03T14:27:44Z
Status: validated
Intent: Pin the PEDERSEN-VECTOR/1 derivation encodings, basis commitment, canonical-y, and vectors (closes the cand-0092 obstruction)
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=feebb6c98bd0faef8b540a9e26c410e98caefd38b6309aaaefa5a9045adf0c3b

## Cargo (what lands if admitted)

- `seeds/sites/ledger/specs/profiles/PEDERSEN-VECTOR-1.md` replaces `sites/ledger/specs/profiles/PEDERSEN-VECTOR-1.md`: +51/-0 lines vs live
- `seeds/sites/ledger/specs/profiles/vectors/PEDERSEN-VECTOR-1.json` is NEW at `sites/ledger/specs/profiles/vectors/PEDERSEN-VECTOR-1.json`:      188 lines
- `seeds/world-app/provekit-pedersen-vector-derivation/Nargo.toml` is NEW at `world-app/provekit-pedersen-vector-derivation/Nargo.toml`:       13 lines
- `seeds/world-app/provekit-pedersen-vector-derivation/render-vector.mjs` is NEW at `world-app/provekit-pedersen-vector-derivation/render-vector.mjs`:      121 lines
- `seeds/world-app/provekit-pedersen-vector-derivation/src/main.nr` is NEW at `world-app/provekit-pedersen-vector-derivation/src/main.nr`:      140 lines
- `seeds/candidates/QUEUE.md` replaces `candidates/QUEUE.md`: +3/-1 lines vs live

## Witnessed behavioral delta (task: Complete PEDERSEN-VECTOR/1 generator-pinning profile: field_of encoding, basis commitment, canonical y, beta.19 Noir-generated vectors, honesty boundary, and cand-0092 queue resolution.)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
