# Fundraise Workflow

This package is the dependency-free workflow core for the fundraising demo.

It composes three objects:

- a FUNDRAISE-CLEARING/1 packet;
- a verifier receipt saying a ProveKit/CRE/runtime verifier accepted the packet;
- the `fundraise-authorizer` settlement signing request.

The output is a deterministic settlement action for
`FundraiseMintSettlement.settle(auth, signature)`.

This package intentionally does not import the CRE SDK, verify ProveKit proofs,
sign Ethereum messages, submit transactions, or touch Nix/flake dependencies. A
real CRE workflow or ProveKit verifier service should produce the verifier receipt
and then call `authorizeFundraiseWorkflow`. The returned settlement action is what
the authorizer key signs and submits.

For local development, `buildDemoVerifierReceipt` creates a clearly marked
`runtime-reference` verifier receipt. Production policy can reject it by setting
`require_live_proof: true` or by excluding `runtime-reference` from
`accepted_proof_systems`.

```js
import {
  authorizeFundraiseWorkflow,
  buildDemoVerifierReceipt,
} from "@aac/fundraise-workflow";

const verifier_receipt = buildDemoVerifierReceipt({ packet });
const receipt = authorizeFundraiseWorkflow({ packet, verifier_receipt });

if (!receipt.accepted) throw new Error(receipt.reason);
// receipt.settlement_action.args.auth is ready for FundraiseMintSettlement.settle.
// receipt.settlement_action.args.signature is intentionally null until the
// deployment authorizer signs the Solidity digest.
```
