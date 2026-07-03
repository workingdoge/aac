# Dispatch Economics v0

Policy id: boat.dispatch-economics.v0
Owner: operator
Status: active (declared 2026-07-03)
Scope: workspace-wide worker/reviewer/coordinator role assignment for
governed candidate work

## Policy

Fable/Anthropic (usage credits) is the scarce high-leverage resource.
codex/OpenAI (flat subscription) is the volume resource.

| Role | Assignment |
|---|---|
| BUILD (proposer) | codex, dispatched with a fully self-contained brief |
| REVIEW (independent) | a fresh claude session (`claude -p` or equivalent ephemeral convening), never the coordinator inline |
| COORDINATE | the Fable main session: dispatch briefs, tracker, reconvenes, admit/land under operator authorization, memory, cross-repo sequencing |
| HARD SYNTHESIS | Fable only where cross-repo context genuinely requires it: law design judgment, program scoping, curvature escalations |

Fable allocation is sized for leverage, never volume builds -- minimal use,
maximum effect.

## Why This Works

Acceptance is discharge-determined (BIDIR-4.4): the gates validate with the
harness lint, attested evals, eval-check replay, and independent review. Those
gates enforce quality, not builder trust. A weak build costs a transform round
on the subscription, not credits.

Measured baseline 2026-07-03: Fable build agents ran 120-490k tokens per
candidate; reviews are structurally cheaper.

Cross-model review (codex proposes, claude reviews) is epistemically stronger
than same-model review: each side of the gate has different failure modes.

The coordinator must not review inline because it has authorship stake in its
own dispatch briefs.

## Operational Rules

1. Build dispatches are self-contained briefs: canon reading list, eval
   standards including the standalone-subshell probe form, and STOP after
   `loop brief`. codex workers are not steered mid-task. Failed gates route
   through the instance queue, not conversation. `loop dispatch --worker codex`
   is the house mechanism where its origin-allowlist expectations hold.

2. Reviews convene a fresh claude session per candidate. The local claude CLI
   carries Nix daemon access which the codex sandbox lacks, retiring the
   irai-32e reviewer gap for claude-side reviews: five paid round-trips as of
   2026-07-03.

3. Route by check substrate. nix-eval-heavy evals must not be discharged in
   the codex sandbox. bash/jq-checkable work is codex-safe. Split at dispatch
   time.

4. Review tiering (workspace tracker irai-dac, realization pending):
   mechanical claims such as byte-identity, ancestry, and pin moves get
   checklist-tier verification. Semantic claims such as law, authority
   boundaries, and eval soundness get full independent review.

5. Subordination clause: this policy exempts nothing from the gates.
   Operator-held decisions remain operator-held regardless of proposing
   worker. Per-instance WORKER.md contracts remain binding.

## Provenance

Declared by the operator in-session 2026-07-03 after measured
build-on-Fable/review-on-codex baseline. The inversion was chosen because
discharge-determined gates make builder identity a cost variable, not a
quality variable.

This doc is kernel cargo (export manifest row) and transports via the
connection. Instances treat it as operator policy, never as law displacing
premath statements.
