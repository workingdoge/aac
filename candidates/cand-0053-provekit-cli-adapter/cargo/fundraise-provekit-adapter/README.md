# Fundraise ProveKit Adapter

This package converts ProveKit verification into the normalized verifier receipt
consumed by `fundraise-workflow`.

It is intentionally a narrow adapter:

- it does not compile Noir;
- it does not verify WHIR or Groth16 proofs itself;
- it does not import the CRE SDK;
- it does not sign or submit transactions.

The real ProveKit CLI, browser WASM wrapper, service, or CRE workflow still does
the verification. This adapter can call the native `provekit-cli` prepare/prove/
verify flow, or it can accept a verification result from another environment. If
that verifier says `accepted: true`, this adapter binds the proof metadata,
public inputs, verifier key digest, packet commitment, and timings into a
deterministic `aac.fundraise-workflow.verifier-receipt.v1`.

That receipt can then be passed to `authorizeFundraiseWorkflow` with
`require_live_proof: true`.

```js
import { buildProveKitVerifierReceipt } from "@aac/fundraise-provekit-adapter";
import { authorizeFundraiseWorkflow, createWorkflowPolicy } from "@aac/fundraise-workflow";

const verifier_receipt = buildProveKitVerifierReceipt({
  packet,
  provekit: {
    accepted: true,
    proof_system: "provekit-whir",
    mode: "native-cli",
    proof: proofBytes,
    public_inputs: publicInputs,
    verifier_key_digest: vkDigest,
  },
});

const workflow = authorizeFundraiseWorkflow({
  packet,
  verifier_receipt,
  policy: createWorkflowPolicy({ require_live_proof: true }),
});
```

For the native CLI path, pass explicit filesystem paths. The adapter executes
`prepare`, `prove`, and `verify`, then hashes the proof file and verifier key
file into the receipt:

```js
import { buildProveKitVerifierReceiptFromNativeCli } from "@aac/fundraise-provekit-adapter";

const verifier_receipt = await buildProveKitVerifierReceiptFromNativeCli({
  packet,
  cli: {
    provekit_bin: process.env.PROVEKIT_BIN ?? "provekit-cli",
    circuit_dir: "world-app/provekit-vnet",
    prover_toml: "Prover.toml",
    prover_key: "aac_vnet_provekit.pkp",
    verifier_key: "aac_vnet_provekit.pkv",
    proof: "proof.np",
  },
});
```
