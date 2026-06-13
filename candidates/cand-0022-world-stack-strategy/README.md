# cand-0022-world-stack-strategy

Lands **Design Note 0002** (non-normative): *The World Stack for AAC — AgentKit +
ProveKit*, at `sites/ledger/design/0002-world-stack-agentkit-provekit.md`, plus
its row in the design README. A hackathon-grade architecture for shipping AAC as
a **human-backed clearing copilot** Mini App: proof-of-human gates scarce access
(free proof-gen, quote/matching trials, financing/settlement slots), an AgentKit
x402 gateway meters per-human, ProveKit generates a narrow client-side receipt
proof (a right-sized EVENT-COMPLETE/1 BVR), and human-in-the-loop binds
irreversible actions (`receipt:<nullifier>`, `settlement:<batch_id>`) to a World
ID approval.

**Fact-checked, not just transcribed.** The note was written against a
2026-06-13 deep-research pass (5 angles, 21 sources, 25 claims under 3-vote
adversarial verification) and then audited by a 3-lens adversarial critic panel.
The verified record overrides the original strategy where they disagree:

- **ProveKit pins Noir `v1.0.0-beta.19`, NOT `beta.11`** (the draft's claim was
  stale). AAC is on `beta.14` — *behind* ProveKit. So a ProveKit circuit is a
  separate beta.19 package, isolated from the bb/UltraHonk workspace; do not
  downgrade and do not migrate the workspace.
- **AgentBook lookup resolves on World Chain (`eip155:480`)** (weakly, 2-1); the
  "gasless relay on **Base mainnet**" claim was **refuted 0-3**. Registration
  transport is left as an explicit open question.
- **ProveKit's default in-circuit hash is Skyscraper** (Poseidon2 only in
  examples) — so it does *not* automatically align with AAC's open Poseidon2
  item; the note flags this as a measured decision.
- Plus: World ID v4 `POST /api/v4/verify/{rp_id}`, uniqueness vs session proofs,
  HITL `requestHumanAuthorization` (action id defaults to the tool-call id,
  customizable), `walletAuth()`, and World Chain **PBH**. Perf numbers are marked
  unverified.

## Evidence (`eval-self.sh`, attested)

- structure — non-normative marker + all sections (Verified facts, AgentKit,
  ProveKit, narrow waist, MVP, Risks) present; listed in the design README.
- corrections — the research-grounded corrections are in the text (beta.19 not
  beta.11; AgentBook World Chain `eip155:480` with the Base claim flagged
  refuted; Skyscraper; v4 verify; `requestHumanAuthorization`; PBH; perf marked
  unverified).
- xrefs — EVENT-COMPLETE/1 + 4/REG cross-references resolve to real files on disk.

Status: open (pre-threshold).
