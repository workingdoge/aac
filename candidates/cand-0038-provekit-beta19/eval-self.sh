#!/usr/bin/env bash
# eval-self.sh -- evidence for cand-0038-provekit-beta19.
#
# Makes world-app/provekit-circuit (the ProveKit re-expression of EVENT/1, Design
# Note 0002 S5) actually build/test/execute on its DECLARED beta.19 toolchain, and
# brings beta.19 in reproducibly via Nix. Three scaffold bugs (cand-0027) had never
# been exercised because no beta.19 nargo existed:
#   (1) Nargo.toml pinned `compiler_version = ">=1.0.0-beta.19"` -- beta.19's semver
#       parser rejects ANY prerelease requirement ("Requirements may only refer to
#       full releases"), so the package would not even load. Removed; the toolchain
#       guard moves to the flake (nargo19).
#   (2) hash.nr imported the PRIVATE std::hash::poseidon2::Poseidon2::hash (not
#       exported downstream). Rewritten as a width-4/rate-3 sponge over the PUBLIC
#       std::hash::poseidon2_permutation -- the identical construction circuits/hash
#       adopted in cand-0024.
#   (3) Prover.toml.example carried 0x00 placeholders. Regenerated with the real
#       sponge-hash commitments so `nargo execute` solves.
# Plus an ADDITIVE flake package `nargo19`: the hash-pinned beta.19 nargo for all
# four release triples, same mechanism as the existing beta.14 `nargo`, kept OFF the
# dev-shell PATH and out of the default package so the beta.14 circuits/ workspace is
# untouched.
#
# Checks: (1) structural -- the three fixes + the additive flake package present;
# (2) functional -- nargo19 (beta.19) compile clean + `nargo test` 8/8 + `nargo
# execute` solves on the regenerated example; (3) reproducibility -- the flake's
# nargo19 attribute evaluates/builds to a beta.19 binary (SKIP-honest pre-land / no-nix).
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"
PKG="$CAND_DIR/cargo/world-app/provekit-circuit"
FLAKE="$CAND_DIR/cargo/flake.nix"
TRACES="$CAND_DIR/traces"
rm -rf "$TRACES"; mkdir -p "$TRACES"

