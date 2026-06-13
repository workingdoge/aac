# cand-0027-world-app-scaffold

Lands the **World-stack MVP scaffold** (Design Note 0002) onto main as a
**clearly-labeled prototype**, at `world-app/`. It makes the strategy concrete in
code: a human-backed clearing copilot Mini App + an AgentKit x402 gateway + a
right-sized ProveKit receipt circuit.

## What's here

- `world-app/miniapp/` — a MiniKit Mini App (TS/React): `walletAuth` → World ID
  uniqueness → one-per-human starter credits (nullifier-keyed, idempotent) →
  AgentBook registration → client-side ProveKit proof → a HITL approval bound to
  `receipt:<nullifier>`.
- `world-app/gateway/` — an AgentKit x402 gateway: the 402 + agentkit challenge,
  a **per-human SHARED counter** (N agent wallets → one human's quota),
  free/free-trial/discount policy, a persistent `GatewayStorage` interface +
  replay nonces.
- `world-app/provekit-circuit/` — a Noir **beta.19** circuit: a right-sized
  EVENT-COMPLETE/1 BalancedVectorReceipt (role coverage, `J = Φ_R(E)`, per-basis
  Pⁿ balance, u64 carrier, event-scoped nullifier).

## How it was vetted

A **4-lens adversarial review** (gateway/x402, circuit, miniapp, honesty) found
**no critical findings and no circuit soundness bugs**: the per-human counter is
correct, the stubs throw (never fake a pass), and the README doesn't overclaim.
The two "land-after-fixes" majors were documented integration TODOs (nonce
parsing; the Skyscraper-vs-Poseidon2 hash decision), not scaffold defects.

**Five pre-landing fixes** applied:
1. **Numeraire-collapse test** added to the circuit's `pacioli.nr` — proves
   fabric can't vanish even when USD balances (the heart of the Pⁿ thesis).
2. **Production guard** on the dev-only `InMemoryGatewayStorage` (throws under
   `NODE_ENV=production`) so it can't silently back a live deployment.
3. **`miniapp/.env.example`** (the `VITE_GATEWAY_URL` the app reads + integration
   TODOs).
4. **Server-fallback made opt-in + loud** in `provekit.ts`: the fallback ships
   the witness (incl. party ids) to the gateway, defeating client-side privacy —
   it is now an explicit `allowWitnessToServer` opt-in with a boundary warning,
   never a silent default.
5. **ASCII-only circuit source** — the `.nr`/`Nargo.toml` comments are
   transliterated (`§`→`S`, `—`→`--`) so they compile on beta.14 *and* beta.19
   (a latent compile risk, since beta.19 couldn't be tested here).

## What is NOT verified here (honestly)

External SDK calls (MiniKit `walletAuth`, World ID, AgentKit, ProveKit WASM) are
**stubbed** and throw `verify-at-integration`; only their names are confirmed
against the verified record. The full beta.19 circuit **does not compile in this
beta.14 env** (expected). The gateway + miniapp **typecheck clean** (`tsc
--noEmit`, verified against the scaffold's installed deps).

## Evidence (`eval-self.sh`, attested)

- fixes — all five fixes present (numeraire test, prod guard, `.env.example`,
  opt-in fallback, ASCII circuit).
- honesty — `node_modules` gitignored + uncommitted; the README carries the
  beta.19 / stub / verify-at-integration caveats; stubs throw.
- circuit — the Pⁿ no-numeraire-collapse property **executes green** on beta.14
  (`pacioli.nr` standalone: collapse rejected, vector zero-account balanced).

Status: open (pre-threshold).
