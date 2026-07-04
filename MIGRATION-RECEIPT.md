# Migration receipt: aac dependency mode

```text
MigrationReceipt:
  schema: boat.migration.v0
  migrated_at: 2026-07-04T14:54:43Z
  law: premath.workspace-kernel-bundle.v0 (connection clause)
  from: copy-mode
  to: dependency-mode
  kernel_source: /Users/arj/irai/loop
  kernel_rev_pinned: 932d0d408273d26e2a818dbad91e1af7828e2480
  kernel_rev_live: 932d0d408273d26e2a818dbad91e1af7828e2480
  kernel_store: /nix/store/jqpccf1g85b5kpdv89c8vin71f8i91bc-loop-kernel-export
  removed: 196 file(s)
  shim: tools/loop
  shim_sha256: 439f7640157c01c6c87394cd4b9c129595d0bbbc318e21973a8ce932dfe1d4d7
  preserved_souls:
    - tools/schemas/instance.tsv
    - tools/schemas/kernel-adaptations.tsv
  verification_boundary: migrate-to-dependency.sh with nix build .#kernelStore or BOAT_KERNEL_STORE fallback
  follow_up: loop-side bundle-base.tsv mode flip is a separate loop-side change
```
