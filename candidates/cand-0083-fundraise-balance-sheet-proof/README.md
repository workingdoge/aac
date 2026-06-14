# cand-0083-fundraise-balance-sheet-proof

Intent: Add a live ProveKit balance-sheet before/after proof to the fundraise demo, tied to the selected batch.

Status: evaluated.

## Cargo

This candidate adds a separate ProveKit app package at
`world-app/provekit-balance-sheet` and wires the fundraise demo runner to prove
it after the selected VNET batch proof.

The runner now:

- computes dynamic previous/next balance-sheet roots from the selected fill;
- writes a batch-specific `Prover.toml` into the temporary ProveKit workdir;
- runs `prepare/prove/verify` for the balance-sheet circuit;
- returns a distinct `balance_sheet` verifier summary with proof digest,
  receipt digest, public-input commitment, roots, and row deltas.

The web component renders that receipt as a separate "Before/after state proof"
card in the private-books lane. The main VNET verifier remains the batch-clearing
receipt used by the workflow authorization.

## Boundary

The balance-sheet circuit proves state arithmetic and root consistency for the
selected batch. It does not prove the starting balance sheet is externally true;
production use still needs an anchored prior root, auditor signature, registry
log, or equivalent truth source.

## Evidence

`eval-self.sh` passed 6/6:

- source wiring for dynamic balance-sheet roots and verifier receipt;
- runner tests for preview/run summaries and 30-unit partial fill roots;
- Noir beta.19 tests for the new balance-sheet package;
- stale-next-root mutant rejected;
- Astro fundraise page build with the state-proof card bundled;
- landing scope limited to runner, fundraise page/data/docs, and the new
  ProveKit app package.

`scores.json` is attested: `e34b1ae5aad7`.
