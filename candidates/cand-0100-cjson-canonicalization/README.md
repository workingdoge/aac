# cand-0100-cjson-canonicalization

Intent: 2/FACT completion: pin cjson/1 canonical bytes + author TypeDecl documents (closes the cand-0099 obstruction)

Status: open (pre-threshold).

## Cargo

- `seeds/sites/ledger/specs/2/README.md` preserves the existing cjson/1
  key-order and integer pins, adds only the control-character escape spelling
  and a not-RFC-8785/JCS clarification, and completes the TypeDecl object
  grammar/location.
- `seeds/sites/ledger/specs/2/reference/cjson1_encode.py` is the cited
  reference encoder for cjson/1 and `sha256/1(enc(TypeDecl))`.
- `seeds/sites/ledger/specs/2/type-declarations/*.json` adds canonical
  TypeDecl documents for `cjson/1`, `sha256/1`, `d2f-31be/1`,
  `uh-bn254/1`, `name-ens/1`, and `data-walrus/1`.
- `seeds/sites/ledger/specs/2/vectors/*.json` adds escape, UTF-8-byte
  key-order, arbitrary-precision integer, and TypeDecl typeId vectors.
- `seeds/sites/ledger/specs/registers/R1.md` records the six computed
  `sha256:<hex>` identities and leaves `uh-wrap-groth16/1` reserved without
  a deployed identity assignment.
- `seeds/candidates/QUEUE.md` queue-merges the cand-0099 obstruction entry to
  resolved.

No `tools/**` or premath law-spine cargo is landed by this candidate.

## Optional RLM Trace Evidence

When model-assisted or large-context reasoning materially supports this candidate,
keep that support in checking mode: generate an explicit trace with
`tools/eval/rlm-trace-from-candidate.sh`, check it with
`sites/eval/realizations/rlm-trace-profile-check/rlm-trace-profile-check.sh`,
and store the JSONL plus checker output under `traces/` before attestation.
A passing RLM trace is evidence only; it does not grant answer authority,
KB admission, Boat candidate admission, Harbor readiness, live LLM calls,
provider calls, network access, shell access, or secret access.
