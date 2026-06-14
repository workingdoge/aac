# cand-0030-kernel-app-decouple

Intent: Sever the kernel->app back-edge: remove the rulebook (application schema) dependency from the enshrined transition + nullify circuits -- it is test-only, the proven main is already schema-agnostic. transition keeps pacioli+ledger+hash; nullify drops to hash only. The transition composition test uses the literal Pn conformance vector (a fixture) and an opaque nullifier instead of compile_goods_receipt_invoice/event_nullifier; nullify anti-replay tests use opaque field values. nargo test green workspace-wide; a structural probe witnesses the kernel crates carry no app refs. Enforces 4/REG S5 (base MUST NOT require an application target) at the crate level. Circuits-only, no tier-guard.

Status: open (pre-threshold).
