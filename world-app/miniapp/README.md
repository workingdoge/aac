# @aac/world-miniapp — Mini App skeleton

A World Mini App (TypeScript/React, MiniKit) for the AAC human-backed clearing
copilot. **Skeleton only** — every World/ProveKit SDK call is a typed stub that
throws "verify-at-integration" until the Beta SDKs are wired. The UI surfaces those
errors instead of faking success.

## The five-step flow (Design Note 0002 §8)

| step | file | verified surface | status |
|---|---|---|---|
| 1. `walletAuth()` sign-in | `lib/worldid.ts` | `walletAuth()` (3-0) | **stub** |
| 2. uniqueness proof → one-per-human credits | `lib/worldid.ts` + `lib/credits.ts` | `POST /api/v4/verify/{rp_id}`, one-time nullifier | **stub** (credit store is real, keyed by nullifier) |
| 3. AgentBook agent-wallet registration | `lib/agentbook.ts` | lookup on World Chain `eip155:480` (2-1) | **stub** (transport unresolved) |
| 4. client-side ProveKit proof | `lib/provekit.ts` | WASM proving supported (3-0) but thin | **witness build real; WASM prove placeholder; server fallback real-shaped** |
| 5. HITL approval checkpoint | `components/ApprovalCheckpoint.tsx` | `requestHumanAuthorization`, action id customizable (3-0) | **stub** (bound to `receipt:<nullifier>`) |

## What is REAL vs stubbed here

- **Real:** the flow orchestration (`App.tsx`), the starter-credit store keyed by the
  stored nullifier (`credits.ts`, idempotent — one grant per human), the witness
  assembly + client-side role sanity checks (`provekit.ts buildReceiptWitness`), the
  abort-criterion race (browser WASM → server fallback), the domain-action-token
  binding for HITL.
- **Stubbed (throws "verify-at-integration"):** `walletAuth`, `proveUniqueness`,
  `requestHumanAuthorization`, `registerAgentWallet`, `createAgentkitClient().fetch`,
  and the WASM `proveInBrowser`. Each throw names the exact integration step.

## Integration deps (NOT installed — all Beta, pin at integration)

- MiniKit — candidate `@worldcoin/minikit-js` (name/version **unverified**)
- AgentKit client SDK (the `createAgentkitClient` helper)
- World ID HITL package (the `requestHumanAuthorization` helper)
- ProveKit WASM module (the browser prove path)

The `lib/*` shims compile **without** these and throw at runtime, so `tsc` passes and
the app renders the flow before any SDK is added.

## Run (after `npm install`)

```sh
npm install
npm run typecheck   # verified clean in this scaffold
npm run dev         # Vite dev server on :5173 — renders the skeleton UI
```

Mini Apps run inside World App's webview; for local dev, tunnel into World App via the
Developer Portal. Put the ProveKit `prepare` output (the prover key) under
`public/keys/` so `fetchProverKey()` can cache it.

## ProveKit privacy note

The browser path posts only `proof + public inputs` to the gateway. The **server
fallback** (`proveOnServer`) posts the witness — so the server-fallback path trades
privacy for shipping. Make that tradeoff explicit in any real deployment; do not send
party ids to a server you do not want to see them.
