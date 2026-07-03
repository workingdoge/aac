#!/usr/bin/env bash
# eval-self.sh -- obstruction evidence for cand-0099-r1-typeid-table.
#
# The requested R1 typeId table depends on byte-identical canonical inputs.
# This harness proves the current source does not determine those bytes, then
# attests the queue update that records the blocker.
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"

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

# shellcheck source=../../tools/eval/eval-lib.sh
. "$ROOT/tools/eval/eval-lib.sh"
eval_init "$CAND_DIR" "$ROOT" || exit 1

WORK="$(mktemp -d /private/tmp/aac-cand-0099.XXXXXX)"
STAGED="$WORK/root"
stage_root "$STAGED" || exit 1

cjson_control_escape_gap_probe() {
  local fact="$1" short unicode
  grep_prose 'Strings as JSON strings with mandatory escaping of' "$fact" >/dev/null \
    || { echo "unexpected: 2/FACT string escaping rule missing"; return 0; }
  grep_prose 'control characters, and no other escaping' "$fact" >/dev/null \
    || { echo "unexpected: 2/FACT control-character rule missing"; return 0; }
  short='"\n"'
  unicode='"\u000a"'
  [[ "$short" != "$unicode" ]] \
    || { echo "unexpected: control-character witness encodings collapsed"; return 0; }
  if grep_prose 'control characters MUST use' "$fact" >/dev/null \
    || grep_prose 'shortest JSON escape' "$fact" >/dev/null \
    || grep_prose 'six-character \\u00xx escape' "$fact" >/dev/null; then
    echo "source now appears to choose a control-character escape spelling"
    return 0
  fi
  echo "blocked: newline has distinct JSON spellings ($short vs $unicode) and 2/FACT does not choose one"
  return 41
}

typedecl_document_gap_probe() {
  local root="$1" fact="$root/sites/ledger/specs/2/README.md" docs
  grep_prose 'TypeDecl := { kind, name?, version, schema' "$fact" >/dev/null \
    || { echo "unexpected: 2/FACT TypeDecl sketch missing"; return 0; }
  grep_prose 'Its identity is `typeId := H(enc(TypeDecl))`' "$fact" >/dev/null \
    || { echo "unexpected: 2/FACT typeId digest rule missing"; return 0; }
  docs="$(find "$root/sites/ledger/specs" -type f \( -iname '*typedecl*' -o -path '*/type-declarations/*' -o -path '*/type-decls/*' \) -print)"
  if [[ -n "$docs" ]]; then
    echo "source now has candidate TypeDecl document paths:"
    printf '%s\n' "$docs"
    return 0
  fi
  echo "blocked: 2/FACT gives a TypeDecl sketch but no byte-canonical declaration documents for R1 handles"
  return 42
}

r1_tbd_gap_probe() {
  local r1="$1"
  grep -Fq '_tbd' "$r1" \
    || { echo "R1 no longer contains _tbd_ handle rows"; return 0; }
  grep -F '`cjson/1` | _tbd' "$r1" >/dev/null \
    || { echo "unexpected: cjson/1 tbd row disappeared independently"; return 0; }
  echo "blocked: R1 still has _tbd_ rows because canonical TypeDecl bytes are not determined"
  return 43
}

queue_update_mutant_probe() {
  local root="$1" q="$root/candidates/QUEUE.md" m="$WORK/QUEUE-duplicate-open.md"
  [[ -f "$q" ]] || { echo "unexpected: staged queue missing"; return 0; }
  BOAT_ROOT="$root" QUEUE_MD="$q" bash "$root/tools/queue-lint.sh" > "$TRACES/t04-queue-positive.txt" 2>&1 \
    || { echo "unexpected: staged queue update does not lint"; cat "$TRACES/t04-queue-positive.txt"; return 0; }
  grep_prose 'R1 typeId table blocked by underdetermined canonical bytes' "$q" > "$TRACES/t04-queue-entry.txt" 2>&1 \
    || { echo "unexpected: R1 obstruction queue entry missing"; return 0; }
  cp "$q" "$m"
  printf '\n## Open\n' >> "$m"
  BOAT_ROOT="$root" QUEUE_MD="$m" bash "$root/tools/queue-lint.sh"
}

citation_mutant_probe() {
  local fact="$1" mutant="$WORK/FACT-mutant.md"
  grep_prose 'Strings as JSON strings with mandatory escaping of' "$fact" >/dev/null \
    || { echo "unexpected: cjson string rule citation does not resolve"; return 0; }
  grep_prose 'Its identity is `typeId := H(enc(TypeDecl))`' "$fact" >/dev/null \
    || { echo "unexpected: typeId digest citation does not resolve"; return 0; }
  sed 's/Its identity is `typeId := H(enc(TypeDecl))`/Its identity is removed in this mutant/' "$fact" > "$mutant"
  grep_prose 'Its identity is `typeId := H(enc(TypeDecl))`' "$mutant"
}

run_failing_probe \
  t01-cjson-control-escape-gap \
  "2/FACT section 2 leaves control-character JSON escape spelling byte-undetermined" \
  "control-character escape gap probe unexpectedly passed" \
  cjson_control_escape_gap_probe "$STAGED/sites/ledger/specs/2/README.md"

run_failing_probe \
  t02-typedecl-document-gap \
  "2/FACT section 3 requires H(enc(TypeDecl)), but no byte-canonical TypeDecl documents exist for the R1 handles" \
  "TypeDecl document gap probe unexpectedly passed" \
  typedecl_document_gap_probe "$STAGED"

run_failing_probe \
  t03-r1-tbd-gap \
  "R1 still contains _tbd_ rows; replacing them now would bind invented declaration bytes" \
  "R1 _tbd_ gap probe unexpectedly passed" \
  r1_tbd_gap_probe "$STAGED/sites/ledger/specs/registers/R1.md"

run_failing_probe \
  t04-queue-update-mutant \
  "staged queue update lints through queue-merge; duplicate-header mutant is rejected" \
  "queue update mutant unexpectedly passed queue-lint" \
  queue_update_mutant_probe "$STAGED"

run_failing_probe \
  t05-citation-mutant \
  "2/FACT rule citations resolve on source text and fail on a citation-removal mutant" \
  "citation mutant unexpectedly preserved the removed 2/FACT digest rule" \
  citation_mutant_probe "$STAGED/sites/ledger/specs/2/README.md"

attest_tail "Record the cand-0099 cjson/1 and TypeDecl byte-determination blockers instead of computing arbitrary R1 typeIds."
