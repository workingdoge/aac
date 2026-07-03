# Threshold Brief: cand-0096-python-poseidon-crosscheck

Generated: 2026-07-03T17:35:03Z
Status: validated
Intent: Independent Python Poseidon2 cross-check of the PEDERSEN-VECTOR/1 derivation vectors
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=feebb6c98bd0faef8b540a9e26c410e98caefd38b6309aaaefa5a9045adf0c3b

## Cargo (what lands if admitted)

- `seeds/sites/ledger/specs/profiles/reference/pedersen_vector_1.py` is NEW at `sites/ledger/specs/profiles/reference/pedersen_vector_1.py`:      738 lines
- `seeds/sites/ledger/specs/profiles/PEDERSEN-VECTOR-1.md` replaces `sites/ledger/specs/profiles/PEDERSEN-VECTOR-1.md`: +8/-3 lines vs live
- `seeds/sites/ledger/specs/profiles/vectors/PEDERSEN-VECTOR-1.json` replaces `sites/ledger/specs/profiles/vectors/PEDERSEN-VECTOR-1.json`: +2/-2 lines vs live
- `seeds/candidates/QUEUE.md` replaces `candidates/QUEUE.md`: +2/-2 lines vs live

## Witnessed behavioral delta (task: cand-0096 independent Python Poseidon2 cross-check for PEDERSEN-VECTOR/1)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
