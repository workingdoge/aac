# Threshold Brief: cand-0027-world-app-scaffold

Generated: 2026-06-13T20:50:48Z
Status: landed
Intent: Land the World-stack MVP scaffold (Design Note 0002) onto main as a clearly-labeled prototype: world-app/ = a MiniKit Mini App (walletAuth + World ID uniqueness -> one-per-human starter credits + AgentBook + client-side ProveKit proof + HITL approval) + an AgentKit x402 gateway (per-human SHARED counter, free/free-trial/discount, persistent-storage interface, replay nonces) + a beta.19 ProveKit receipt circuit (a right-sized EVENT-COMPLETE/1 BVR). Reviewed by a 4-lens adversarial panel (no critical/soundness findings; honest stubs). Applies 4 pre-landing fixes: (1) add the numeraire-collapse rejection test to the provekit circuit; (2) production guard on the dev-only in-memory gateway storage; (3) a .env.example; (4) make the provekit server-fallback party-ID-leak caveat loud. External SDKs are stubbed (verify-at-integration); the beta.19 circuit does not compile in this beta.14 env (documented).
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=a324246e80c0202d95f4e3a4b88dc8b048e92e49a9326a4e6bccd1e76b94cba1

## Cargo (what lands if admitted)

- `cargo/world-app/.gitignore` replaces `world-app/.gitignore`: +0/-0 lines vs live
- `cargo/world-app/README.md` replaces `world-app/README.md`: +0/-0 lines vs live
- `cargo/world-app/gateway/README.md` replaces `world-app/gateway/README.md`: +0/-0 lines vs live
- `cargo/world-app/gateway/package.json` replaces `world-app/gateway/package.json`: +0/-0 lines vs live
- `cargo/world-app/gateway/src/core/aac-stub.ts` replaces `world-app/gateway/src/core/aac-stub.ts`: +0/-0 lines vs live
- `cargo/world-app/gateway/src/core/agentkit.ts` replaces `world-app/gateway/src/core/agentkit.ts`: +0/-0 lines vs live
- `cargo/world-app/gateway/src/core/gateway.ts` replaces `world-app/gateway/src/core/gateway.ts`: +0/-0 lines vs live
- `cargo/world-app/gateway/src/core/policy.ts` replaces `world-app/gateway/src/core/policy.ts`: +0/-0 lines vs live
- `cargo/world-app/gateway/src/core/types.ts` replaces `world-app/gateway/src/core/types.ts`: +0/-0 lines vs live
- `cargo/world-app/gateway/src/examples/hono.ts` replaces `world-app/gateway/src/examples/hono.ts`: +0/-0 lines vs live
- `cargo/world-app/gateway/src/index.ts` replaces `world-app/gateway/src/index.ts`: +0/-0 lines vs live
- `cargo/world-app/gateway/src/storage/interface.ts` replaces `world-app/gateway/src/storage/interface.ts`: +0/-0 lines vs live
- `cargo/world-app/gateway/src/storage/memory.ts` replaces `world-app/gateway/src/storage/memory.ts`: +0/-0 lines vs live
- `cargo/world-app/gateway/tsconfig.json` replaces `world-app/gateway/tsconfig.json`: +0/-0 lines vs live
- `cargo/world-app/miniapp/.env.example` replaces `world-app/miniapp/.env.example`: +0/-0 lines vs live
- `cargo/world-app/miniapp/README.md` replaces `world-app/miniapp/README.md`: +0/-0 lines vs live
- `cargo/world-app/miniapp/index.html` replaces `world-app/miniapp/index.html`: +0/-0 lines vs live
- `cargo/world-app/miniapp/package.json` replaces `world-app/miniapp/package.json`: +0/-0 lines vs live
- `cargo/world-app/miniapp/src/App.tsx` replaces `world-app/miniapp/src/App.tsx`: +0/-0 lines vs live
- `cargo/world-app/miniapp/src/components/ApprovalCheckpoint.tsx` replaces `world-app/miniapp/src/components/ApprovalCheckpoint.tsx`: +0/-0 lines vs live
- `cargo/world-app/miniapp/src/components/StepCard.tsx` replaces `world-app/miniapp/src/components/StepCard.tsx`: +0/-0 lines vs live
- `cargo/world-app/miniapp/src/lib/agentbook.ts` replaces `world-app/miniapp/src/lib/agentbook.ts`: +0/-0 lines vs live
- `cargo/world-app/miniapp/src/lib/agentkit-client.ts` replaces `world-app/miniapp/src/lib/agentkit-client.ts`: +0/-0 lines vs live
- `cargo/world-app/miniapp/src/lib/credits.ts` replaces `world-app/miniapp/src/lib/credits.ts`: +0/-0 lines vs live
- `cargo/world-app/miniapp/src/lib/provekit.ts` replaces `world-app/miniapp/src/lib/provekit.ts`: +0/-0 lines vs live
- `cargo/world-app/miniapp/src/lib/worldid.ts` replaces `world-app/miniapp/src/lib/worldid.ts`: +0/-0 lines vs live
- `cargo/world-app/miniapp/src/main.tsx` replaces `world-app/miniapp/src/main.tsx`: +0/-0 lines vs live
- `cargo/world-app/miniapp/tsconfig.json` replaces `world-app/miniapp/tsconfig.json`: +0/-0 lines vs live
- `cargo/world-app/miniapp/vite.config.ts` replaces `world-app/miniapp/vite.config.ts`: +0/-0 lines vs live
- `cargo/world-app/provekit-circuit/Nargo.toml` replaces `world-app/provekit-circuit/Nargo.toml`: +0/-0 lines vs live
- `cargo/world-app/provekit-circuit/Prover.toml.example` replaces `world-app/provekit-circuit/Prover.toml.example`: +0/-0 lines vs live
- `cargo/world-app/provekit-circuit/README.md` replaces `world-app/provekit-circuit/README.md`: +0/-0 lines vs live
- `cargo/world-app/provekit-circuit/src/hash.nr` replaces `world-app/provekit-circuit/src/hash.nr`: +0/-0 lines vs live
- `cargo/world-app/provekit-circuit/src/ledger.nr` replaces `world-app/provekit-circuit/src/ledger.nr`: +0/-0 lines vs live
- `cargo/world-app/provekit-circuit/src/main.nr` replaces `world-app/provekit-circuit/src/main.nr`: +0/-0 lines vs live
- `cargo/world-app/provekit-circuit/src/pacioli.nr` replaces `world-app/provekit-circuit/src/pacioli.nr`: +0/-0 lines vs live
- `cargo/world-app/provekit-circuit/src/rulebook.nr` replaces `world-app/provekit-circuit/src/rulebook.nr`: +0/-0 lines vs live

## Witnessed behavioral delta (task: land the World-stack MVP scaffold (Design Note 0002) onto main as a labeled prototype after a 4-lens review + 5 fixes (numeraire-collapse test, in-memory storage production guard, .env.example, opt-in+loud server-fallback, ASCII circuit); honest stubs + caveats; node_modules uncommitted; the Pn no-numeraire-collapse property executes green on beta.14)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
