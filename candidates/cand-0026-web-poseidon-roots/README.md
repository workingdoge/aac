# cand-0026-web-poseidon-roots

The **cand-0024 cascade, part 2** (final). The Poseidon2 migration changed every
commitment value; the web components still displayed the old *pedersen* roots.
This updates them so `/circuit` and `/registry` show the live proof.

## What changed

- `aac-transition.ts` — the TRANSITION/1 proof receipt: `prevAccount`,
  `nextAccount`, `nextNull`, `journal`, `factFold` → the new Poseidon2 values;
  `opcodes` 775 → 673. (`prevNull` 0x64, `context` 0x2a, `factCount` 1 are
  pass-through inputs, unchanged.)
- `aac-row.ts` — the 4/REG row receipt: `prevAccount`, `nextAccount`, `nextNull`
  → the new values.
- `circuit.mdx` — the regeneration note: `~775` → `~673` ACIR opcodes.

These are the same values `nargo execute` solves and the registry's regenerated
verifiers (cand-0025) consume — the UI, the circuit, and the chain now agree.

## Evidence (`eval-self.sh`, attested)

- values — the components carry the new Poseidon2 roots + `opcodes 673`, and no
  stale pedersen value remains anywhere in the cargo.
- build — `astro build` green (16 pages); the new root is bundled into the Lit
  JS, **no** stale pedersen value appears anywhere in `dist/`, and `/circuit`
  renders `673 ACIR opcodes`.

This closes the Poseidon2 cascade (cand-0024 circuits → cand-0025 registry →
cand-0026 web): circuit, verifier, and UI are coherent end to end.

Status: open (pre-threshold).
