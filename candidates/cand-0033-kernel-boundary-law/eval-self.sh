#!/usr/bin/env bash
# eval-self.sh -- functional evidence for cand-0033-kernel-boundary-law.
# Witnesses tools/kernel-boundary-check.sh: a read-only ROOT-relative court for
# the kernel/app crate boundary (4/REG S5; recompute-vs-consume seam). KERNEL =
# {pacioli,hash,ledger,transition,nullify}; a kernel crate may depend on / import
# only KERNEL crates + std. Checks: (1) structural -- checker is ROOT-relative,
# pins the KERNEL set, mints typed witnesses, and is ENROLLED in evaluate-landed;
# (2) CLEAN on the live post-cand-0032 tree (kernel crates only touch kernel);
# (3) NON-VACUOUS -- a manifest mutant (app dep in a kernel crate) AND a `use`
# mutant (app import in kernel src, no manifest dep) are BOTH refused, exit 1.
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"
CARGO="$CAND_DIR/cargo"
CHK="$CARGO/tools/kernel-boundary-check.sh"
EL="$CARGO/tools/eval/evaluate-landed.sh"
TRACES="$CAND_DIR/traces"
rm -rf "$TRACES"; mkdir -p "$TRACES"

# attest.sh uses GNU `head -n -1`; shim for BSD/macOS (cand-0030/0031 pattern).
head() {
  if [[ "${1:-}" == "-n" && "${2:-}" == "-1" && $# -eq 3 ]]; then
    awk 'NR > 1 { print prev } { prev = $0 }' "$3"
  else
    command head "$@"
  fi
}
export -f head

# ---- (1) structural: checker shape + enrollment -----------------------------
check_logic() {
  local bad=0
  grep -q 'BOAT_ROOT' "$CHK" || { echo "checker not ROOT-relative (no BOAT_ROOT)"; bad=1; }
  grep -q 'KERNEL="pacioli hash ledger transition nullify"' "$CHK" || { echo "checker does not pin the KERNEL set"; bad=1; }
  grep -q 'tools/eval/witness-id.sh' "$CHK" || { echo "checker does not mint typed witnesses via witness-id.sh"; bad=1; }
  grep -q 'kernel-app-boundary-violation' "$CHK" || { echo "checker lacks the boundary-violation class"; bad=1; }
  # enrollment: a [[ -f ]]-guarded run_suite line (export-course conditional).
  grep -q '\[\[ -f "\$ROOT/tools/kernel-boundary-check.sh" \]\]' "$EL" || { echo "evaluate-landed lacks the [[ -f ]] guard for the checker"; bad=1; }
  grep -q 'run_suite kernel-boundary bash tools/kernel-boundary-check.sh' "$EL" || { echo "evaluate-landed does not enroll the kernel-boundary suite"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "checker ROOT-relative, pins KERNEL set, mints typed witnesses, and is [[ -f ]]-guard-enrolled in evaluate-landed"
}

# ---- (2) clean on the live tree ---------------------------------------------
check_clean() {
  local out rc
  out="$(BOAT_ROOT="$ROOT" KBC_CIRCUITS="$ROOT/circuits" bash "$CHK" 2>&1)"; rc=$?
  echo "$out" > "$TRACES/_clean.txt"
  [[ "$rc" -eq 0 ]] || { echo "checker FAILED on the live tree (exit $rc): $out"; return 1; }
  grep -q 'ok (5 kernel crates depend only on kernel crates)' "$TRACES/_clean.txt" || { echo "unexpected clean output"; return 1; }
  echo "clean: kernel crates {pacioli,hash,ledger,transition,nullify} depend only on kernel crates (exit 0)"
}

# ---- (3) non-vacuous: both guards refuse a violation ------------------------
check_mutant() {
  local bad=0
  # (a) manifest mutant: inject an app dep into a kernel crate.
  local ma="$TRACES/mutant-dep"; rm -rf "$ma"; cp -r "$ROOT/circuits" "$ma"
  awk '1; /^\[dependencies\]/ && !d { print "receipt = { path = \"../receipt\" }"; d=1 }' "$ma/transition/Nargo.toml" > "$ma/transition/Nargo.toml.t" && mv "$ma/transition/Nargo.toml.t" "$ma/transition/Nargo.toml"
  local outa rca
  outa="$(BOAT_ROOT="$ROOT" KBC_CIRCUITS="$ma" bash "$CHK" 2>"$TRACES/_mutdep.err")"; rca=$?
  echo "$outa" > "$TRACES/_mutdep.txt"
  [[ "$rca" -eq 1 ]] || { echo "manifest mutant NOT refused (exit $rca)"; bad=1; }
  grep -q '"tokenPath": "transition.Nargo.toml.receipt"' "$TRACES/_mutdep.txt" || { echo "manifest mutant: missing typed violation"; bad=1; }
  grep -qE '"witnessId": "w1_' "$TRACES/_mutdep.txt" || { echo "manifest mutant: no minted witnessId"; bad=1; }
  # (b) use mutant: inject an app import into kernel src, NO manifest dep.
  local mb="$TRACES/mutant-use"; rm -rf "$mb"; cp -r "$ROOT/circuits" "$mb"
  printf '\nuse receipt::participant_set;\n' >> "$mb/ledger/src/lib.nr"
  local outb rcb
  outb="$(BOAT_ROOT="$ROOT" KBC_CIRCUITS="$mb" bash "$CHK" 2>"$TRACES/_mutuse.err")"; rcb=$?
  echo "$outb" > "$TRACES/_mutuse.txt"
  [[ "$rcb" -eq 1 ]] || { echo "use mutant NOT refused (exit $rcb)"; bad=1; }
  grep -q '"tokenPath": "ledger.lib.nr.receipt"' "$TRACES/_mutuse.txt" || { echo "use mutant: missing typed violation"; bad=1; }
  # (c) reordered inline table -- path NOT the first key -- must still be caught (M4).
  local mc="$TRACES/mutant-reorder"; rm -rf "$mc"; cp -r "$ROOT/circuits" "$mc"
  awk '1; /^\[dependencies\]/ && !d { print "aliased = { tag = \"v1\", path = \"../rulebook\" }"; d=1 }' "$mc/nullify/Nargo.toml" > "$mc/nullify/Nargo.toml.t" && mv "$mc/nullify/Nargo.toml.t" "$mc/nullify/Nargo.toml"
  local outc rcc
  outc="$(BOAT_ROOT="$ROOT" KBC_CIRCUITS="$mc" bash "$CHK" 2>/dev/null)"; rcc=$?
  echo "$outc" > "$TRACES/_mutreorder.txt"
  [[ "$rcc" -eq 1 ]] || { echo "reordered-key mutant NOT refused (exit $rcc)"; bad=1; }
  grep -q '"tokenPath": "nullify.Nargo.toml.rulebook"' "$TRACES/_mutreorder.txt" || { echo "reordered-key mutant: missing typed violation"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "non-vacuous: manifest-dep, use-import, AND reordered-key (path-not-first) edges all refused (exit 1, typed witnesses)"
}

run() { local nm="$1" fn="$2" rc; "$fn" > "$TRACES/$nm.txt" 2>&1; rc=$?; printf 'loop-eval: %-10s %s (exit=%d)\n' "$nm" "$([[ $rc -eq 0 ]] && echo pass || echo FAIL)" "$rc"; return $rc; }

fail=0
run 01-logic  check_logic  || fail=1
run 02-clean  check_clean  || fail=1
run 03-mutant check_mutant || fail=1

verdict="pass"; [[ "$fail" -eq 0 ]] || verdict="fail"
{
  printf '{\n  "schema": "boat.eval-self.v0",\n  "candidate": "cand-0033-kernel-boundary-law",\n'
  printf '  "evaluated_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '  "task": "land tools/kernel-boundary-check.sh -- a read-only ROOT-relative court for the kernel/app crate boundary (4/REG S5): KERNEL = {pacioli,hash,ledger,transition,nullify}, each kernel crate may depend on / import only KERNEL crates + std; a Nargo.toml dep or use naming a non-kernel crate is refused typed (witnessId minted). Enrolled in evaluate-landed.sh so every post-land re-checks the boundary. Witnessed: structural (ROOT-relative, KERNEL pinned, typed witnesses, [[ -f ]]-guard-enrolled), CLEAN on the live post-cand-0032 tree, and NON-VACUOUS (a manifest-dep mutant AND a use-import mutant are both refused, exit 1).",\n'
  printf '  "checks": {\n'
  printf '    "logic": "%s",\n'  "$(grep -q 'guard-enrolled in evaluate-landed' "$TRACES/01-logic.txt" && echo pass || echo fail)"
  printf '    "clean": "%s",\n'  "$(grep -q 'depend only on kernel crates (exit 0)' "$TRACES/02-clean.txt" && echo pass || echo fail)"
  printf '    "mutant": "%s"\n'  "$(grep -q 'manifest-dep, use-import, AND reordered-key' "$TRACES/03-mutant.txt" && echo pass || echo fail)"
  printf '  },\n  "verdict": "%s"\n}\n' "$verdict"
} > "$CAND_DIR/scores.json"

printf 'loop-eval: verdict=%s\n' "$verdict"
bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES" \
  || { printf 'loop-eval: WARNING attestation failed\n' >&2; exit 1; }
[[ "$verdict" == "pass" ]] || exit 1
