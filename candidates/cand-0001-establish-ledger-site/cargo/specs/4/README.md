# 4/REG — The Root Registry

- Name: 4/REG · Status: Raw · Editor: Arjun Velagapudi <arjun@aac.sh>
- License: GPL-3.0-or-later. RFC 2119 applies. Cites: 1/PACI, 2/FACT, 3/PROOF, 6/NAME.

The registry is the system's only shared infrastructure. It holds books,
not funds: its state is commitments, its update rule is proof, and its
refusals are the entire trust model. It has no sequencer (rows are
self-sequenced), no bridge (no assets), no forced-inclusion machinery
(inherited from the host chain), and no DA committee (books are
self-custodied per 7/DATA). Each absence is structural, not deferred.

## 1. State

```
Row := {
  account_root:    scalar     # carrier scalar of the row's profile
  nullifier_root:  scalar
  fact_fold:       scalar     # 3/PROOF Annex B, chained across updates
  fact_count:      uint
  context:         scalar     # deployment/profile commitment
  version:         uint       # accepted target version for this row
  nonce:           uint       # update counter
}
registry : namehash → Row     # namehash per 6/NAME
epochs   : uint → { fold_begin, fold_end, balanced }   # per 5/NET
targets  : targetId → { circuit_hash, vk_hash, verifier, profileId }
           # targetId per 3/PROOF §2; handles resolve via the Register
```

## 2. Update rule

`update(namehash, version, proof, publicInputs)` MUST:
1. Authorize the caller for `namehash` (6/NAME owner or a key it has
   delegated on-registry).
2. Resolve `targets[targetId]` for the claimed TRANSITION target;
   reject unknown targets.
3. Discharge the verifier contract of 3/PROOF §5 in full, with the pinned
   context being this row: `prev_account_root`, `prev_nullifier_root`
   MUST equal storage; `context_commitment` MUST equal `row.context`.
4. Atomically: write next roots; set
   `fact_fold := chain(fact_fold, publicInputs.fact_fold)`,
   `fact_count += publicInputs.fact_count`; increment `nonce`; emit
   `Updated(namehash, nonce, next_account_root, next_nullifier_root,
   fact_fold)`.

Old-root equality (step 3) is the concurrency rule: each row is its own
sequencer; a stale update fails harmlessly and is resubmitted against the
new roots.

## 2a. Batched updates (reserved alongside TRANSITION-AGG/1)

`batchUpdate(version, aggProof, aggPublicInputs, children[])`, where each
child is `(namehash, childPublicInputs, ownerAuth)`, MUST:

1. Resolve `targets[targetId]` for the claimed TRANSITION-AGG target;
   discharge the verifier
   contract for `aggProof`, recomputing `children_commitment` over the
   supplied child tuples and checking `transition_vk_hash` against the
   pinned TRANSITION/1 instance.
2. Per child, in order: verify `ownerAuth` — a signature by the row's
   authorized key (6/NAME owner or on-registry delegate) over a
   domain-separated digest binding (system identifier, registry
   identifier, namehash, row nonce, childPublicInputs), under an
   authorization scheme registered in the deployment profile. The caller (aggregator) holds no
   authority; authority travels with the child.
3. Per child: apply §2 steps 3–4 against that row. On old-root or nonce
   mismatch, skip the child and emit `Stale(namehash)`; a stale child
   MUST NOT invalidate its siblings.
4. Emit per-child `Updated` events exactly as in §2.

The aggregator role is permissionless and untrusted: it can batch and it
can omit, it cannot forge, reorder a row against its nonce, or touch a
row without its owner's signed authorization. Aggregator compensation is
a deployment concern outside this specification.

## 3. Reads

`get(namehash) → Row` and the `Updated` event stream are the system's
read surface; 6/NAME text records point here, never the reverse.

## 4. Target governance

`registerTarget(targetDecl, circuit_hash, vk_hash, verifier)`
is the system's actual upgrade power: whoever holds it decides what
proofs mean. It MUST be held by an explicit governance address (multisig
or better) from first deployment, MUST be event-logged, and MUST be
append-only — a registered targetId is immutable; mistakes are
superseded by new versions, never edited. Rows opt into versions; a row
MUST NOT be migrated by anyone but its own authorized updater.

## 5. Security considerations

- The registry verifies consistency, not truth (2/FACT §8): a row's roots
  commit to whatever its owner proved, no more.
- Authorization compromise = row compromise, bounded to that row.
- Target-governance compromise = system compromise; see §4.
- Censorship resistance equals the host chain's; deployments SHOULD state
  the host explicitly in `context`.

## Annex C (informative) — Cost model

Verification cost under the primary profile is dominated by a
near-constant per proof, not by circuit size; measured figures live in
the Deployment Register (R1) and SHOULD be re-measured per deployment.
Three consequences are load-bearing regardless of the constant's value:
(1) registry touches are *checkpoints*, never per-payment events — 8/SESS
keeps micros off-chain by design, so payment throughput is independent of
this constant; (2) §2a amortizes one verification and one proof across N
rows (per-row calldata shrinks to the child tuple and signature), which
is the intended scaling lever; (3) the wrapper profile (3/PROOF §1) caps settlement at a smaller
constant per batch for deployments requiring direct base-layer finality —
a premium tier, not a default. NET/1 runs once per epoch and needs none
of this. The normative design goal is that the verification constant is
amortized, not assumed small.



