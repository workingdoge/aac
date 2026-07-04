# cand-0101-dependency-mode-migration (machine-drafted, DRAFT — pre-threshold)

```text
CycleReceipt:
  receipt_id: CR-cand-0101-dependency-mode-migration-aac-2026-06-13-0001
  cycle_id: aac-2026-06-13
  cargo: migrate this instance from kernel-by-copy to dependency-mode using the kcir pilot shape
  source: candidates/cand-0101-dependency-mode-migration/ (META, scores.json, traces/; META.candidate_id=cand-0101-dependency-mode-migration; META.cycle_id=aac-2026-06-13; LANDED.git_commit=e4b9fc3; LANDED.landed_at=2026-07-04T14:54:33Z; memory.landing=hash=a72534a5e96651fbbea48d172c318b1808d7418537d520e834368f4dbcf61d6c; snapshot=e4b9fc3; landed_at=2026-07-04T14:54:33Z)
  selected_material: seeds/flake.nix -> flake.nix; seeds/flake.lock -> flake.lock; seeds/migrate-to-dependency.sh -> migrate-to-dependency.sh
  left_behind: candidate-local record/evidence retained: candidates/cand-0101-dependency-mode-migration/META, candidates/cand-0101-dependency-mode-migration/DECLARATION, candidates/cand-0101-dependency-mode-migration/README.md, candidates/cand-0101-dependency-mode-migration/LANDING, candidates/cand-0101-dependency-mode-migration/VALIDATE.json, candidates/cand-0101-dependency-mode-migration/BRIEF.md, candidates/cand-0101-dependency-mode-migration/REVIEW.md, candidates/cand-0101-dependency-mode-migration/scores.json, candidates/cand-0101-dependency-mode-migration/traces, candidates/cand-0101-dependency-mode-migration/drafts, candidates/cand-0101-dependency-mode-migration/rollback, candidates/cand-0101-dependency-mode-migration/DECISION, candidates/cand-0101-dependency-mode-migration/DECISIONS, candidates/cand-0101-dependency-mode-migration/LANDED
  owner: agent:claude; declaration.layer=evidence-tooling; declaration.implements=premath.workspace-kernel-bundle.v0 (connection clause: aac dependency-mode base-change machinery)
  authority_surface: cycle.operating-surface.v0
  predicate: premath.seed-selection-boundary.v0
  predicate_absence_reason: none
  projection_surface: candidates/cand-0101-dependency-mode-migration/
  verification_boundary: machine refs only: VALIDATE.json=present; scores=present(provenance); REVIEW.md=present; LANDED=present; memory.landing=hash=a72534a5e96651fbbea48d172c318b1808d7418537d520e834368f4dbcf61d6c; snapshot=e4b9fc3; landed_at=2026-07-04T14:54:33Z
  shore_commitment: landed
  threshold_outcome: admit
  disposition: TODO-review
  recorder: Tusk
  receipt_ref: cycles/aac-2026-06-13/receipts/CAND-0101-DEPENDENCY-MODE-MIGRATION-2026-07-04.md
```
