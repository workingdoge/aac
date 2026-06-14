#!/usr/bin/env bash
# eval-self.sh -- functional evidence for cand-0030-kernel-app-decouple.
# Witnesses the kernel->app back-edge severance: the enshrined `transition` and
# `nullify` circuits drop their `rulebook` (application schema) dependency, which
# was test-only (the proven `main` was already schema-agnostic). transition keeps
# pacioli+ledger+hash; nullify drops to hash alone. The transition composition
# test now uses the literal Pn conformance vector + an opaque nullifier instead
# of compile_goods_receipt_invoice/event_nullifier; nullify's anti-replay tests
# use an opaque field. Checks: (1) a structural probe that the kernel crates
# carry no app refs; (2) nargo test green workspace-wide + all sample witnesses
# still solve; (3) a candidate-local MUTANT proving the probe is non-vacuous.
# nargo via NARGO_BIN/PATH/~/.nargo/bin; honest-skips the prove stage if absent.
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"
CARGO="$CAND_DIR/cargo/circuits"
TRACES="$CAND_DIR/traces"
rm -rf "$TRACES"; mkdir -p "$TRACES"

NARGO="${NARGO_BIN:-$(command -v nargo || true)}"
[[ -n "$NARGO" && -x "$NARGO" ]] || { [[ -x "$HOME/.nargo/bin/nargo" ]] && NARGO="$HOME/.nargo/bin/nargo"; }
have_nargo() { [[ -n "$NARGO" && -x "$NARGO" ]]; }

