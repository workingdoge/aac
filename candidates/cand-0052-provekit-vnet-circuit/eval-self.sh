#!/usr/bin/env bash
# eval-self.sh -- functional evidence for cand-0052-provekit-vnet-circuit.
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"
PKG="$CAND_DIR/cargo/world-app/provekit-vnet"
TRACES="$CAND_DIR/traces"
WORK="$(mktemp -d /private/tmp/aac-vnet-eval.XXXXXX)"
RUN_PKG="$WORK/provekit-vnet"
rm -rf "$TRACES"; mkdir -p "$TRACES"

# tools/eval/attest.sh uses GNU `head -n -1`. On BSD/macOS, provide the exact
# behavior to the child bash process without modifying the verifier-set tool.
head() {
  if [[ "${1:-}" == "-n" && "${2:-}" == "-1" && $# -eq 3 ]]; then
    awk 'NR > 1 { print prev } { prev = $0 }' "$3"
  else
    command head "$@"
  fi
}
export -f head

NARGO19_BIN="${NARGO19_BIN:-}"
PROVEKIT_BIN="${PROVEKIT_BIN:-}"

resolve_toolchain() {
  local p
  if [[ -z "$NARGO19_BIN" ]]; then
    while IFS= read -r p; do
      case "$p" in
        *-nargo-v1.0.0-beta.19/bin/nargo) NARGO19_BIN="$p"; break ;;
      esac
    done < <(find /nix/store -maxdepth 4 -path '*/bin/nargo' -type f 2>/dev/null | sort)
  fi
  if [[ -z "$PROVEKIT_BIN" ]]; then
    while IFS= read -r p; do
      case "$p" in
        *-provekit-cli-1.0.0/bin/provekit-cli) PROVEKIT_BIN="$p"; break ;;
      esac
    done < <(find /nix/store -maxdepth 4 -path '*/bin/provekit-cli' -type f 2>/dev/null | sort)
  fi

  [[ -x "$NARGO19_BIN" ]] || { echo "nargo19 binary not found in /nix/store"; return 1; }
  [[ -x "$PROVEKIT_BIN" ]] || { echo "provekit-cli binary not found in /nix/store"; return 1; }
  "$NARGO19_BIN" --version
  "$PROVEKIT_BIN" --help | head -n 1
}

