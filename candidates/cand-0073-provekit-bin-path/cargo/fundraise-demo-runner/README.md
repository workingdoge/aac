# Fundraise Demo Runner

This package runs the real demo path for the fundraising story:

1. load the canonical `FUNDRAISE-DEMO-1` packet;
2. copy `world-app/provekit-vnet` to a temporary work directory;
3. run the native ProveKit CLI `prepare`, `prove`, and `verify` flow;
4. build a live-proof verifier receipt;
5. run `fundraise-workflow` with `require_live_proof: true`;
6. emit the pending `FundraiseMintSettlement.settle(auth, signature)` action;
7. attach a compact summary artifact for presentation and UI callers.

The default mode does not sign the authorizer request, submit a transaction,
deploy contracts, or verify a recursive proof on-chain. Those are explicit
deployment steps.

```sh
nix build .#provekit
PROVEKIT_BIN=./result/bin/provekit-cli node fundraise-demo-runner/bin/fundraise-demo.mjs
```

`PROVEKIT_BIN` may be an executable name on `PATH`, an absolute path, or a
repo-relative path like `./result/bin/provekit-cli`. The runner resolves
path-like relative values against `--repo-root` before copying the circuit into
its temporary proving directory.

The output is JSON suitable for the presentation: proof digest, verifier-key
digest, workflow receipt, and the settlement action that needs an authorizer
signature before on-chain settlement.

For a smaller presentation/UI artifact, use:

```sh
nix build .#provekit
PROVEKIT_BIN=./result/bin/provekit-cli node fundraise-demo-runner/bin/fundraise-demo.mjs --summary
```

The summary is a deterministic projection of the receipt. It includes the round,
issuer, public roots/commitments, ProveKit proof digest, workflow digests,
settlement status, balances when available, and an explicit caveat that the
current settlement contract verifies the authorizer signature and replay guard;
production recursive/on-chain VNET proof verification remains a separate target.

## Local Settlement

With a local Anvil node running, the runner can also deploy the demo settlement
contracts, sign the contract digest with a demo authorizer key, submit
`settle(auth, signature)`, and read token balances back:

```sh
anvil
nix build .#provekit
PROVEKIT_BIN=./result/bin/provekit-cli \
  node fundraise-demo-runner/bin/fundraise-demo.mjs \
    --settle-local \
    --summary \
    --rpc-url http://127.0.0.1:8545 \
    --forge-bin "$(command -v forge)" \
    --cast-bin "$(command -v cast)" \
    --solc-bin "$(command -v solc)"
```

This is still a local demo path. It uses deterministic Anvil/development keys by
default, signs the on-chain settlement digest with `cast wallet sign --no-hash`,
does not deploy to a public testnet, and does not replace a production
recursive/on-chain VNET proof verifier.
