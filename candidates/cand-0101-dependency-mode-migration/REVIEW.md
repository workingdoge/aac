# Review: cand-0101-dependency-mode-migration

```text
ReviewJudgment:
  candidate_id: cand-0101-dependency-mode-migration
  reviewed_at: 2026-07-04T14:45:00Z
  subject:
    brief_sha256: 3dcd8212cfd5099fd924515e8f0a60912427839a207f224eddae73ccdeb81deb
    landing_tier: normal
    review_prompt_sha256: e008b3253abc769b03c9e039e3615bf04e2a1943759004d916114b11deb93bed
  reviewer:
    independence_claim: fresh-session
    write_scope_claim: REVIEW.md-only
  evidence_audit:
    eval_check: reproduced
    witness_ref: tools/eval/eval-check.sh candidates/cand-0101-dependency-mode-migration .
  findings: none
  recommendation: admit
```

```text
ReviewNote:
  candidate_id: cand-0101-dependency-mode-migration
  reviewed_at: 2026-07-04T14:45:00Z
  brief_audited: agree — the line-diff bounds match live-vs-seed comparison exactly (see below); intent is machinery-only, not a migration run.
  claims_verified:
    - claim: "seeds/flake.nix replaces flake.nix: +3/-0 lines vs live"
      evidence_path: diff /Users/arj/irai/aac/flake.nix seeds/flake.nix
      verdict: confirmed (3 additions: loop.url input, loop argument, kernelStore package output; zero deletions)
    - claim: "seeds/flake.lock replaces flake.lock: +19/-0 lines vs live"
      evidence_path: diff /Users/arj/irai/aac/flake.lock seeds/flake.lock
      verdict: confirmed (adds loop node with locked rev 932d0d40… and root inputs.loop edge; no other nodes touched)
    - claim: "seeds/migrate-to-dependency.sh is NEW at migrate-to-dependency.sh; 388 lines"
      evidence_path: seeds/migrate-to-dependency.sh (wc -l = 388); no live counterpart
      verdict: confirmed
    - claim: "Evaluator verdict: pass" (8/8 checks)
      evidence_path: scores.json + tools/eval/eval-check.sh candidates/cand-0101-dependency-mode-migration .
      verdict: reproduced byte-exact; fresh-run verdict pass rc=0; evidence restored and attestation re-verified (eb1695f53117)
    - claim: "Loop pin 932d0d408273… is ancestor of live Loop HEAD"
      evidence_path: eval-self.sh t02 executes `git -C /Users/arj/irai/loop merge-base --is-ancestor $LOOP_PIN HEAD`; passes in traces
      verdict: confirmed (t02 pass)
    - claim: "Migration preserves instance + adaptation souls, removes kernel copies, writes receipt, idempotent"
      evidence_path: traces/t03_migration.out + traces/t03_idempotent.out
      verdict: confirmed; second invocation emits "already dependency-mode; no-op"
    - claim: "Shim exports BOAT_INSTANCE_ROOT so post-migration status/validate hit the scratch instance, not the read-only store"
      evidence_path: traces/t04_status.out + traces/t04_validate.out; check `[[ ! -e "$store/candidates/$id" ]]` guards the boundary
      verdict: confirmed (t04 pass)
    - claim: "Undeclared kernel-file divergence refuses before receipt creation"
      evidence_path: traces/t05_undeclared_divergence_refused.out — "kernel store digest mismatch: WORKER.md"; t06 asserts no MIGRATION-RECEIPT.md written
      verdict: confirmed
    - claim: "Corrupted manifest row refuses before receipt creation"
      evidence_path: traces/t07_corrupted_manifest_refused.out — "malformed manifest row: bogus…"; t08 asserts no receipt
      verdict: confirmed
    - claim: "This candidate does not run the migration"
      evidence_path: README.md L18–20, LANDING (only three seeds→destinations, none of which invoke migrate-to-dependency.sh); eval runs on scratch mktemp roots
      verdict: confirmed
  concerns: none of admission-blocking severity. Observations for follow-up:
    - The Loop pin is a `file:///Users/arj/irai/loop` local path — not a publishable ref. This is called out in the flake.nix comment as a hackathon-speed pin and matches the boat "swap for a published ref" note; consistent with brief but future republication will need a real URL.
    - migrate-to-dependency.sh is post-land operator-run only; nothing in this candidate exercises it against the *live* AAC tree, only against scratch fixtures. That is the correct scope for machinery-only landing, but the actual copy→dependency cutover remains an unwitnessed act awaiting operator invocation.
  questions_asked: none — non-interactive convening.
  recommendation: admit
```
