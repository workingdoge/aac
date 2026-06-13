# AAC — proof-native double-entry accounting

AAC is a double-entry accounting system in which **balance is a proof, not a
promise**. Entities keep private books, publish provable balanced-claim roots
at names, and anchor ledger roots in a registry that **refuses unbalanced
state**. The core insight is algebraic: double-entry bookkeeping *is* the
Grothendieck group K(M) of amount vectors — and that identity is what lets a
ledger's integrity be checked in zero knowledge.

This repository is the specification suite, its machine-checked formal core,
and the governance loop through which the implementation lands.

## What's here

| Path | What it is |
|------|------------|
| [`rfc/`](rfc/README.md) | The specification suite — RFCs 1–8 (PACI, FACT, PROOF, REG, NET, NAME, DATA, SESS) + 12/OTC, the root registry, and registers. Prescriptive: implementations conform to the specs, not the other way round. |
| [`verification/`](verification/README.md) | The formal core. [`Core.lean`](verification/Core.lean) formalizes the K(M) semantics and **machine-checks against mathlib (Lean v4.28.0) with zero `sorry`**; [`k-properties.ts`](verification/k-properties.ts) is the differential property harness (7,488 checks against an independent reference model). |

The keystone result is `pacioli_equal_field_sound` (and its N-row
generalization): under u64 amount bounds, BN254 field-equality of cross-sums
reflects real ℕ equality — the carrier-injectivity obligation (3/PROOF §3)
that a zk circuit's range checks must discharge. *"Soundness is this
injectivity."*

## Verify the formal core

Requires [Nix](https://nixos.org). From this directory:

```sh
nix develop                    # provides elan (the Lean toolchain manager)
cd verification
lake exe cache get             # downloads prebuilt mathlib oleans (minutes, no source build)
lake build                     # elaborates Core.lean — success ⟺ zero open obligations
```

See [verification/README.md](verification/README.md) for the full
lemma-to-RFC map and reproducibility notes.

## Status

All RFCs are **Raw** (the suite's earliest lifecycle stage). The core
*semantics* (1/PACI §2–§5) are machine-checked; the **Noir circuit
implementation** and the constraint-level Lean binding (Clean `FormalCircuit`)
are in progress. The lifecycle gates are defined in
[rfc/README.md](rfc/README.md): Raw→Draft requires executable conformance for
every MUST; Draft→Stable requires a formal companion for every
soundness-bearing MUST with no open obligation.

## Governance (boat)

This repo is governed by an exported instance of the **boat** development
loop: **every change is a candidate** — evaluated against attested evidence,
briefed, reviewed where it touches the verifier set, and gated before it
lands. Acceptance is *discharge-determined, never proposal-determined*: what a
proposer claims carries no authority; what the verifiers discharge does. The
project's own source — RFCs, circuits, proofs — lands through candidates like
everything else; what survives the gates is what the project IS.

The instance was born here (see [`EXPORT-RECEIPT.md`](EXPORT-RECEIPT.md)) with
the loop-model conformance differential **green inside this repo** — the proof
that the transported loop still is the loop.

```sh
# Read the contract first — it is binding:
cat WORKER.md

# One iteration of the loop:
bash tools/loop open cand-0001-name "intent"
# build cargo + eval-self.sh in the candidate dir; attest evidence
bash tools/loop validate cand-0001-name
bash tools/loop brief cand-0001-name
bash tools/loop auto cand-0001-name --agent your-name

# Or dispatch a bounded worker at the queue top:
bash tools/loop dispatch --agent your-name
```

- Contract: [`WORKER.md`](WORKER.md)
- Backlog: [`candidates/QUEUE.md`](candidates/QUEUE.md) (seeded with the project goal)
- Runner: `tools/loop` · Law spine: `sites/premath/specs/`
- The shell: `nix develop` provides the kernel toolchain and the Lean tooling.

## License

Specification text (`rfc/`) is licensed **GPL-3.0-or-later**; implementation
code is licensed independently. Process: 1/C4 and 2/COSS of
<https://rfc.unprotocols.org> are adopted by reference.
