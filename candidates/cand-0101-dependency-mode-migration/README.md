# cand-0101-dependency-mode-migration

Intent: migrate this instance from kernel-by-copy to dependency-mode using the kcir pilot shape

Status: open (pre-threshold).

## Cargo

- `seeds/flake.nix` amends the existing AAC flake with the local Loop input
  and a `packages.${system}.kernelStore` output that points at
  `loop.packages.${system}.kernelExport`.
- `seeds/flake.lock` adds only the `loop` node and root input edge, preserving
  the existing lock graph and pinning Loop to
  `932d0d408273d26e2a818dbad91e1af7828e2480`.
- `seeds/migrate-to-dependency.sh` is the operator-run migration script,
  ported from KCIR's live repaired version with AAC receipt labels.

This candidate does not run the migration. It lands the machinery and dry-runs
the migration logic in scratch instances only.

## POST-LAND

Run the migration from the repo root:

```sh
bash migrate-to-dependency.sh
```

Expected receipt:

```sh
test -f MIGRATION-RECEIPT.md
grep -Fx 'MigrationReceipt:' MIGRATION-RECEIPT.md
grep -Fx '  schema: boat.migration.v0' MIGRATION-RECEIPT.md
grep -Fx '  to: dependency-mode' MIGRATION-RECEIPT.md
grep -Fx '  shim: tools/loop' MIGRATION-RECEIPT.md
grep -Fx '  preserved_souls:' MIGRATION-RECEIPT.md
```

Lock-bump sanity:

```sh
kernel_store="$(awk -F': ' '$1 == "  kernel_store" { print $2; exit }' MIGRATION-RECEIPT.md)"
bash "$kernel_store/tools/lock-bump.sh" . --dry-run
```

Verification commands:

```sh
bash tools/loop status
bash tools/loop status cand-0101-dependency-mode-migration
git status --short
```

## Optional RLM Trace Evidence

When model-assisted or large-context reasoning materially supports this candidate,
keep that support in checking mode: generate an explicit trace with
`tools/eval/rlm-trace-from-candidate.sh`, check it with
`sites/eval/realizations/rlm-trace-profile-check/rlm-trace-profile-check.sh`,
and store the JSONL plus checker output under `traces/` before attestation.
A passing RLM trace is evidence only; it does not grant answer authority,
KB admission, Boat candidate admission, Harbor readiness, live LLM calls,
provider calls, network access, shell access, or secret access.
