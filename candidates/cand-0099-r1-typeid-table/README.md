# cand-0099-r1-typeid-table

Intent: Compute R1's typeId table + 2/FACT canonical-encoding vectors (every cross-thread TypedFact depends on this)

Status: open (pre-threshold).

## Stop Finding

This candidate does not compute R1 typeIds and does not add a `cjson/1`
reference encoder. The requested output is blocked by two byte-identity gaps in
the current source:

- 2/FACT section 2 says strings are JSON strings with mandatory escaping of
  quotes, backslashes, and control characters, with no other escaping. It does
  not choose the JSON spelling for control characters. For example, a newline
  string can be encoded as `"\n"` or `"\u000a"`; both escape the control
  character and use no unrelated escape, but they produce different bytes.
- 2/FACT section 3 defines type identity as `typeId := H(enc(TypeDecl))`, but
  only sketches `TypeDecl := { kind, name?, version, schema, ... }`. The repo
  has no byte-canonical TypeDecl documents for the R1 handles `cjson/1`,
  `sha256/1`, `d2f-31be/1`, `uh-bn254/1`, `uh-wrap-groth16/1`,
  `name-ens/1`, or `data-walrus/1`.
- R1 therefore still contains `_tbd_` rows. Replacing them now would bind
  arbitrary declaration bytes rather than digesting authored declarations.

Per the cargo instruction, this candidate stops and records the obstruction in
the queue instead of inventing canonical bytes.

## Boundary

No live `sites/` or `tools/` files are edited. The only landing material is a
`candidates/QUEUE.md` merge seeded from `QUEUE.base`.

Status: open (pre-threshold).

## Optional RLM Trace Evidence

When model-assisted or large-context reasoning materially supports this candidate,
keep that support in checking mode: generate an explicit trace with
`tools/eval/rlm-trace-from-candidate.sh`, check it with
`sites/eval/realizations/rlm-trace-profile-check/rlm-trace-profile-check.sh`,
and store the JSONL plus checker output under `traces/` before attestation.
A passing RLM trace is evidence only; it does not grant answer authority,
KB admission, Boat candidate admission, Harbor readiness, live LLM calls,
provider calls, network access, shell access, or secret access.
