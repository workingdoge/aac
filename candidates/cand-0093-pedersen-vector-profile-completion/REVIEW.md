```text
ReviewJudgment:
  candidate_id: cand-0093-pedersen-vector-profile-completion
  reviewed_at: 2026-07-03T14:55:00Z
  subject:
    brief_sha256: c372e75835deca65c55b7dfcad2f62c4ba3da0ae465f6c2ade65cc1f6b78283c
    landing_tier: normal
    review_prompt_sha256: 996317feb6ed77334f1c38e291a24c45d6b37769c0222e8c3fa7f3b9e8352735
  reviewer:
    independence_claim: fresh-session
    write_scope_claim: REVIEW.md-only
  evidence_audit:
    eval_check: reproduced
    witness_ref: "bash tools/eval/eval-check.sh candidates/cand-0093-pedersen-vector-profile-completion . -> attest verified 5d9d13d1865c, evidence restored byte-exact, fresh-run rc=0 pass"
  findings: none
  recommendation: admit
```

```text
ReviewNote:
  candidate_id: cand-0093-pedersen-vector-profile-completion
  reviewed_at: 2026-07-03T14:55:00Z
  brief_audited: agree — the +51/-0 line delta in the spec, the new vector JSON, the new beta.19 harness under world-app/, and the QUEUE.md +3/-1 move exactly match what is in seeds/; the eval verdict pass is reproduced end-to-end by eval-check.sh.
  claims_verified:
    - "Additive-only spec amendment (§1 table params, §2 field_of/basis_commitment/canonical-y, §7 vector reference block) -> diff sites/ledger/specs/profiles/PEDERSEN-VECTOR-1.md against seed shows only additions; no line removed -> verified"
    - "Prescribed seed formula 'seed(label, j) = Poseidon2( \"aac/vnet/1\", profile_id, basis_commitment, basis_type_id_j, label, j )' unchanged -> seed line preserved byte-identically at seed line 55 vs live line 53 -> verified"
    - "§8 target identity text and lowercase profile_id 'pedersen-vector/1' unchanged -> the two paragraphs at seed lines 216-220 vs live lines 165-169 are byte-identical -> verified"
    - "field_of encoding fully pins string derivations (UTF-8 BE, <=31-byte fail-closed, no reduction) and enumerates every string arg reachable from the seed formula (domain tag, aac/vnet/1/basis, labels G/H, profile_id, basis_type_id_j) -> seeds/…/PEDERSEN-VECTOR-1.md §2 lines 67-78 -> verified"
    - "Integers j, ctr, n are used as field elements directly (no hidden encoding) -> §2 line 78 -> verified"
    - "basis_commitment binds ordered basis with explicit n; production 2/FACT swap changes target identity -> §2 lines 80-92 -> verified; mutant that drops n is rejected by t02 probe (traces/t02-basis-commitment.out)"
    - "Canonical-y rule pinned (first-QR ctr; even square root of rhs; if odd LSB use p-y) -> §2 lines 95-98 -> verified; matches main.nr's y.to_le_bits()[0] == 0 check on the canonical integer rep in [0,p-1] (odd p makes even/odd unambiguous)"
    - "field_of computations reproduce independently in Python (aac/vnet/1 -> 459866030074855593094961; aac/vnet/1/basis -> 129440780105341809738746541662016858483; pedersen-vector/1 -> 38246398409996331787205124593264425578289; G -> 71; H -> 72; USD -> 5591876; fabric -> 112568449526115; shares -> 126892148680051; -17 mod p -> 21888242871839275222246405745257275088548364400416034343698204186575808495600) and match the vector JSON, the spec examples, and the main.nr constants -> verified"
    - "Vector regenerates byte-identically through the beta.19 Noir harness; corrupt-mutant on accepted_ctr rejected -> t06-vectors-regenerate probe returns 46; corroborated by eval-check.sh reproducing attestation 5d9d13d1865c and re-attesting df262eacd1cb from a fresh run"
    - "Try-and-increment sanity: G_1 (fabric) accepts at ctr=3 with three rejected priors (Legendre = -1), G_2 (shares) accepts at ctr=2 with two rejected priors, H and G_0 accept at ctr=0 -> distribution consistent with ~1/2 acceptance probability per ctr; each rejected prior x is included in the vector and reproduced by the harness -> verified"
    - "Honesty clause is stated, not hedged, in both spec §7 lines 195-198 and vectors/PEDERSEN-VECTOR-1.json notes[] -> 'same implementation family as the ProveKit VNET circuit', 'not yet an independent Poseidon2 implementation cross-check', 'independent Python Poseidon2 cross-check is queued as follow-up work' -> verified"
    - "Independent Python cross-check is queued as an [open] entry (not hedged away) -> seeds/candidates/QUEUE.md line 48 explicitly requires 'an implementation-family cross-check, not a second wrapper around Noir output' -> verified"
    - "Queue formation: exactly one Open/Resolved header pair; cand-0092 obstruction closed as [resolved cand-0093-...]; duplicate-header mutant rejected -> t08-queue-formation probe returns 48 -> verified"
    - "Temp-HOME nargo workaround (HOME=$WORK/nargo-home) is a hermetic cache/config isolation for the .#nargo19 binary in the restricted worker sandbox, not a broken-toolchain mask -> eval-self.sh calls nargo --version, nargo test --show-output, and nargo execute against a fresh $WORK dir; harness is standalone (Nargo.toml has no path/git deps) and uses only std::hash::poseidon2_permutation -> verified"
    - "Eval-check.sh re-attests to the same attestation 5d9d13d1865c after snapshot/restore, then reproduces pass from a fresh run (new body_sha256/attestation, matching verdict) -> verified"
  concerns: none
  questions_asked:
    - "Is the derivation fully deterministic (no place a second implementer could encode differently)? -> Yes. Every string argument to the seed and basis_commitment hashes is enumerated in the field_of rule (§2), including domain tags and every basis_type_id_j; integers j, ctr, n are stated to be used as field elements directly; the <=31-byte fail-closed bound ensures the resulting integer stays well below p (2^248 < p ≈ 2^254) so 'no reduction' is well-defined. The Poseidon2 sponge shape is pinned in the vector's toolchain.hash field ('width 4/rate 3 sponge with message length in the capacity lane') and the same shape is realized in main.nr's hash() function."
    - "Is the <=31-byte bound stated wherever a string arg appears? -> Yes. §2 names it once for the derivation and enumerates every string input covered; §7's basis_type_ids ('USD', 'fabric', 'shares') and the profile_id ('pedersen-vector/1') all satisfy it in the shipped vector."
    - "Is the even-y rule unambiguous (LSB of what representation)? -> Effectively yes. The spec says 'the even square root; if odd LSB use p - y'. In the Grumpkin base field p is prime (odd), so of the two square roots {y, p - y} exactly one has even canonical integer representation, and main.nr's y.to_le_bits()[0] == 0 pins that to the canonical integer in [0, p-1]. Making 'LSB of the canonical integer representation of y in [0, p-1]' explicit would be a purely cosmetic clarification and does not affect determinism given the assertion in the harness."
    - "Does the seed still bind everything §2 requires (profile_id, basis_commitment, basis_type_id_j, label, j)? -> Yes; the seed formula text is byte-identical to the previously-prescribed version, and the amendment only pins what was underdetermined (how to encode strings, how basis_commitment is computed, how canonical y is chosen)."
    - "Is the honesty clause stated same-implementation-family (not hedged)? -> Yes; and the queued independent Python Poseidon2 cross-check is filed as an [open] entry, not merely noted."
    - "Is the temp-HOME workaround hermetic-honest? -> Yes; it isolates nargo's config cache into $WORK/nargo-home so the beta.19 binary runs cleanly in the restricted sandbox. It does not point to a stubbed toolchain: eval-self.sh resolves nargo19 from NARGO19_BIN or $ROOT/result/bin/nargo or the pinned /nix/store path, and the eval runs nargo --version, nargo test --show-output (harness self-asserts x/curve/even-y for all four generators), and nargo execute before rendering."
  recommendation: admit
```
