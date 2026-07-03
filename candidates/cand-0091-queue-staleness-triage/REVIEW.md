```
ReviewJudgment:
  candidate_id: cand-0091-queue-staleness-triage
  reviewed_at: 2026-07-03T14:05:00Z
  subject:
    brief_sha256: b12b43df1679af6bfcc5dc017bd240db7cdba779c0891cc4404d614a40185546
    landing_tier: normal
    review_prompt_sha256: 1fc886bd020353321ad25a090520f3456569fc433a904648bf550e864e4ad94a
  reviewer:
    independence_claim: fresh-session
    write_scope_claim: REVIEW.md-only
  evidence_audit:
    eval_check: reproduced
    witness_ref: bash tools/eval/eval-check.sh candidates/cand-0091-queue-staleness-triage . -> "REPRODUCED (pass attested, pass reproduced, evidence intact)"
  findings: none
  recommendation: admit
```

```
ReviewNote:
  candidate_id: cand-0091-queue-staleness-triage
  reviewed_at: 2026-07-03T14:05:00Z
  brief_audited: agree — Cargo bound is `seeds/candidates/QUEUE.md` replacing live `candidates/QUEUE.md` (+8/-8 vs live per `diff`); attested verdict pass, harness reproduces.
  claims_verified:
    - "SECOND POSTING PROGRAM TRIAGE resolved by cand-0039 + repo/UST" -> `circuits/bom-receipt/{Nargo.toml,src}`, `circuits/event-bom-receipt/src/main.nr`, `circuits/event-repo-open/src/main.nr`, `circuits/event-repo-close/src/main.nr`, `circuits/event-ust/src/main.nr` all present; each of event-bom-receipt, event-repo-open, event-repo-close, event-ust `use event_harness::{discharge, EventPublics};` (grepped). Cand dirs `candidates/cand-0039-second-posting-program/`, `cand-0040-repo-clearing/`, `cand-0043-ust-trade/` all carry `LANDED`. VERIFIED — the harness is genuinely multi-program.
    - "PROVEKIT NIX-REPRO superseded by cand-0050-provekit-flake-import" -> `flake.nix` L360-391 defines `provekitToolchain`/`provekitCraneLib`/`provekitNoirSrc`/`provekitCommonArgs` with `cargoExtraArgs = "--offline -p provekit-cli"` and `overrideVendorGitCheckout` patching `noirc_driver`/`noir_stdlib`; `flake.lock` L1376+ pins `provekit-src` from `worldfnd`. VERIFIED — the flake builds ProveKit from worldfnd upstream.
    - "VNET/1 rewrite: circuit is demo-shaped, generator binding not spec-compliant" -> `world-app/provekit-vnet/src/main.nr` L12-13 sets `N_ATOMS = 2`, `N_BASIS = 3`; L27 uses `std::hash::derive_generators("AAC_PEDERSEN_VECTOR_VNET_1".as_bytes(), 0)` — a fixed label with no basis binding. `sites/ledger/specs/profiles/PEDERSEN-VECTOR-1.md` L46-71 requires `seed(label,j) = Poseidon2("aac/vnet/1", profile_id, basis_commitment, basis_type_id_j, label, j)` and verifier-independent re-derivation. VERIFIED — the remaining-scope call-out matches code vs spec.
    - "Fundraise/BCC runtime is harness-orphaned" -> `fundraise-runtime/src/index.mjs` L5,L8 imports `../../bcc-runtime/src/index.mjs` and `../../vnet-runtime/src/index.mjs`; recursive grep for `event-harness` in `fundraise-runtime/` returns empty. VERIFIED — factual statement; the entry frames both integration paths (become a posting program vs record permanent split) without prejudging.
    - "0037..0044 range refs cite (number, slug) per DN0005 rule" -> all four resolved/rewritten entries reference `cand-0039-second-posting-program`, `cand-0040-repo-clearing`, `cand-0043-ust-trade`, `cand-0050-provekit-flake-import`, `cand-0052-provekit-vnet-circuit` with slugs. VERIFIED.
  concerns: none
  questions_asked: none — non-interactive convening; the coordinator context-notes' four verification asks were treated as the review checklist and answered above.
  recommendation: admit
```
