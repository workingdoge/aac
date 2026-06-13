// The Mini App: one human, one agent, one proof circuit, one approval checkpoint
// (Design Note 0002 §8). This is a SKELETON — every external SDK call routes through
// the stubs in ./lib/* and throws until wired. The UI shows the five-step flow and
// surfaces each stub's "verify-at-integration" error instead of faking success.

import { useState } from "react";

import { walletAuth, proveUniqueness, type WalletAuthResult } from "./lib/worldid.js";
import { registerAgentWallet, WORLD_CHAIN, type AgentRegistration } from "./lib/agentbook.js";
import { mintStarterCredits, type StarterCredits } from "./lib/credits.js";
import { createAgentkitClient } from "./lib/agentkit-client.js";
import {
  buildReceiptWitness,
  proveReceipt,
  type ReceiptWitness,
  type ProveKitProof,
} from "./lib/provekit.js";
import { ApprovalCheckpoint } from "./components/ApprovalCheckpoint.js";
import { StepCard } from "./components/StepCard.js";

const GATEWAY_URL = (import.meta as unknown as { env?: { VITE_GATEWAY_URL?: string } }).env?.VITE_GATEWAY_URL
  ?? "http://localhost:8787";

export function App() {
  const [auth, setAuth] = useState<WalletAuthResult | null>(null);
  const [credits, setCredits] = useState<StarterCredits | null>(null);
  const [registration, setRegistration] = useState<AgentRegistration | null>(null);
  const [proof, setProof] = useState<ProveKitProof | null>(null);
  const [via, setVia] = useState<"browser" | "server" | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState<string | null>(null);

  // the agentkit client the agent uses to call protected gateway endpoints.
  const agentkit = createAgentkitClient({ signer: auth?.address ?? null, chain: WORLD_CHAIN });

  function run(label: string, fn: () => Promise<void>) {
    return async () => {
      setError(null);
      setBusy(label);
      try {
        await fn();
      } catch (e) {
        // Stubs throw "verify-at-integration" — show it, do not pretend it worked.
        setError((e as Error).message);
      } finally {
        setBusy(null);
      }
    };
  }

  // step 1 — walletAuth sign-in
  const onSignIn = run("walletAuth", async () => {
    setAuth(await walletAuth());
  });

  // step 2 — uniqueness proof -> one-per-human starter credits keyed by nullifier
  const onProveUnique = run("proveUniqueness", async () => {
    const u = await proveUniqueness("aac:starter-credits");
    setCredits(mintStarterCredits(u.nullifier_hash));
  });

  // step 3 — AgentBook registration (default World Chain; transport unresolved)
  const onRegister = run("registerAgentWallet", async () => {
    if (auth === null) throw new Error("sign in first");
    setRegistration(await registerAgentWallet(auth.address, { chain: WORLD_CHAIN }));
  });

  // step 4 — client-side ProveKit proof (witness build + WASM placeholder, server fallback)
  const onProve = run("proveReceipt", async () => {
    const witness: ReceiptWitness = buildReceiptWitness(
      { usd_cents: 10000n, fabric_meters: 50n, buyer_id: "111", supplier_id: "222" },
      {
        // recompute from the deployed circuit's hash — placeholders here (see circuit README)
        rulebook_id: "7",
        event_commitment: "0x00",
        participant_set: "0x00",
        journal_commitment: "0x00",
        event_nullifier: "0x00",
      },
    );
    const result = await proveReceipt(
      witness,
      { proverKeyUrl: "/keys/aac_receipt.pk", abortAfterMs: 8000 },
      {
        gatewayUrl: GATEWAY_URL,
        agentkitFetch: agentkit.fetch,
        // DEMO ONLY: allow the server-side proving fallback so the MVP ships even
        // before the browser WASM glue is wired. This sends the witness (incl. party
        // ids) to the gateway -- a deliberate privacy tradeoff; production keeps
        // proving client-side or blinds the witness first.
        allowWitnessToServer: true,
      },
    );
    setProof(result.proof);
    setVia(result.via);
  });

  return (
    <main style={{ maxWidth: 560, margin: "0 auto", padding: 16, fontFamily: "system-ui, sans-serif" }}>
      <h1 style={{ fontSize: 20 }}>AAC — human-backed clearing copilot</h1>
      <p style={{ color: "#666", fontSize: 13 }}>
        Prototype skeleton. Every World/ProveKit call is a stub that throws
        "verify-at-integration" until the Beta SDKs are wired.
      </p>

      {error && (
        <div style={{ background: "#fff3f3", border: "1px solid #f3c2c2", padding: 8, borderRadius: 6, fontSize: 12, marginBottom: 12 }}>
          <strong>stub / integration error:</strong> {error}
        </div>
      )}

      <StepCard n={1} title="Sign in (walletAuth)" done={auth !== null}
        detail={auth ? `wallet ${auth.address}` : "binds the session to a wallet"}
        action={{ label: "walletAuth()", onClick: onSignIn, busy: busy === "walletAuth", disabled: auth !== null }} />

      <StepCard n={2} title="Prove unique human → starter credits" done={credits !== null}
        detail={credits ? `${credits.remaining} credits, keyed by nullifier ${credits.nullifier.slice(0, 10)}…` : "one-time uniqueness proof; credits keyed by the stored nullifier"}
        action={{ label: "proveUniqueness()", onClick: onProveUnique, busy: busy === "proveUniqueness", disabled: auth === null || credits !== null }} />

      <StepCard n={3} title="Register agent wallet (AgentBook)" done={registration !== null}
        detail={registration ? `registered on ${registration.chain}` : `default ${WORLD_CHAIN}; registration transport UNRESOLVED`}
        action={{ label: "registerAgentWallet()", onClick: onRegister, busy: busy === "registerAgentWallet", disabled: auth === null || registration !== null }} />

      <StepCard n={4} title="Client-side proof (ProveKit)" done={proof !== null}
        detail={proof ? `proof via ${via} (${proof.proof.length} bytes)` : "build witness → WASM prove (placeholder) → server fallback on abort"}
        action={{ label: "proveReceipt()", onClick: onProve, busy: busy === "proveReceipt", disabled: credits === null || proof !== null }} />

      <ApprovalCheckpoint
        enabled={proof !== null}
        nullifier={credits?.nullifier ?? "pending"}
      />
    </main>
  );
}