check_structure() {
  local f="$1" bad=0
  grep -q 'std::hash::derive_generators("AAC_PEDERSEN_VECTOR_VNET_1".as_bytes(), 0)' "$f" \
    || { echo "missing domain-separated derived generator set"; bad=1; }
  ! grep -q 'EmbeddedCurvePoint::generator()' "$f" \
    || { echo "uses base generator demo path"; bad=1; }
  grep -q 'multi_scalar_mul' "$f" || { echo "missing MSM primitive"; bad=1; }
  ! grep -q 'embedded_curve_add' "$f" || { echo "uses point-addition primitive"; bad=1; }
  grep -q 'generator_set_id_pub == generator_set_id()' "$f" \
    || { echo "missing generator-set public pin"; bad=1; }
  grep -q 'transition_set_commitment_pub == transition_set_commitment' "$f" \
    || { echo "missing transition-set public linkage"; bad=1; }
  grep -q 'journal commitment does not match atom vector' "$f" \
    || { echo "missing per-atom journal link rejection"; bad=1; }
  grep -q 'aggregate opening x mismatch' "$f" \
    || { echo "missing claimed aggregate opening check"; bad=1; }
  grep -q 'aggregate opening is not a pure blinding commitment' "$f" \
    || { echo "missing pure-blinding zero-opening check"; bad=1; }
  grep -q 'basis dimension does not net to zero' "$f" \
    || { echo "missing per-basis zero-net check"; bad=1; }
  grep -q 'coordinate exceeds PEDERSEN-VECTOR/1 profile bound' "$f" \
    || { echo "missing bounded-coordinate check"; bad=1; }
  grep -q 'rejects_bad_opening' "$f" || { echo "missing bad-opening vector"; bad=1; }
  grep -q 'rejects_mismatched_transition_link' "$f" \
    || { echo "missing mismatched-transition vector"; bad=1; }
  grep -q 'rejects_wrong_generator_set_id' "$f" \
    || { echo "missing bad-generator-set vector"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "VNET circuit is MSM-only, generator-pinned, linked, bounded, and reject-tested"
}

check_scope() {
  local bad=0
  grep -qx $'cargo/world-app/provekit-vnet/src/main.nr\tworld-app/provekit-vnet/src/main.nr' "$CAND_DIR/LANDING" \
    || { echo "missing main.nr landing"; bad=1; }
  grep -qx $'cargo/world-app/provekit-vnet/Prover.toml.example\tworld-app/provekit-vnet/Prover.toml.example' "$CAND_DIR/LANDING" \
    || { echo "missing witness example landing"; bad=1; }
  ! find "$CAND_DIR/cargo/world-app/provekit-vnet" -path '*/target/*' -type f | grep -q . \
    || { echo "generated target artifact included"; bad=1; }
  ! find "$CAND_DIR/cargo/world-app/provekit-vnet" -name '*.json' -type f | grep -q . \
    || { echo "generated circuit json included"; bad=1; }
  grep -q 'provekit-vnet/Prover.toml' "$CAND_DIR/cargo/world-app/.gitignore" \
    || { echo "missing provekit-vnet generated-artifact ignore"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "landing scope is source/docs/witness template only; generated artifacts stay out"
}

check_corrupt() {
  local m="$TRACES/main-mutant.nr"
  cp "$PKG/src/main.nr" "$m"
  perl -0pi -e 's/std::hash::derive_generators\("AAC_PEDERSEN_VECTOR_VNET_1"\.as_bytes\(\), 0\)/[EmbeddedCurvePoint::generator(), EmbeddedCurvePoint::generator(), EmbeddedCurvePoint::generator(), EmbeddedCurvePoint::generator()]/' "$m"
  if check_structure "$m" > "$TRACES/_mutant_check.txt" 2>&1; then
    echo "mutant unexpectedly passed"
    return 1
  fi
  grep -q 'missing domain-separated derived generator set' "$TRACES/_mutant_check.txt" || {
    echo "mutant failed for the wrong reason"
    cat "$TRACES/_mutant_check.txt"
    return 1
  }
  echo "mutant rejected when derived generators are replaced by the demo base-generator path"
}

prepare_workdir() {
  cp -R "$PKG" "$RUN_PKG"
  cp "$RUN_PKG/Prover.toml.example" "$RUN_PKG/Prover.toml"
  mkdir -p "$WORK/home/nargo"
  echo "prepared temporary package at $RUN_PKG"
}

run_nargo_tests() {
  (cd "$RUN_PKG" && HOME="$WORK/home" "$NARGO19_BIN" test --show-output)
}

run_nargo_execute() {
  (cd "$RUN_PKG" && HOME="$WORK/home" "$NARGO19_BIN" execute)
}

run_provekit_prepare() {
  (cd "$RUN_PKG" && HOME="$WORK/home" "$PROVEKIT_BIN" prepare --deny-warnings --force -p aac_vnet_provekit.pkp -v aac_vnet_provekit.pkv .)
}

run_provekit_prove() {
  (cd "$RUN_PKG" && HOME="$WORK/home" "$PROVEKIT_BIN" prove -p aac_vnet_provekit.pkp -i Prover.toml -o proof.np)
}

run_provekit_verify() {
  (cd "$RUN_PKG" && HOME="$WORK/home" "$PROVEKIT_BIN" verify -v aac_vnet_provekit.pkv --proof proof.np)
}

run() {
  local nm="$1" fn="$2" rc
  shift 2
  "$fn" "$@" > "$TRACES/$nm.txt" 2>&1
  rc=$?
  printf 'loop-eval: %-12s %s (exit=%d)\n' "$nm" "$([[ $rc -eq 0 ]] && echo pass || echo FAIL)" "$rc"
  return $rc
}

fail=0
run 01-structure check_structure "$PKG/src/main.nr" || fail=1
run 02-scope     check_scope                    || fail=1
run 03-corrupt   check_corrupt                  || fail=1
run 04-toolchain resolve_toolchain              || fail=1
run 05-prepare   prepare_workdir                || fail=1
if [[ "$fail" -eq 0 ]]; then
  run 06-nargo-tests run_nargo_tests       || fail=1
  run 07-execute     run_nargo_execute     || fail=1
  run 08-pk-prepare  run_provekit_prepare  || fail=1
  run 09-pk-prove    run_provekit_prove    || fail=1
  run 10-pk-verify   run_provekit_verify   || fail=1
fi

verdict="pass"; [[ "$fail" -eq 0 ]] || verdict="fail"
{
  printf '{\n  "schema": "boat.eval-self.v0",\n  "candidate": "cand-0052-provekit-vnet-circuit",\n'
  printf '  "evaluated_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '  "task": "Land a standalone ProveKit beta.19 VNET/1 reference circuit using derived Grumpkin Pedersen-vector MSM commitments, checked transition linkage, and WHIR proof verification.",\n'
  printf '  "checks": {\n'
  printf '    "structure": "%s",\n' "$(grep -q 'MSM-only' "$TRACES/01-structure.txt" && echo pass || echo fail)"
  printf '    "scope": "%s",\n' "$(grep -q 'generated artifacts stay out' "$TRACES/02-scope.txt" && echo pass || echo fail)"
  printf '    "corrupt": "%s",\n' "$(grep -q 'mutant rejected' "$TRACES/03-corrupt.txt" && echo pass || echo fail)"
  printf '    "toolchain": "%s",\n' "$(grep -q 'nargo version = 1.0.0-beta.19' "$TRACES/04-toolchain.txt" && grep -q 'provekit-cli' "$TRACES/04-toolchain.txt" && echo pass || echo fail)"
  printf '    "nargo_tests": "%s",\n' "$(grep -q '8 tests passed' "$TRACES/06-nargo-tests.txt" && echo pass || echo fail)"
  printf '    "nargo_execute": "%s",\n' "$(grep -q 'Circuit witness successfully solved' "$TRACES/07-execute.txt" && echo pass || echo fail)"
  printf '    "provekit_prepare": "%s",\n' "$(grep -q 'R1CS' "$TRACES/08-pk-prepare.txt" && grep -q 'Wrote .*aac_vnet_provekit.pkv' "$TRACES/08-pk-prepare.txt" && echo pass || echo fail)"
  printf '    "provekit_prove": "%s",\n' "$(grep -q 'Wrote .*proof.np' "$TRACES/09-pk-prove.txt" && echo pass || echo fail)"
  printf '    "provekit_verify": "%s"\n' "$(grep -q 'run:' "$TRACES/10-pk-verify.txt" && echo pass || echo fail)"
  printf '  },\n  "verdict": "%s"\n}\n' "$verdict"
} > "$CAND_DIR/scores.json"

printf 'loop-eval: verdict=%s\n' "$verdict"
bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES" \
  || { printf 'loop-eval: WARNING attestation failed\n' >&2; exit 1; }
[[ "$verdict" == "pass" ]] || exit 1
