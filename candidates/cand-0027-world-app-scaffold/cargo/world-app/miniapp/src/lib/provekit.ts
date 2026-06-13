// Client-side ProveKit proof step.
//
// Design Note 0002 §5: the Mini App webview builds the witness, fetches the prover
// key once (cache it), proves client-side via the WASM path, and posts only
// `proof + public inputs` to the gateway. The browser glue is UNDER-DOCUMENTED —
// budget wrapper work and set an ABORT CRITERION: if the WASM path overruns, fall
// back to SERVER-SIDE proving and still ship.
//
// This file has a REAL witness-build shape (the private/public input assembly the
// circuit expects, mirroring world-app/provekit-circuit/src/main.nr) and a clearly
// marked PLACEHOLDER for the WASM prove call.

// ---- the receipt witness (matches provekit-circuit/src/main.nr ABI) ----------

/** Private witness — the typed quantities and the two party ids. */
export interface ReceiptWitnessPrivate {
  usd_cents: bigint;
  fabric_meters: bigint;
  buyer_id: string; // field element as 0x-hex or decimal string
  supplier_id: string;
}

/**
 * Public inputs (order normative; SUBSET of the EVENT-COMPLETE/1 §5 ABI):
 *   0 rulebook_id
 *   1 event_commitment
 *   2 participant_set
 *   3 journal_commitment
 *   4 event_nullifier
 * These commitment values are HASH-DEPENDENT (Skyscraper vs the Poseidon2
 * placeholder) — recompute them with the deployed circuit's hash. The witness
 * builder here assembles the STRUCTURE; the actual field hashing is done by the
 * WASM/nargo witness generator, not in JS.
 */
export interface ReceiptPublicInputs {
  rulebook_id: string;
  event_commitment: string;
  participant_set: string;
  journal_commitment: string;
  event_nullifier: string;
}

export interface ReceiptWitness {
  private: ReceiptWitnessPrivate;
  public: ReceiptPublicInputs;
}

/** The proof + public inputs the client posts to the gateway/backend. */
export interface ProveKitProof {
  proof: Uint8Array;
  publicInputs: ReceiptPublicInputs;
}

// ---- witness assembly (REAL; deterministic) ---------------------------------

/**
 * Assemble the witness map the WASM prover (or `nargo execute`) consumes. This is
 * the real shape; it does NOT compute the hash commitments (that is the prover's
 * job from the same `main.nr`). For a dev flow, fill the public commitment values
 * from `nargo test --show-output print_public_inputs` (see the circuit README).
 */
export function buildReceiptWitness(
  priv: ReceiptWitnessPrivate,
  pub: ReceiptPublicInputs,
): ReceiptWitness {
  // Light client-side sanity checks that mirror the circuit's role obligations, so
  // the user gets a fast error before the (expensive) prove call.
  if (priv.buyer_id === "0" || priv.buyer_id === "0x0") throw new Error("missing Buyer role");
  if (priv.supplier_id === "0" || priv.supplier_id === "0x0") throw new Error("missing Supplier role");
  if (priv.buyer_id === priv.supplier_id) throw new Error("one party fills both roles");
  if (priv.usd_cents < 0n || priv.fabric_meters < 0n) throw new Error("negative coordinate");
  return { private: priv, public: pub };
}

// ---- prover-key cache (fetch once) ------------------------------------------

let proverKeyCache: Uint8Array | null = null;

/**
 * Fetch the ProveKit prover key once and cache it (Design Note 0002 §5: "fetches the
 * prover key once (cache it)"). The key comes from the circuit's `prepare` step,
 * served as a static asset. STUB the actual fetch target.
 */
export async function fetchProverKey(url: string): Promise<Uint8Array> {
  if (proverKeyCache !== null) return proverKeyCache;
  const res = await fetch(url);
  if (!res.ok) throw new Error(`[provekit] prover key fetch failed: ${res.status}`);
  proverKeyCache = new Uint8Array(await res.arrayBuffer());
  return proverKeyCache;
}

// ---- the WASM prove call (PLACEHOLDER) --------------------------------------

export interface ProveOptions {
  /** prover-key asset URL (the prepared key). */
  proverKeyUrl: string;
  /** abort the WASM path after this many ms and let the caller fall back. */
  abortAfterMs: number;
}