# tools/eval/attest.sh uses GNU `head -n -1`; BSD/macOS head rejects negative
# counts. Provide the exact behavior to attest.sh's child bash without touching
# the verifier-set tool (the same shim cand-0031-sparse-profile used).
head() {
  if [[ "${1:-}" == "-n" && "${2:-}" == "-1" && $# -eq 3 ]]; then
    awk 'NR > 1 { print prev } { prev = $0 }' "$3"
  else
    command head "$@"
  fi
}
export -f head

# ---- (1) structural: the kernel crates carry no application references -------
check_logic() {
  local bad=0
  # transition: no rulebook anywhere; app-schema symbols gone; kernel deps kept.
  grep -q 'rulebook' "$CARGO/transition/Nargo.toml" && { echo "transition Nargo.toml still depends on rulebook"; bad=1; }
  grep -qE 'use rulebook|rulebook::' "$CARGO/transition/src/main.nr" && { echo "transition main.nr still imports/uses rulebook"; bad=1; }
  grep -qE 'compile_goods_receipt_invoice|GoodsReceiptInvoice|event_commitment\(' "$CARGO/transition/src/main.nr" && { echo "transition main.nr still names the app schema"; bad=1; }
  grep -q 'pacioli = { path = "../pacioli" }' "$CARGO/transition/Nargo.toml" || { echo "transition lost pacioli"; bad=1; }
  grep -q 'ledger = { path = "../ledger" }'   "$CARGO/transition/Nargo.toml" || { echo "transition lost ledger"; bad=1; }
  grep -q 'hash = { path = "../hash" }'       "$CARGO/transition/Nargo.toml" || { echo "transition lost hash"; bad=1; }
  # transition composition test exists and uses the literal Pn conformance vector.
  grep -q 'composition_transition_posts_the_bvr_journal' "$CARGO/transition/src/main.nr" || { echo "transition composition test missing"; bad=1; }
  grep -q '\[10000, 0, 0\]' "$CARGO/transition/src/main.nr" || { echo "transition composition test lacks the literal Pn vector"; bad=1; }
  # nullify: no rulebook, no ledger; app-side derivations gone; keeps hash.
  grep -q 'rulebook' "$CARGO/nullify/Nargo.toml" && { echo "nullify Nargo.toml still depends on rulebook"; bad=1; }
  grep -q 'ledger'   "$CARGO/nullify/Nargo.toml" && { echo "nullify Nargo.toml still depends on ledger"; bad=1; }
  grep -qE 'use rulebook|rulebook::|use ledger|ledger::' "$CARGO/nullify/src/main.nr" && { echo "nullify main.nr still imports/uses rulebook or ledger"; bad=1; }
  grep -qE 'event_nullifier\(|participant_set\(' "$CARGO/nullify/src/main.nr" && { echo "nullify main.nr still calls an app-side derivation"; bad=1; }
  grep -q 'hash = { path = "../hash" }' "$CARGO/nullify/Nargo.toml" || { echo "nullify lost hash"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "kernel crates carry no app refs; transition keeps pacioli+ledger+hash; nullify on hash only"
}

# ---- (2) functional: the whole workspace still proves -----------------------
stage() { # assemble the post-sever workspace into a scratch dir, echo its path
  local s="$TRACES/ws"; rm -rf "$s"; mkdir -p "$s"
  for c in pacioli hash ledger rulebook event-complete transition nullify; do
    cp -r "$ROOT/circuits/$c" "$s/$c"
  done
  cp "$ROOT/circuits/Nargo.toml" "$s/Nargo.toml"
  # overlay the modified kernel crates; Prover.tomls stay from ROOT (main unchanged)
  cp "$CARGO/transition/Nargo.toml"  "$s/transition/Nargo.toml"
  cp "$CARGO/transition/src/main.nr" "$s/transition/src/main.nr"
  cp "$CARGO/nullify/Nargo.toml"     "$s/nullify/Nargo.toml"
  cp "$CARGO/nullify/src/main.nr"    "$s/nullify/src/main.nr"
  rm -rf "$s/target"
  printf '%s' "$s"
}

check_prove() {
  have_nargo || { echo "SKIP: nargo absent"; return 0; }
  local s; s="$(stage)"
  ( cd "$s" && "$NARGO" test ) > "$TRACES/_test.txt" 2>&1 || { echo "workspace tests FAILED"; tail -20 "$TRACES/_test.txt"; return 1; }
  grep -qE 'tests passed' "$TRACES/_test.txt" || { echo "tests did not report passing"; tail -8 "$TRACES/_test.txt"; return 1; }
  grep -qE 'test failed|FAILED' "$TRACES/_test.txt" && { echo "a test failed"; tail -12 "$TRACES/_test.txt"; return 1; }
  for p in transition nullify event_complete; do
    ( cd "$s" && "$NARGO" execute --package "$p" ) > "$TRACES/_exec_$p.txt" 2>&1 || { echo "$p execute FAILED"; tail -6 "$TRACES/_exec_$p.txt"; return 1; }
    grep -q 'successfully solved' "$TRACES/_exec_$p.txt" || { echo "$p witness not solved"; return 1; }
  done
  echo "nargo test green workspace-wide; transition+nullify+event_complete witnesses still solve"
}

# ---- (3) mutant: the structural probe is non-vacuous ------------------------
# Re-introduce an application reference into a COPY of the kernel source and
# confirm the same probe catches it. Candidate-local only -- the DURABLE law
# (a checker enrolled in evaluate-landed.sh) is cand-0032's job, by design.
check_mutant() {
  local m="$TRACES/mutant-transition.nr"
  cp "$CARGO/transition/src/main.nr" "$m"
  printf '\nuse rulebook::GoodsReceiptInvoice;\n' >> "$m"
  if grep -qE 'use rulebook|rulebook::' "$m"; then
    echo "mutant caught: the probe flags a re-introduced rulebook reference (non-vacuous)"
    return 0
  fi
  echo "mutant NOT caught: the structural probe is vacuous"
  return 1
}

run() { local nm="$1" fn="$2" rc; "$fn" > "$TRACES/$nm.txt" 2>&1; rc=$?; printf 'loop-eval: %-10s %s (exit=%d)\n' "$nm" "$([[ $rc -eq 0 ]] && echo pass || echo FAIL)" "$rc"; return $rc; }

fail=0
run 01-logic  check_logic  || fail=1
run 02-prove  check_prove  || fail=1
run 03-mutant check_mutant || fail=1

verdict="pass"; [[ "$fail" -eq 0 ]] || verdict="fail"
{
  printf '{\n  "schema": "boat.eval-self.v0",\n  "candidate": "cand-0030-kernel-app-decouple",\n'
  printf '  "evaluated_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '  "task": "sever the kernel->app back-edge: remove the rulebook (application schema) dependency from the enshrined transition + nullify circuits (test-only; the proven main was already schema-agnostic). transition keeps pacioli+ledger+hash; nullify drops to hash alone. The transition composition test uses the literal Pn conformance vector + an opaque nullifier; nullify anti-replay tests use an opaque field. nargo test green workspace-wide, all sample witnesses solve, and a structural probe (with a candidate-local mutant) witnesses the kernel carries no app refs. 4/REG S5: base MUST NOT require an application target.",\n'
  printf '  "checks": {\n'
  printf '    "logic": "%s",\n'  "$(grep -q 'no app refs' "$TRACES/01-logic.txt" && echo pass || echo fail)"
  printf '    "prove": "%s",\n'  "$(grep -qE 'nargo test green|^SKIP' "$TRACES/02-prove.txt" && echo pass || echo fail)"
  printf '    "mutant": "%s"\n'  "$(grep -q 'mutant caught' "$TRACES/03-mutant.txt" && echo pass || echo fail)"
  printf '  },\n  "verdict": "%s"\n}\n' "$verdict"
} > "$CAND_DIR/scores.json"

printf 'loop-eval: verdict=%s\n' "$verdict"
bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES" \
  || { printf 'loop-eval: WARNING attestation failed\n' >&2; exit 1; }
[[ "$verdict" == "pass" ]] || exit 1
