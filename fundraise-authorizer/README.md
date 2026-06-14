# Fundraise Authorizer

This package is the authorizer seam between the FUNDRAISE-CLEARING/1 runtime
packet and the demo `FundraiseMintSettlement` contract.

It does four things:

- verifies a fundraise packet with `fundraise-runtime`;
- shapes the runtime mint authorization into the EVM fields the settlement
  contract consumes;
- binds deployment policy fields such as chain id, settlement contract, token
  contract, round id hash, authorizer id, and verifier profile;
- emits a deterministic settlement signing request and authorizer receipt.

It intentionally does not sign Ethereum messages, verify ProveKit proofs,
compile Noir, simulate CRE, or compute the Solidity `keccak256` settlement
digest. A deployment CRE workflow, service, or operator key signs the contract
digest only after accepting this request and whatever ProveKit/runtime proof
checks the deployment requires.

For the demo, `authorizeFundraisePacket` is the main function. It returns a
fail-closed receipt:

```js
import { authorizeFundraisePacket } from "@aac/fundraise-authorizer";

const receipt = authorizeFundraisePacket({ packet });
if (!receipt.accepted) throw new Error(receipt.reason);
```

The receipt's `request.contract_authorization` field is the object a caller
passes to `FundraiseMintSettlement.settle` after the configured authorizer signs
the Solidity digest.
