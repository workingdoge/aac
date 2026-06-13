# Threshold Brief: cand-0027-world-app-scaffold

Generated: 2026-06-13T20:50:46Z
Status: validated
Intent: Land the World-stack MVP scaffold (Design Note 0002) onto main as a clearly-labeled prototype: world-app/ = a MiniKit Mini App (walletAuth + World ID uniqueness -> one-per-human starter credits + AgentBook + client-side ProveKit proof + HITL approval) + an AgentKit x402 gateway (per-human SHARED counter, free/free-trial/discount, persistent-storage interface, replay nonces) + a beta.19 ProveKit receipt circuit (a right-sized EVENT-COMPLETE/1 BVR). Reviewed by a 4-lens adversarial panel (no critical/soundness findings; honest stubs). Applies 4 pre-landing fixes: (1) add the numeraire-collapse rejection test to the provekit circuit; (2) production guard on the dev-only in-memory gateway storage; (3) a .env.example; (4) make the provekit server-fallback party-ID-leak caveat loud. External SDKs are stubbed (verify-at-integration); the beta.19 circuit does not compile in this beta.14 env (documented).
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=a324246e80c0202d95f4e3a4b88dc8b048e92e49a9326a4e6bccd1e76b94cba1

## Cargo (what lands if admitted)

- `cargo/world-app/.gitignore` is NEW at `world-app/.gitignore`: 12 lines
- `cargo/world-app/README.md` is NEW at `world-app/README.md`: 167 lines
- `cargo/world-app/gateway/README.md` is NEW at `world-app/gateway/README.md`: 84 lines
- `cargo/world-app/gateway/package.json` is NEW at `world-app/gateway/package.json`: 30 lines
- `cargo/world-app/gateway/src/core/aac-stub.ts` is NEW at `world-app/gateway/src/core/aac-stub.ts`: 49 lines
- `cargo/world-app/gateway/src/core/agentkit.ts` is NEW at `world-app/gateway/src/core/agentkit.ts`: 116 lines
- `cargo/world-app/gateway/src/core/gateway.ts` is NEW at `world-app/gateway/src/core/gateway.ts`: 150 lines
- `cargo/world-app/gateway/src/core/policy.ts` is NEW at `world-app/gateway/src/core/policy.ts`: 86 lines
- `cargo/world-app/gateway/src/core/types.ts` is NEW at `world-app/gateway/src/core/types.ts`: 98 lines
- `cargo/world-app/gateway/src/examples/hono.ts` is NEW at `world-app/gateway/src/examples/hono.ts`: 75 lines
- `cargo/world-app/gateway/src/index.ts` is NEW at `world-app/gateway/src/index.ts`: 10 lines
- `cargo/world-app/gateway/src/storage/interface.ts` is NEW at `world-app/gateway/src/storage/interface.ts`: 45 lines
- `cargo/world-app/gateway/src/storage/memory.ts` is NEW at `world-app/gateway/src/storage/memory.ts`: 73 lines
- `cargo/world-app/gateway/tsconfig.json` is NEW at `world-app/gateway/tsconfig.json`: 22 lines
- `cargo/world-app/miniapp/.env.example` is NEW at `world-app/miniapp/.env.example`: 12 lines
- `cargo/world-app/miniapp/README.md` is NEW at `world-app/miniapp/README.md`: 56 lines
- `cargo/world-app/miniapp/index.html` is NEW at `world-app/miniapp/index.html`: 13 lines
- `cargo/world-app/miniapp/package.json` is NEW at `world-app/miniapp/package.json`: 24 lines
- `cargo/world-app/miniapp/src/App.tsx` is NEW at `world-app/miniapp/src/App.tsx`: 134 lines
- `cargo/world-app/miniapp/src/components/ApprovalCheckpoint.tsx` is NEW at `world-app/miniapp/src/components/ApprovalCheckpoint.tsx`: 81 lines
- `cargo/world-app/miniapp/src/components/StepCard.tsx` is NEW at `world-app/miniapp/src/components/StepCard.tsx`: 49 lines
- `cargo/world-app/miniapp/src/lib/agentbook.ts` is NEW at `world-app/miniapp/src/lib/agentbook.ts`: 47 lines
- `cargo/world-app/miniapp/src/lib/agentkit-client.ts` is NEW at `world-app/miniapp/src/lib/agentkit-client.ts`: 40 lines
- `cargo/world-app/miniapp/src/lib/credits.ts` is NEW at `world-app/miniapp/src/lib/credits.ts`: 59 lines
- `cargo/world-app/miniapp/src/lib/provekit.ts` is NEW at `world-app/miniapp/src/lib/provekit.ts`: 193 lines
- `cargo/world-app/miniapp/src/lib/worldid.ts` is NEW at `world-app/miniapp/src/lib/worldid.ts`: 96 lines
- `cargo/world-app/miniapp/src/main.tsx` is NEW at `world-app/miniapp/src/main.tsx`: 19 lines
- `cargo/world-app/miniapp/tsconfig.json` is NEW at `world-app/miniapp/tsconfig.json`: 19 lines
- `cargo/world-app/miniapp/vite.config.ts` is NEW at `world-app/miniapp/vite.config.ts`: 11 lines
- `cargo/world-app/provekit-circuit/Nargo.toml` is NEW at `world-app/provekit-circuit/Nargo.toml`: 25 lines
- `cargo/world-app/provekit-circuit/Prover.toml.example` is NEW at `world-app/provekit-circuit/Prover.toml.example`: 19 lines
- `cargo/world-app/provekit-circuit/README.md` is NEW at `world-app/provekit-circuit/README.md`: 149 lines
- `cargo/world-app/provekit-circuit/src/hash.nr` is NEW at `world-app/provekit-circuit/src/hash.nr`: 36 lines
- `cargo/world-app/provekit-circuit/src/ledger.nr` is NEW at `world-app/provekit-circuit/src/ledger.nr`: 54 lines
- `cargo/world-app/provekit-circuit/src/main.nr` is NEW at `world-app/provekit-circuit/src/main.nr`: 155 lines
- `cargo/world-app/provekit-circuit/src/pacioli.nr` is NEW at `world-app/provekit-circuit/src/pacioli.nr`: 80 lines
- `cargo/world-app/provekit-circuit/src/rulebook.nr` is NEW at `world-app/provekit-circuit/src/rulebook.nr`: 75 lines

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
