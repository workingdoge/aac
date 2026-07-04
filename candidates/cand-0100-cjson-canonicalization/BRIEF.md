# Threshold Brief: cand-0100-cjson-canonicalization

Generated: 2026-07-04T00:28:42Z
Status: validated
Intent: 2/FACT completion: pin cjson/1 canonical bytes + author TypeDecl documents (closes the cand-0099 obstruction)
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=feebb6c98bd0faef8b540a9e26c410e98caefd38b6309aaaefa5a9045adf0c3b

## Cargo (what lands if admitted)

- `seeds/sites/ledger/specs/2/README.md` replaces `sites/ledger/specs/2/README.md`: +14/-0 lines vs live
- `seeds/sites/ledger/specs/2/reference/cjson1_encode.py` is NEW at `sites/ledger/specs/2/reference/cjson1_encode.py`:      195 lines
- `seeds/sites/ledger/specs/2/type-declarations/cjson-1.json` is NEW at `sites/ledger/specs/2/type-declarations/cjson-1.json`:       23 lines
- `seeds/sites/ledger/specs/2/type-declarations/sha256-1.json` is NEW at `sites/ledger/specs/2/type-declarations/sha256-1.json`:       13 lines
- `seeds/sites/ledger/specs/2/type-declarations/d2f-31be-1.json` is NEW at `sites/ledger/specs/2/type-declarations/d2f-31be-1.json`:       12 lines
- `seeds/sites/ledger/specs/2/type-declarations/uh-bn254-1.json` is NEW at `sites/ledger/specs/2/type-declarations/uh-bn254-1.json`:       12 lines
- `seeds/sites/ledger/specs/2/type-declarations/name-ens-1.json` is NEW at `sites/ledger/specs/2/type-declarations/name-ens-1.json`:       14 lines
- `seeds/sites/ledger/specs/2/type-declarations/data-walrus-1.json` is NEW at `sites/ledger/specs/2/type-declarations/data-walrus-1.json`:       13 lines
- `seeds/sites/ledger/specs/2/vectors/cjson1-escape.json` is NEW at `sites/ledger/specs/2/vectors/cjson1-escape.json`:      246 lines
- `seeds/sites/ledger/specs/2/vectors/cjson1-key-order.json` is NEW at `sites/ledger/specs/2/vectors/cjson1-key-order.json`:       21 lines
- `seeds/sites/ledger/specs/2/vectors/cjson1-integers.json` is NEW at `sites/ledger/specs/2/vectors/cjson1-integers.json`:       32 lines
- `seeds/sites/ledger/specs/2/vectors/typedecl-typeids.json` is NEW at `sites/ledger/specs/2/vectors/typedecl-typeids.json`:       54 lines
- `seeds/sites/ledger/specs/registers/R1.md` replaces `sites/ledger/specs/registers/R1.md`: +14/-7 lines vs live
- `seeds/candidates/QUEUE.md` queue-merges `candidates/QUEUE.md`: +2/-3 lines vs QUEUE.base

## Witnessed behavioral delta (task: Complete cjson/1 canonical bytes, TypeDecl documents, R1 typeIds, vectors, and cand-0099 queue resolution.)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
