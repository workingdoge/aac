#!/usr/bin/env bash
# eval-self.sh -- functional evidence for cand-0050-provekit-flake-import.
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"
TRACES="$CAND_DIR/traces"
CARGO="$CAND_DIR/cargo"
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

check_flake_import() {
  local flake="$CARGO/root/flake.nix"
  local lock="$CARGO/root/flake.lock"
  local bad=0
  grep -q 'crane.url = "github:ipetkov/crane"' "$flake" || { echo "missing crane input"; bad=1; }
  grep -q 'github:oxalica/rust-overlay' "$flake" || { echo "missing rust-overlay input"; bad=1; }
  grep -q 'github:worldfnd/ProveKit/b0cb124685bcf24cc0deaa7b191032f58875a47a' "$flake" || { echo "missing pinned provekit source"; bad=1; }
  grep -q 'provekitToolchain = pkgs.rust-bin.nightly."2026-03-04".minimal' "$flake" || { echo "missing pinned ProveKit toolchain"; bad=1; }
  grep -q 'cargoExtraArgs = "--locked -p provekit-cli"' "$flake" || { echo "missing CLI package restriction"; bad=1; }
  grep -q 'mainProgram = "provekit-cli"' "$flake" || { echo "missing CLI mainProgram"; bad=1; }
  grep -q 'inherit nargo nargo19 bignum-paramgen provekit' "$flake" || { echo "provekit not exported as a package"; bad=1; }
  grep -q '"crane_2"' "$lock" || { echo "missing lock node crane_2"; bad=1; }
  grep -q '"provekit-src"' "$lock" || { echo "missing lock node provekit-src"; bad=1; }
  grep -q '"rust-overlay_3"' "$lock" || { echo "missing lock node rust-overlay_3"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "ProveKit flake package wiring and lock nodes are present"
}

check_ignore_hygiene() {
  local ignore="$CARGO/world-app/.gitignore"
  local bad=0
  grep -q 'provekit-circuit/proof.np' "$ignore" || { echo "missing proof.np ignore"; bad=1; }
  grep -q 'provekit-circuit/\*.pkp' "$ignore" || { echo "missing pkp ignore"; bad=1; }
  grep -q 'provekit-circuit/\*.pkv' "$ignore" || { echo "missing pkv ignore"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "generated ProveKit proof/key outputs are ignored"
}

check_landing_scope() {
  local bad=0
  grep -qx $'cargo/root/flake.nix\tflake.nix' "$CAND_DIR/LANDING" || { echo "missing flake.nix landing"; bad=1; }
  grep -qx $'cargo/root/flake.lock\tflake.lock' "$CAND_DIR/LANDING" || { echo "missing flake.lock landing"; bad=1; }
  grep -qx $'cargo/world-app/.gitignore\tworld-app/.gitignore' "$CAND_DIR/LANDING" || { echo "missing gitignore landing"; bad=1; }
  ! grep -q 'provekit-circuit/.*\\.\\(pkp\\|pkv\\|np\\)' "$CAND_DIR/LANDING" || { echo "generated ProveKit artifact in landing map"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "landing scope is limited to flake packaging plus ignore hygiene"
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
run 01-flake   check_flake_import  || fail=1
run 02-ignore  check_ignore_hygiene || fail=1
run 03-scope   check_landing_scope  || fail=1

verdict="pass"; [[ "$fail" -eq 0 ]] || verdict="fail"
{
  printf '{\n  "schema": "boat.eval-self.v0",\n  "candidate": "cand-0050-provekit-flake-import",\n'
  printf '  "evaluated_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '  "task": "Import the ProveKit flake package into the vnet fundraising worktree without landing generated proof artifacts.",\n'
  printf '  "checks": {\n'
  printf '    "flake_import": "%s",\n' "$(grep -q 'ProveKit flake package wiring' "$TRACES/01-flake.txt" && echo pass || echo fail)"
  printf '    "ignore_hygiene": "%s",\n' "$(grep -q 'generated ProveKit proof/key outputs are ignored' "$TRACES/02-ignore.txt" && echo pass || echo fail)"
  printf '    "landing_scope": "%s"\n' "$(grep -q 'landing scope is limited' "$TRACES/03-scope.txt" && echo pass || echo fail)"
  printf '  },\n  "verdict": "%s"\n}\n' "$verdict"
} > "$CAND_DIR/scores.json"

printf 'loop-eval: verdict=%s\n' "$verdict"
bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES" \
  || { printf 'loop-eval: WARNING attestation failed\n' >&2; exit 1; }
[[ "$verdict" == "pass" ]] || exit 1
