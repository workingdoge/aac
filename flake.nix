{
  description = "A boat-governed project: every change is a candidate";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    flake-utils.url = "github:numtide/flake-utils";
    # The source instance this project's governance kernel exports from.
    # Local-path pin (hackathon-speed); swap for a published ref when
    # boat publishes beyond this host.
    boat.url = "git+file:///Users/arj/irai/boat";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      boat,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        # One-shot governance bootstrap (refuses re-init):
        #   nix run .#init -- --goal "the worldly goal"
        # boat-init materializes the kernel into ./tools + ./sites,
        # seeds candidates/QUEUE.md with the goal, and fails closed
        # unless the loop-model conformance differential is green
        # INSIDE this repo.
        apps.init = {
          type = "app";
          program = toString (
            pkgs.writeShellScript "boat-project-init" ''
              exec ${boat.packages.${system}.boat-kernel}/bin/boat-init . "$@"
            ''
          );
        };

        devShells.default = pkgs.mkShell {
          packages = [
            pkgs.bash
            pkgs.coreutils
            pkgs.gnugrep
            pkgs.gnused
            pkgs.gawk
            pkgs.findutils
            pkgs.python3
            pkgs.git
            pkgs.jq
            pkgs.shellcheck
            # Lean toolchain manager for the ledger site's proof. elan reads
            # sites/ledger/statements/lean-toolchain and provisions Lean
            # v4.28.0 on first use; mathlib oleans come from `lake exe cache
            # get`, never a from-source rebuild. See sites/ledger/statements/.
            pkgs.elan
          ];
          shellHook = ''
            if [ ! -f tools/loop ]; then
              echo "ungoverned tree — bootstrap with:"
              echo "  nix run .#init -- --goal \"the worldly goal\""
            else
              echo "boat-governed project"
              echo "  contract: WORKER.md"
              echo "  backlog:  candidates/QUEUE.md"
              echo "  runner:   tools/loop"
            fi
            echo "verify the Lean spec (machine-checked, zero sorries):"
            echo "  (cd sites/ledger/statements && lake exe cache get && lake build)"
          '';
        };
      }
    );
}
