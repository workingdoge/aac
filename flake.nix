{
  description = "A boat-governed project: every change is a candidate";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    # The source instance this project's governance kernel exports from.
    # Local-path pin (hackathon-speed); swap for a published ref when
    # boat publishes beyond this host.
    boat.url = "git+file:///Users/arj/irai/boat";
    # paintgun: DTCG 2025.10 design-token compiler/verifier (the `paint`
    # CLI) for the AAC design system + spec-publication packs. Published,
    # reproducible pin.
    paintgun.url = "github:workingdoge/paintgun/v0.1.0";
    # Noir workspace toolchain.
    # Adapted from the flake fragment supplied in this 2026-06-13 change
    # request; the upstream source pins are the canonical releases/tags below.
    bb-bin = {
      url = "https://github.com/AztecProtocol/aztec-packages/releases/download/v2.1.8/barretenberg-amd64-linux.tar.gz";
      flake = false;
    };
    noir-src = {
      url = "github:noir-lang/noir/v1.0.0-beta.14";
      flake = false;
    };
    co-snarks-src = {
      url = "github:TaceoLabs/co-snarks/co-noir-v0.7.0";
      flake = false;
    };
    bignum-paramgen-src = {
      url = "github:noir-lang/noir-bignum-paramgen";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      boat,
      paintgun,
      bb-bin,
      noir-src,
      co-snarks-src,
      bignum-paramgen-src,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        lib = pkgs.lib;

        isX86Linux = system == "x86_64-linux";

        bb = pkgs.stdenv.mkDerivation rec {
          pname = "barretenberg";
          version = "v2.1.8";
          src = bb-bin;
          nativeBuildInputs = with pkgs; [
            autoPatchelfHook
            stdenv.cc.cc
          ];
          installPhase = ''
            runHook preInstall
            mkdir -p $out/bin
            cp bb $out/bin
            runHook postInstall
          '';
          meta = {
            description = "Barretenberg (or bb for short) is an optimized elliptic curve library for the bn128 curve, and a PLONK SNARK prover.";
            homepage = "https://barretenberg.aztec.network/docs/";
            license = lib.licenses.asl20;
            platforms = [ "x86_64-linux" ];
            maintainers = [ ];
          };
        };

        noir-src-patched = pkgs.stdenv.mkDerivation rec {
          pname = "noir-src-patched";
          version = "v1.0.0-beta.14";
          src = noir-src;
          cargoHash = "sha256-ZIW54tBlqjMb/Je8+4vpUMOGL8BEimMf24GrVTbB76g=";
          patchPhase = ''
            sed -e '2d;12,13d;16,$d' -i compiler/noirc_driver/build.rs
          '';
          dontConfigure = true;
          dontBuild = true;
          doCheck = false;
          installPhase = ''
            mkdir -p $out
            cp -r ./* $out
          '';
          meta = {
            description = "Noir is a domain specific language for zero knowledge proofs.";
            homepage = "https://noir-lang.org/";
            license = lib.licenses.mit;
            platforms = lib.platforms.unix;
            maintainers = [ ];
          };
        };

        noir = pkgs.rustPlatform.buildRustPackage (finalAttrs: {
          pname = "noir";
          version = "v1.0.0-beta.14";
          src = noir-src-patched;
          cargoHash = "sha256-ZIW54tBlqjMb/Je8+4vpUMOGL8BEimMf24GrVTbB76g=";
          preBuild = ''
            export GIT_COMMIT=60ccd48e18ad8ce50d5ecda9baf813b712145051
            export GIT_DIRTY=false
          '';
          doCheck = false;
          meta = {
            description = "Noir is a domain specific language for zero knowledge proofs (patched source).";
            homepage = "https://noir-lang.org/";
            license = lib.licenses.mit;
            platforms = lib.platforms.unix;
            maintainers = [ ];
          };
        });

        co-snarks = pkgs.rustPlatform.buildRustPackage (finalAttrs: {
          pname = "co-snarks";
          version = "co-noir-v0.7.0";
          src = co-snarks-src;
          cargoHash = "sha256-yY9LrmKVBAgNhyhazG1Z42NIPmrCghw4p5pDUjdHmoU=";
          patchPhase = ''
            export GIT_COMMIT=60ccd48e18ad8ce50d5ecda9baf813b712145051
            export GIT_DIRTY=false
            mkdir -p /build/noir
            cp -r ${noir-src-patched}/* /build/noir/
            sed -e '/^acir =/d' \
                -e '/^acvm =/d' \
                -e '/^brillig =/d' \
                -e '/^noirc-abi =/d' \
                -e '/^noirc-artifacts =/d' \
                -e '87aacir = { path = "/build/noir/acvm-repo/acir" }' \
                -e '87aacir_field = { path = "/build/noir/acvm-repo/acir_field" }' \
                -e '87aacvm = { path = "/build/noir/acvm-repo/acvm" }' \
                -e '87aacvm_js = { path = "/build/noir/acvm-repo/acvm_js" }' \
                -e '87ablackbox_solver = { path = "/build/noir/acvm-repo/blackbox_solver" }' \
                -e '87abn254_blackbox_solver = { path = "/build/noir/acvm-repo/bn254_blackbox_solver" }' \
                -e '87abrillig = { path = "/build/noir/acvm-repo/brillig" }' \
                -e '87abrillig_vm = { path = "/build/noir/acvm-repo/brillig_vm" }' \
                -e '87afm = { path = "/build/noir/compiler/fm" }' \
                -e '87anoirc_arena = { path = "/build/noir/compiler/noirc_arena" }' \
                -e '87anoirc_driver = { path = "/build/noir/compiler/noirc_driver" }' \
                -e '87anoirc_errors = { path = "/build/noir/compiler/noirc_errors" }' \
                -e '87anoirc_evaluator = { path = "/build/noir/compiler/noirc_evaluator" }' \
                -e '87anoirc_frontend = { path = "/build/noir/compiler/noirc_frontend" }' \
                -e '87anoirc_printable_type = { path = "/build/noir/compiler/noirc_printable_type" }' \
                -e '87anoirc_span = { path = "/build/noir/compiler/noirc_span" }' \
                -e '87awasm = { path = "/build/noir/compiler/wasm" }' \
                -e '87aacvm_cli = { path = "/build/noir/tooling/acvm_cli" }' \
                -e '87aartifact_cli = { path = "/build/noir/tooling/artifact_cli" }' \
                -e '87aast_fuzzer = { path = "/build/noir/tooling/ast_fuzzer" }' \
                -e '87afuzz = { path = "/build/noir/tooling/ast_fuzzer/fuzz" }' \
                -e '87adebugger = { path = "/build/noir/tooling/debugger" }' \
                -e '87agreybox_fuzzer = { path = "/build/noir/tooling/greybox_fuzzer" }' \
                -e '87ainspector = { path = "/build/noir/tooling/inspector" }' \
                -e '87alsp = { path = "/build/noir/tooling/lsp" }' \
                -e '87anargo = { path = "/build/noir/tooling/nargo" }' \
                -e '87anargo_cli = { path = "/build/noir/tooling/nargo_cli" }' \
                -e '87anargo_expand = { path = "/build/noir/tooling/nargo_expand" }' \
                -e '87anargo_fmt = { path = "/build/noir/tooling/nargo_fmt" }' \
                -e '87anargo_fuzz_target = { path = "/build/noir/tooling/nargo_fuzz_target" }' \
                -e '87anargo_toml = { path = "/build/noir/tooling/nargo_toml" }' \
                -e '87anoirc_abi = { path = "/build/noir/tooling/noirc_abi" }' \
                -e '87anoirc_abi_wasm = { path = "/build/noir/tooling/noirc_abi_wasm" }' \
                -e '87anoirc_artifacts = { path = "/build/noir/tooling/noirc_artifacts" }' \
                -e '87anoirc_artifacts_info = { path = "/build/noir/tooling/noirc_artifacts_info" }' \
                -e '87aprofiler = { path = "/build/noir/tooling/profiler" }' \
                -e '87assa_cli = { path = "/build/noir/tooling/ssa_cli" }' \
                -e '87assa_executor = { path = "/build/noir/tooling/ssa_executor" }' \
                -e '87assa_fuzzer = { path = "/build/noir/tooling/ssa_fuzzer" }' \
                -e '87afuzzer = { path = "/build/noir/tooling/ssa_fuzzer/fuzzer" }' \
                -e '87assa_verification = { path = "/build/noir/tooling/ssa_verification" }' \
                -e '87aiter-extended = { path = "/build/noir/utils/iter-extended" }' \
                -e '87aprotobuf = { path = "/build/noir/utils/protobuf" }' \
                -i Cargo.toml
            sed -e 's/noirc-abi/noirc_abi/g' \
                -e 's/noirc-artifacts/noirc_artifacts/g' \
                -i co-noir/{co-acvm,co-noir,noir-types}/Cargo.toml tests/Cargo.toml
          '';
          doCheck = false;
          meta = {
            description = "Tooling for creating collaborative SNARKs for Circom and Noir circuits.";
            homepage = "https://docs.taceo.io/";
            license = lib.licenses.mit;
            platforms = lib.platforms.linux;
            maintainers = [ ];
          };
        });

        bignum-paramgen = pkgs.rustPlatform.buildRustPackage (finalAttrs: {
          pname = "noir-bignum-paramgen";
          version = "main";
          src = bignum-paramgen-src;
          cargoHash = "sha256-Z1RE1nbICtaVC2/xMBDA5k6R3ADMijMWRedAwbvd4Pw=";
          doCheck = false;
          meta = {
            description = "Parameter generation tool for noir-bignum";
            mainProgram = "paramgen";
            homepage = "https://github.com/noir-lang/noir-bignum-paramgen";
            license = lib.licenses.asl20;
            maintainers = [ ];
          };
        });

        noirToolchainPackages =
          [
            noir
            bignum-paramgen
            pkgs.clang
            pkgs.llvmPackages.bintools
            pkgs.rustup
          ]
          ++ lib.optionals (pkgs.stdenv.isLinux && pkgs ? circom) [
            pkgs.circom
          ]
          ++ lib.optionals pkgs.stdenv.isLinux [
            co-snarks
          ]
          ++ lib.optionals isX86Linux [
            bb
          ];
      in
      {
        packages =
          {
            default = noir;
            inherit noir bignum-paramgen;
          }
          // lib.optionalAttrs pkgs.stdenv.isLinux {
            inherit co-snarks;
          }
          // lib.optionalAttrs isX86Linux {
            inherit bb;
          };

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
            # paint: DTCG token-pack compiler/verifier for the design system.
            paintgun.packages.${system}.default
          ] ++ noirToolchainPackages;
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
            if command -v nargo >/dev/null 2>&1; then
              nargo --version | grep -v 'git version hash'
            fi
            if command -v co-noir >/dev/null 2>&1; then
              co-noir --version
            fi
            if command -v bb >/dev/null 2>&1; then
              echo "bb $(bb --version)"
            fi
          '';
        };
      }
    );
}
