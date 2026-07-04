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

## LockBumpReceipt 2026-07-04T17:28:16Z

```text
LockBumpReceipt:
  schema: boat.lock-bump.v0
  ts: 2026-07-04T17:28:16Z
  from-rev: 932d0d408273d26e2a818dbad91e1af7828e2480
  to-rev: bf9bb38059226d6f4f00d0b656dfe0bde126e9e0
  store-path: /nix/store/n0sm5zd80fqnfbql3gl9g2kww0x8jd59-loop-kernel-export
  shim: tools/loop
  shim-changed: y
  shim-installed-sha256-before: 439f7640157c01c6c87394cd4b9c129595d0bbbc318e21973a8ce932dfe1d4d7
  shim-template-sha256: a01989a8dfa0b32264b5dda663da1fdb20b0c476783764d34c1d77eaa72ed2b7
  shim-installed-sha256-after: a01989a8dfa0b32264b5dda663da1fdb20b0c476783764d34c1d77eaa72ed2b7
  verification-boundary: tools/lock-bump.sh; store materializer command recorded by operator environment
```
