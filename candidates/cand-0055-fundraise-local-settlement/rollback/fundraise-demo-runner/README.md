# Fundraise Demo Runner

This package runs the real demo path for the fundraising story:

1. load the canonical `FUNDRAISE-DEMO-1` packet;
2. copy `world-app/provekit-vnet` to a temporary work directory;
3. run the native ProveKit CLI `prepare`, `prove`, and `verify` flow;
4. build a live-proof verifier receipt;
5. run `fundraise-workflow` with `require_live_proof: true`;
6. emit the pending `FundraiseMintSettlement.settle(auth, signature)` action.

It does not sign the authorizer request, submit a transaction, deploy contracts,
or verify a recursive proof on-chain. Those are the next deployment steps.

```sh
PROVEKIT_BIN=./result/bin/provekit-cli node fundraise-demo-runner/bin/fundraise-demo.mjs
```

The output is JSON suitable for the presentation: proof digest, verifier-key
digest, workflow receipt, and the settlement action that needs an authorizer
signature before on-chain settlement.