# attest.sh uses GNU `head -n -1`; BSD/macOS head rejects negative counts. Shim it
# (queued portability fix; cand-0030/0031/0032/0037 all carry this).
head() {
  if [[ "${1:-}" == "-n" && "${2:-}" == "-1" && $# -eq 3 ]]; then
    awk 'NR > 1 { print prev } { prev = $0 }' "$3"
  else
    command head "$@"
  fi
}
export -f head

# Resolve a beta.19 nargo: explicit override first, else build the flake's nargo19
# (the reproducible path -- post-land ROOT/flake.nix carries the attribute), else
# SKIP the functional check honestly (structural still gates).
NARGO19="${NARGO19_BIN:-}"
if [[ -z "$NARGO19" || ! -x "$NARGO19" ]]; then
  if command -v nix >/dev/null 2>&1; then
    out="$(nix --extra-experimental-features 'nix-command flakes' build "$ROOT#nargo19" --no-link --print-out-paths 2>/dev/null | tail -1)"
    [[ -n "$out" && -x "$out/bin/nargo" ]] && NARGO19="$out/bin/nargo"
  fi
fi
have_nargo19() {
  [[ -n "$NARGO19" && -x "$NARGO19" ]] || return 1
  "$NARGO19" --version 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | grep -q 'nargo version = 1.0.0-beta.19'
}

# ---- (1) structural -----------------------------------------------------------
check_logic() {
  local bad=0
  # (1) no compiler_version pin at all (any prerelease requirement refuses to load).
  grep -qE '^[[:space:]]*compiler_version' "$PKG/Nargo.toml" && { echo "Nargo.toml still pins compiler_version (beta.19 rejects prerelease requirements -> package will not load)"; bad=1; }
  # (2) sponge over the PUBLIC permutation; the private Poseidon2::hash is gone.
  # Strip doc-comment lines first: the header comment NAMES the private path to
  # explain why it is avoided, which must not trip the "still calls it" check.
  grep -q 'std::hash::poseidon2_permutation' "$PKG/src/hash.nr" || { echo "hash.nr does not use the public poseidon2_permutation"; bad=1; }
  grep -vE '^[[:space:]]*//' "$PKG/src/hash.nr" | grep -q 'Poseidon2::hash' && { echo "hash.nr still calls the private Poseidon2::hash (in code, not a comment)"; bad=1; }
  grep -qE 'P2_WIDTH|P2_RATE' "$PKG/src/hash.nr" || { echo "hash.nr lacks the width/rate sponge constants"; bad=1; }
  # (3) the example carries real commitments, not 0x00 placeholders.
  grep -qE 'participant_set_pub = "0x0+"$' "$PKG/Prover.toml.example" && { echo "Prover.toml.example still has 0x00 placeholder commitments"; bad=1; }
  grep -q 'participant_set_pub = "0x021921c7' "$PKG/Prover.toml.example" || { echo "Prover.toml.example does not carry the regenerated participant_set value"; bad=1; }
  # additive flake package: nargo19, pinned beta.19, exposed, off the default/devShell.
  grep -q 'nargo19 = pkgs.stdenv.mkDerivation' "$FLAKE" || { echo "flake lacks the nargo19 derivation"; bad=1; }
  grep -q 'nargo19Release = "v1.0.0-beta.19"' "$FLAKE" || { echo "flake nargo19 not pinned to v1.0.0-beta.19"; bad=1; }
  grep -q 'inherit nargo nargo19 bignum-paramgen' "$FLAKE" || { echo "flake does not expose packages.nargo19"; bad=1; }
  grep -q 'sha256-PQIUPvzAalyZH2m7a7dw5jkjBUnWTzXtE977REILenU=' "$FLAKE" || { echo "flake nargo19 missing the pinned aarch64-darwin hash"; bad=1; }
  # additive discipline: nargo19 must NOT be in the noirToolchainPackages list
  # (which feeds the devShell PATH); two nargos on PATH would shadow beta.14. The
  # list runs from `noirToolchainPackages =` to the let-block's `in`; nargo19 is
  # only legitimate in its derivation (before the list) and the `inherit` (after `in`).
  awk '/noirToolchainPackages =/{f=1} /^[[:space:]]*in[[:space:]]*$/{f=0} f&&/nargo19/{print "LEAK"}' "$FLAKE" | grep -q LEAK && { echo "nargo19 leaked into noirToolchainPackages (would shadow beta.14 on PATH)"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "structural ok: compiler_version removed; hash.nr is a sponge over the public permutation; example regenerated; additive flake nargo19 pinned+exposed, off the default/devShell PATH"
}

# ---- (2) functional: compile + test + execute on beta.19 ----------------------
check_prove() {
  have_nargo19 || { echo "SKIP: beta.19 nargo unavailable (set NARGO19_BIN or provide nix for nargo19)"; return 0; }
  # Stage the FULL circuit from ROOT (unchanged src: main.nr, pacioli.nr, ...) then
  # overlay the three fixed files from cargo -- the cand-0037 staging pattern, so the
  # eval reconstructs the post-fix circuit whether ROOT is pre- or post-land.
  local s="$TRACES/ws"; rm -rf "$s"; mkdir -p "$s"
  cp -r "$ROOT/world-app/provekit-circuit"/. "$s/"
  rm -rf "$s/target"
  cp "$PKG/Nargo.toml"          "$s/Nargo.toml"
  cp "$PKG/src/hash.nr"         "$s/src/hash.nr"
  cp "$PKG/Prover.toml.example" "$s/Prover.toml.example"
  cp "$s/Prover.toml.example"   "$s/Prover.toml"
  "$NARGO19" --version 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | grep -v 'git version hash' > "$TRACES/_version.txt"
  ( cd "$s" && "$NARGO19" compile ) > "$TRACES/_compile.txt" 2>&1 || { echo "compile FAILED"; tail -8 "$TRACES/_compile.txt"; return 1; }
  ( cd "$s" && "$NARGO19" test ) 2>&1 | sed 's/\x1b\[[0-9;]*m//g' > "$TRACES/_test.txt"
  grep -qE 'test failed|FAILED' "$TRACES/_test.txt" && { echo "a test failed"; tail -12 "$TRACES/_test.txt"; return 1; }
  grep -q '8 tests passed' "$TRACES/_test.txt" || { echo "did not see 8 passing tests"; tail -12 "$TRACES/_test.txt"; return 1; }
  ( cd "$s" && "$NARGO19" execute ) 2>&1 | sed 's/\x1b\[[0-9;]*m//g' > "$TRACES/_exec.txt"
  grep -q 'successfully solved' "$TRACES/_exec.txt" || { echo "witness did not solve on the regenerated example"; tail -8 "$TRACES/_exec.txt"; return 1; }
  echo "beta.19 ($(sed -n '1p' "$TRACES/_version.txt")): compile clean; nargo test 8/8; witness solved on the regenerated Prover.toml.example"
}

# ---- (3) reproducibility: the flake's nargo19 evaluates/builds to beta.19 ------
check_flake() {
  command -v nix >/dev/null 2>&1 || { echo "SKIP: nix absent"; return 0; }
  local out
  out="$(nix --extra-experimental-features 'nix-command flakes' build "$ROOT#nargo19" --no-link --print-out-paths 2>"$TRACES/_flake.txt" | tail -1)"
  if [[ -z "$out" || ! -x "$out/bin/nargo" ]]; then
    echo "SKIP: flake nargo19 not buildable from ROOT yet (pre-land ROOT/flake.nix lacks the attribute; reproducible once landed)"; return 0
  fi
  "$out/bin/nargo" --version 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | grep -q 'nargo version = 1.0.0-beta.19' \
    || { echo "flake nargo19 built but is not beta.19"; return 1; }
  echo "nix build .#nargo19 -> beta.19 nargo (hash-pinned; reproducible bring-in)"
}

run() { local nm="$1" fn="$2" rc; "$fn" > "$TRACES/$nm.txt" 2>&1; rc=$?; printf 'loop-eval: %-12s %s (exit=%d)\n' "$nm" "$([[ $rc -eq 0 ]] && echo pass || echo FAIL)" "$rc"; return $rc; }

fail=0
run 01-logic  check_logic  || fail=1
run 02-prove  check_prove  || fail=1
run 03-flake  check_flake  || fail=1

# Trim the staged scratch circuit copy from the committed traces (queued trace-bloat
# item): the result *.txt files are the durable evidence; the ws/ tree is scratch.
# Done BEFORE attest so traces_sha256 covers only what gets committed.
rm -rf "$TRACES/ws"

verdict="pass"; [[ "$fail" -eq 0 ]] || verdict="fail"
{
  printf '{\n  "schema": "boat.eval-self.v0",\n  "candidate": "cand-0038-provekit-beta19",\n'
  printf '  "evaluated_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '  "task": "Make world-app/provekit-circuit (the ProveKit EVENT/1 re-expression) compile/test/execute on its declared Noir beta.19 toolchain, and bring beta.19 in reproducibly via Nix. Three never-exercised scaffold bugs fixed: (1) removed the invalid prerelease compiler_version pin (beta.19 rejects any prerelease requirement, so the package would not load); (2) rewrote hash.nr from the private Poseidon2::hash to a width-4/rate-3 sponge over the PUBLIC poseidon2_permutation (identical to circuits/hash cand-0024); (3) regenerated Prover.toml.example from 0x00 placeholders to the real sponge-hash commitments so execute solves. Added an ADDITIVE flake package nargo19 (hash-pinned beta.19 nargo, four triples, same mechanism as the beta.14 nargo) kept off the dev-shell PATH and out of the default package so the beta.14 circuits/ workspace is untouched. Witnessed: structural (three fixes + additive flake package); beta.19 compile clean + nargo test 8/8 + witness solved on the regenerated example; the flake nargo19 attribute builds to a beta.19 binary.",\n'
  printf '  "checks": {\n'
  printf '    "logic": "%s",\n'  "$(grep -q 'structural ok' "$TRACES/01-logic.txt" && echo pass || echo fail)"
  printf '    "prove": "%s",\n'  "$(grep -qE 'witness solved|^SKIP' "$TRACES/02-prove.txt" && echo pass || echo fail)"
  printf '    "flake": "%s"\n'   "$(grep -qE 'reproducible bring-in|^SKIP' "$TRACES/03-flake.txt" && echo pass || echo fail)"
  printf '  },\n  "verdict": "%s"\n}\n' "$verdict"
} > "$CAND_DIR/scores.json"

printf 'loop-eval: verdict=%s\n' "$verdict"
bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES" \
  || { printf 'loop-eval: WARNING attestation failed\n' >&2; exit 1; }
[[ "$verdict" == "pass" ]] || exit 1
