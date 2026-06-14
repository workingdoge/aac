# AAC fundraise balance-sheet ProveKit circuit

This package proves the before/after issuer book row used by the fundraise demo.
It is a presentation-target ProveKit package, not a replacement for
TRANSITION/1.

The circuit proves:

- the public previous balance-sheet root opens to the private starting row;
- the selected settlement amount and issued-unit total are applied to that row;
- the public next balance-sheet root opens to the resulting private row;
- the proof is bound to the selected fundraise packet commitment.

The commitment function is a small deterministic demo commitment so the browser
runner can compute roots without adding beta.19 hash dependencies. It proves
state arithmetic and root consistency for the demo. It does not prove that the
starting balance sheet is externally true; production use still needs a prior
registry root, auditor signature, append-only log, or equivalent anchoring
surface.

Run with the flake-provided beta.19 toolchain:

```sh
nix run .#nargo19 -- test --show-output world-app/provekit-balance-sheet
```

The fundraise runner copies this package into a temporary directory, writes a
batch-specific `Prover.toml`, then calls `provekit-cli prepare/prove/verify`.
