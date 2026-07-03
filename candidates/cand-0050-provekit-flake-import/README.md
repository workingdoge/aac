# cand-0050-provekit-flake-import

Import the ProveKit CLI flake package from the main worktree into the
`codex/vnet-fundraising` worktree so the fundraising demo can use the same
`nix build .#provekit` entrypoint Claude proved locally.

The candidate intentionally carries only root flake packaging plus ignore
hygiene for generated ProveKit key/proof artifacts. It does not import main's
dirty generated files and does not change any circuit, spec, workflow, or
contract semantics.

Intent: import ProveKit flake package from main into vnet fundraising workspace

Status: open (pre-threshold).