/**
 * Prove client-side via ProveKit's WASM path. PLACEHOLDER for the WASM prove call —
 * the browser glue is the real, under-documented hackathon work (Design Note 0002
 * §2.1 CAVEAT, §5).
 *
 * The ABORT CRITERION is wired into the signature: callers race this against
 * `abortAfterMs` and, on overrun, call `proveOnServer` instead (still ships the MVP).
 *
 * @throws always, until the WASM module is wired.
 */
export async function proveInBrowser(
  _witness: ReceiptWitness,
  opts: ProveOptions,
): Promise<ProveKitProof> {
  await fetchProverKey(opts.proverKeyUrl); // cache the key even though prove is stubbed
  // At integration:
  //   1. import the ProveKit WASM module (path UNVERIFIED — the browser demo glue)
  //   2. generate the witness from `_witness` (the same inputs `nargo execute` takes)
  //   3. call the WASM prove(proverKey, witness) -> WHIR proof bytes
  //   4. return { proof, publicInputs: _witness.public }
  throw new Error(
    "[provekit] proveInBrowser() is a placeholder — wire ProveKit's WASM prove path " +
      "(verify-at-integration, Design Note 0002 §2.1 browser CAVEAT). On overrun past " +
      `${opts.abortAfterMs}ms, fall back to proveOnServer().`,
  );
}

/**
 * Server-side proving fallback — the abort-criterion landing spot. Posts the witness
 * to the gateway's `proof-gen` endpoint (server-fallback mode) and gets back the
 * proof. This path is real-shaped; the gateway proxies to the AAC proof service.
 */
export async function proveOnServer(
  witness: ReceiptWitness,
  gatewayUrl: string,
  agentkitFetch: (input: string, init?: RequestInit) => Promise<Response>,
): Promise<ProveKitProof> {
  // PRIVACY TRADEOFF (loud): the server fallback sends the FULL witness -- the
  // private quantities AND both party ids -- to the gateway, which defeats the
  // client-side-proving privacy of the WASM path. It exists only so the MVP ships
  // if the browser WASM glue is not yet wired. Production MUST keep proving
  // client-side, or blind/strip the witness before it leaves the device. Callers
  // opt in explicitly (proveReceipt's `allowWitnessToServer`); we warn at the boundary.
  console.warn(
    "[provekit] SERVER-FALLBACK: sending the full witness (private quantities + party " +
      "ids) to the gateway -- this defeats client-side privacy. Production must prove " +
      "client-side or blind the witness.",
  );
  const res = await agentkitFetch(`${gatewayUrl}/aac/proof-gen`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(witness),
  });
  if (!res.ok) throw new Error(`[provekit] server prove failed: ${res.status}`);
  const body = (await res.json()) as { proof: string };
  return {
    proof: Uint8Array.from(atob(body.proof), (c) => c.charCodeAt(0)),
    publicInputs: witness.public,
  };
}

/**
 * The full client proof step with the abort criterion: try the browser WASM path,
 * and on overrun OR failure fall back to server-side proving. This is the function
 * the UI calls.
 */
export async function proveReceipt(
  witness: ReceiptWitness,
  opts: ProveOptions,
  serverFallback: {
    gatewayUrl: string;
    agentkitFetch: (i: string, init?: RequestInit) => Promise<Response>;
    /** Explicit opt-in. The server fallback sends the witness (incl. party ids) to
     *  the gateway, defeating client-side privacy -- so it is never the silent
     *  default. Set this consciously (the demo does; production should not). */
    allowWitnessToServer: boolean;
  },
): Promise<{ proof: ProveKitProof; via: "browser" | "server" }> {
  const timeout = new Promise<never>((_, reject) =>
    setTimeout(() => reject(new Error("wasm-prove-timeout")), opts.abortAfterMs),
  );
  try {
    const proof = await Promise.race([proveInBrowser(witness, opts), timeout]);
    return { proof, via: "browser" };
  } catch (e) {
    // abort criterion: WASM overran or is not yet wired. Only fall back to the
    // privacy-defeating server path if the caller EXPLICITLY allowed it; otherwise
    // surface the failure rather than silently shipping the witness off-device.
    if (!serverFallback.allowWitnessToServer) throw e;
    const proof = await proveOnServer(witness, serverFallback.gatewayUrl, serverFallback.agentkitFetch);
    return { proof, via: "server" };
  }
}
