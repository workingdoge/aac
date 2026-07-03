#!/usr/bin/env bash
# eval-self.sh -- functional evidence for cand-0086-ledger-statement-interface.
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"
TRACES="$CAND_DIR/traces"
SPEC="$CAND_DIR/cargo/sites/ledger/specs/applications/LEDGER-1.md"
INDEX="$CAND_DIR/cargo/sites/ledger/specs/applications/README.md"
LANDING="$CAND_DIR/LANDING"
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

check_text() {
  local bad=0
  grep -q 'Application surface (not enshrined)' "$SPEC" || { echo "LEDGER/1 must stay non-enshrined"; bad=1; }
  grep -q 'It gives AAC a vertex object' "$SPEC" || { echo "spec missing vertex object claim"; bad=1; }
  grep -q 'A statement is not a second ledger' "$SPEC" || { echo "spec missing statement/ledger separation"; bad=1; }
  grep -q 'Projection law' "$SPEC" || { echo "spec missing projection law section"; bad=1; }
  grep -q 'P(post_C(ledger, journal)) = post_D(P(ledger), P(journal))' "$SPEC" || { echo "spec missing post/projection commutation"; bad=1; }
  grep -q 'TRANSITION public input 4' "$SPEC" || { echo "spec missing journal_commitment binding"; bad=1; }
  grep -q 'stability_failure' "$SPEC" || { echo "spec missing Premath stability failure mapping"; bad=1; }
  grep -q 'locality_failure' "$SPEC" || { echo "spec missing Premath locality failure mapping"; bad=1; }
  grep -q 'descent_failure' "$SPEC" || { echo "spec missing Premath descent failure mapping"; bad=1; }
  grep -q 'glue_non_contractible' "$SPEC" || { echo "spec missing Premath glue failure mapping"; bad=1; }
  grep -q 'Showing a private witness table as though it were verifier input is misleading' "$SPEC" || { echo "spec missing UI privacy warning"; bad=1; }
  grep -q '\[LEDGER/1\](LEDGER-1.md)' "$INDEX" || { echo "applications index missing LEDGER/1"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "LEDGER/1 carries vertex, statement projection, transition binding, Gate vocabulary, and UI privacy boundaries"
}

check_non_expansion() {
  local bad=0
  if grep -qi 'MUST assign.*tag\|MUST allocate.*tag\|is a new enshrined registry target\|defines a new circuit' "$SPEC"; then
    echo "spec appears to assign tags or expand the enshrined/circuit surface"
    bad=1
  fi
  grep -q 'Application surfaces that do not define an in-circuit commitment or proof' "$INDEX" || {
    echo "index must state non-circuit surfaces do not receive tags merely by being named"
    bad=1
  }
  [[ "$bad" -eq 0 ]] && echo "LEDGER/1 does not allocate a domain tag or expand base-registry targets"
}

check_landing() {
  local bad=0
  grep -qx 'cargo/sites/ledger/specs/applications/LEDGER-1.md sites/ledger/specs/applications/LEDGER-1.md' "$LANDING" || {
    echo "LANDING missing LEDGER/1 map"; bad=1;
  }
  grep -qx 'cargo/sites/ledger/specs/applications/README.md sites/ledger/specs/applications/README.md' "$LANDING" || {
    echo "LANDING missing applications README map"; bad=1;
  }
  [[ "$(wc -l < "$LANDING" | tr -d ' ')" == "2" ]] || { echo "LANDING should contain exactly two cargo maps"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "LANDING maps only LEDGER/1 and the application index"
}

check_markdown_links() {
  local bad=0
  grep -q 'Cites: 1/PACI, 2/FACT, 3/PROOF, 4/REG, 6/NAME, 7/DATA' "$SPEC" || {
    echo "spec cites unexpected core dependency set"; bad=1;
  }
  grep -q '^\| \[LEDGER/1\](LEDGER-1.md) \| Committed Ledger State and Statement Interface \| Raw \|$' "$INDEX" || {
    echo "index row is malformed"; bad=1;
  }
  [[ "$bad" -eq 0 ]] && echo "markdown metadata and index row are well formed"
}

run() {
  local nm="$1" fn="$2" rc
  shift 2
  "$fn" "$@" > "$TRACES/$nm.txt" 2>&1
  rc=$?
  printf 'loop-eval: %-16s %s (exit=%d)\n' "$nm" "$([[ $rc -eq 0 ]] && echo pass || echo FAIL)" "$rc"
  return $rc
}

fail=0
run 01-text          check_text          || fail=1
run 02-non-expansion check_non_expansion || fail=1
run 03-landing       check_landing       || fail=1
run 04-markdown      check_markdown_links || fail=1

verdict="pass"; [[ "$fail" -eq 0 ]] || verdict="fail"
{
  printf '{\n  "schema": "boat.eval-self.v0",\n  "candidate": "cand-0086-ledger-statement-interface",\n'
  printf '  "evaluated_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '  "task": "Add LEDGER/1 as the committed private ledger state and statement interface: ledger as vertex, statements as lawful projections, TRANSITION/1 binding, and Premath Gate failure vocabulary.",\n'
  printf '  "checks": {\n'
  printf '    "text": "%s",\n' "$(grep -q 'LEDGER/1 carries vertex' "$TRACES/01-text.txt" && echo pass || echo fail)"
  printf '    "non_expansion": "%s",\n' "$(grep -q 'does not allocate a domain tag' "$TRACES/02-non-expansion.txt" && echo pass || echo fail)"
  printf '    "landing": "%s",\n' "$(grep -q 'maps only LEDGER/1' "$TRACES/03-landing.txt" && echo pass || echo fail)"
  printf '    "markdown": "%s"\n' "$(grep -q 'metadata and index row' "$TRACES/04-markdown.txt" && echo pass || echo fail)"
  printf '  },\n  "verdict": "%s"\n}\n' "$verdict"
} > "$CAND_DIR/scores.json"

printf 'loop-eval: verdict=%s\n' "$verdict"
bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES" \
  || { printf 'loop-eval: WARNING attestation failed\n' >&2; exit 1; }
[[ "$verdict" == "pass" ]] || exit 1
