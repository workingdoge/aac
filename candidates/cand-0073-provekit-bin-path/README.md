# cand-0073-provekit-bin-path

Intent: Resolve relative ProveKit binary paths before the demo runner switches into the temp circuit workdir.

Status: open (pre-threshold).

Boundary:

- Resolves path-like relative `--provekit-bin` / `PROVEKIT_BIN` values against
  `--repo-root` before the runner switches into the temporary ProveKit circuit
  directory.
- Leaves plain executable names such as `provekit-cli` untouched so `PATH`
  lookup still works.
- Does not change the ProveKit adapter's direct-call semantics or the circuit.
