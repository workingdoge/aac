# Fundraise Demo Runner

This package runs the real demo path for the fundraising story:

1. load the canonical `FUNDRAISE-DEMO-1` packet;
2. copy `world-app/provekit-vnet` to a temporary work directory;
3. generate `Prover.toml` from the packet's `vnet_link` witness fields;
4. verify the generated circuit public inputs against that packet-derived
   witness before proving;
5. run the native ProveKit CLI `prepare`, `prove`, and `verify` flow;
6. build a live-proof verifier receipt;
7. run `fundraise-workflow` with `require_live_proof: true`;
8. emit the pending `FundraiseMintSettlement.settle(auth, signature)` action;
9. attach a compact summary artifact for presentation and UI callers.

The VNET ProveKit package is the cand-0095 fixed demo circuit:
`N_ATOMS=2`, `N_BASIS=3`, basis `["USD", "fabric", "shares"]`, and
`context_commitment_pub=9001`. The runner fails closed when a packet does not
match that shape, profile, basis, transition-row width, account domain, or
aggregate opening. The current `FUNDRAISE-DEMO-1` packet is a
`vnet-bn254-g1/1` four-atom USDC/SAFE fixture, so the runner refuses it instead
of padding, projecting, or proving an unrelated static witness. A fundraise
shaped circuit/profile remains the follow-up integration work.

Per PC-1.5.2, the opaque boundary is flipped to the circuit side: the verifier
receipt records the packet commitment, the fundraise packet public-input
digest, the packet `vnet_link` digest, and the cand-0095 circuit public-input
digest derived for the proof. `require_live_proof: true` is therefore no longer
satisfied by a proof over data unrelated to the packet.

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
