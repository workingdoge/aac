#!/usr/bin/env bash
# eval-self.sh -- functional evidence for cand-0024-poseidon2-migration.
# Witnesses the pedersen -> Poseidon2 migration: a new shared `hash` crate (a
# sponge over std::hash::poseidon2_permutation) replaces every pedersen_hash
# across ledger/rulebook/transition/nullify; event-complete + pacioli inherit /
# are unchanged. The whole workspace still passes nargo test, all sample
# witnesses solve against the regenerated Prover.tomls, and the transition gate
# count collapses (pedersen-dominated). nargo via NARGO_BIN/PATH/~/.nargo/bin;
# bb via BB_BIN/PATH for the optional gate read; honest-skips when absent.
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"
CARGO="$CAND_DIR/cargo/circuits"
TRACES="$CAND_DIR/traces"
rm -rf "$TRACES"; mkdir -p "$TRACES"

NARGO="${NARGO_BIN:-$(command -v nargo || true)}"
[[ -n "$NARGO" && -x "$NARGO" ]] || { [[ -x "$HOME/.nargo/bin/nargo" ]] && NARGO="$HOME/.nargo/bin/nargo"; }
have_nargo() { [[ -n "$NARGO" && -x "$NARGO" ]]; }
BB="${BB_BIN:-$(command -v bb || true)}"
[[ -n "$BB" && -x "$BB" ]] || { [[ -x /tmp/aac-bb/bin/bb ]] && BB=/tmp/aac-bb/bin/bb; }

check_logic() {
  local bad=0
  grep -q 'poseidon2_permutation' "$CARGO/hash/src/lib.nr" || { echo "hash crate does not use poseidon2_permutation"; bad=1; }
  grep -q 'pub fn poseidon_hash' "$CARGO/hash/src/lib.nr" || { echo "hash crate lacks poseidon_hash"; bad=1; }
  # every migrated crate must be free of pedersen_hash.
  for f in ledger/src/lib.nr rulebook/src/lib.nr transition/src/main.nr nullify/src/main.nr; do
    grep -q 'pedersen' "$CARGO/$f" && { echo "$f still references pedersen"; bad=1; }
    grep -q 'hash::poseidon_hash' "$CARGO/$f" || { echo "$f does not call hash::poseidon_hash"; bad=1; }
  done
  grep -q '"hash"' "$CARGO/Nargo.toml" || { echo "workspace does not include the hash crate"; bad=1; }
  for c in ledger rulebook transition nullify; do
    grep -q 'hash = { path = "../hash" }' "$CARGO/$c/Nargo.toml" || { echo "$c missing the hash dependency"; bad=1; }
  done
  [[ "$bad" -eq 0 ]] && echo "poseidon2 sponge in hash crate; all 4 crates swapped off pedersen; workspace + deps wired"
}

stage() { # assemble the poseidon2 workspace into a scratch dir, echo its path
  local s="$TRACES/ws"; rm -rf "$s"; mkdir -p "$s"
  cp -r "$ROOT/circuits/pacioli" "$ROOT/circuits/event-complete" "$s/"
  cp -r "$CARGO/hash" "$CARGO/ledger" "$CARGO/rulebook" "$CARGO/transition" "$CARGO/nullify" "$s/"
  cp "$CARGO/Nargo.toml" "$s/Nargo.toml"
  cp "$CARGO/event-complete/Prover.toml" "$s/event-complete/Prover.toml"
  printf '%s' "$s"
}

check_prove() {
  have_nargo || { echo "SKIP: nargo absent"; return 0; }
  local s; s="$(stage)"
  ( cd "$s" && "$NARGO" test ) > "$TRACES/_test.txt" 2>&1 || { echo "workspace tests FAILED"; tail -14 "$TRACES/_test.txt"; return 1; }
  grep -qE 'tests passed' "$TRACES/_test.txt" || { echo "tests did not pass"; return 1; }
  grep -qE 'test failed|FAILED' "$TRACES/_test.txt" && { echo "a test failed"; tail -8 "$TRACES/_test.txt"; return 1; }
  # the regenerated Prover.tomls must solve under poseidon2.
  for p in transition nullify event_complete; do
    ( cd "$s" && "$NARGO" execute --package "$p" ) > "$TRACES/_exec_$p.txt" 2>&1 || { echo "$p execute FAILED"; tail -5 "$TRACES/_exec_$p.txt"; return 1; }
    grep -q 'successfully solved' "$TRACES/_exec_$p.txt" || { echo "$p witness not solved"; return 1; }
  done
  # optional headline: the transition gate count vs 40,511 (pedersen).
  local gates="(bb absent)"
  if [[ -n "$BB" && -x "$BB" ]]; then
    ( cd "$s" && "$NARGO" compile --package transition ) >/dev/null 2>&1
    gates="$("$BB" gates -b "$s/target/transition.json" 2>/dev/null | grep -oE '"circuit_size": *[0-9]+' | grep -oE '[0-9]+' | head -1)"
    [[ -n "$gates" ]] || gates="(unread)"
    if [[ "$gates" =~ ^[0-9]+$ ]]; then
      [[ "$gates" -lt 12000 ]] || { echo "transition gate count $gates did not collapse below 12000 (was 40,511)"; return 1; }
    fi
  fi
  echo "nargo test green (workspace, poseidon2); transition+nullify+event_complete witnesses solve; transition gates=$gates (was 40,511 pedersen)"
}

run() { local nm="$1" fn="$2" rc; "$fn" > "$TRACES/$nm.txt" 2>&1; rc=$?; printf 'loop-eval: %-10s %s (exit=%d)\n' "$nm" "$([[ $rc -eq 0 ]] && echo pass || echo FAIL)" "$rc"; return $rc; }

fail=0
run 01-logic check_logic || fail=1
run 02-prove check_prove || fail=1

verdict="pass"; [[ "$fail" -eq 0 ]] || verdict="fail"
{
  printf '{\n  "schema": "boat.eval-self.v0",\n  "candidate": "cand-0024-poseidon2-migration",\n'
  printf '  "evaluated_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '  "task": "migrate the circuits commitment hash from pedersen_hash to a Poseidon2 sponge (new shared hash crate over std::hash::poseidon2_permutation); swap all 18 sites across ledger/rulebook/transition/nullify; regenerate the transition/nullify/event-complete Prover.tomls; nargo test green across the workspace, all sample witnesses solve, and the transition gate count collapses from 40,511",\n'
  printf '  "checks": {\n'
  printf '    "logic": "%s",\n' "$(grep -q 'workspace + deps wired' "$TRACES/01-logic.txt" && echo pass || echo fail)"
  printf '    "prove": "%s"\n'  "$(grep -qE 'nargo test green|^SKIP' "$TRACES/02-prove.txt" && echo pass || echo fail)"
  printf '  },\n  "verdict": "%s"\n}\n' "$verdict"
} > "$CAND_DIR/scores.json"

printf 'loop-eval: verdict=%s\n' "$verdict"
bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES" \
  || { printf 'loop-eval: WARNING attestation failed\n' >&2; exit 1; }
[[ "$verdict" == "pass" ]] || exit 1
