# cand-0097-web-receipt-value-cascade

Intent: Web aac-receipt value cascade: refresh stale tag-reassignment values (cand-0032 follow-up)

Status: open (pre-threshold).

## Cargo

- `seeds/web/src/components/aac-receipt.ts` replaces `web/src/components/aac-receipt.ts`.
- `seeds/web/src/content/docs/components.mdx` replaces `web/src/content/docs/components.mdx`.
- `seeds/candidates/QUEUE.md` replaces `candidates/QUEUE.md` with the web receipt cascade entry resolved.

## Evidence Plan

- Enumerate the old cand-0032 rollback participant_set/event_nullifier values and prove they are absent from the staged `web/` tree, with a reintroduction mutant.
- Prove the four current EVENT-COMPLETE/1 public inputs are present in both the Lit component and `/components`, with a removal mutant.
- Recompute or execute the beta.14 `circuits/event-complete` witness path; if the sandbox cannot provide the pinned `nargo`, record the blocker explicitly.
- Build the staged web site through the repo `web/package.json` build command, or record the missing toolchain blocker explicitly.
- Lint the staged queue update and reject a duplicate-header mutant.

No tier-guard review is required: cargo lands under `web/**` and `candidates/QUEUE.md`, not `tools/**` or the premath law spine.

## Optional RLM Trace Evidence

When model-assisted or large-context reasoning materially supports this candidate,
keep that support in checking mode: generate an explicit trace with
`tools/eval/rlm-trace-from-candidate.sh`, check it with
`sites/eval/realizations/rlm-trace-profile-check/rlm-trace-profile-check.sh`,
and store the JSONL plus checker output under `traces/` before attestation.
A passing RLM trace is evidence only; it does not grant answer authority,
KB admission, Boat candidate admission, Harbor readiness, live LLM calls,
provider calls, network access, shell access, or secret access.
