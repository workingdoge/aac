#!/usr/bin/env bash
# eval-self.sh -- functional evidence for cand-0097.
#
# Stages the web receipt value cascade, verifies the old cand-0032 rollback
# participant_set/event_nullifier values are absent, verifies the current
# beta.14 EVENT-COMPLETE/1 public inputs are present in both cited web
# surfaces, recomputes those public inputs through the beta.14 circuit workspace
# when the pinned nargo is available, checks the web build or records the exact
# missing substrate, and verifies the queue resolution.
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

WORK="$(mktemp -d /private/tmp/aac-cand-0097.XXXXXX)"
STAGED="$WORK/root"
stage_root "$STAGED" || exit 1

WEB="$STAGED/web"
RECEIPT_TS="$WEB/src/components/aac-receipt.ts"
COMPONENTS_MDX="$WEB/src/content/docs/components.mdx"
QUEUE="$STAGED/candidates/QUEUE.md"

OLD_PARTICIPANT='0x021921c7e8447cf219adbc507e8731fc648f7d9927c5333b1f5eca25ec0c4772'
OLD_NULLIFIER='0x15ab1d0a52937434c8867e788be418a99d103322f114a67be8a8e01b3663daa0'
EVENT_COMMITMENT='0x22dde87bb42e2c0578693c0cc412f172b8ebd73de6201941f8eed299685a6d5a'
PARTICIPANT_SET='0x2be2070bf701535452f715ebd9898b4fb71a09732ae2401e05a698b227459667'
JOURNAL_COMMITMENT='0x1bd134b20563b6f8e23129e7af09640e7024b7ef5fe4619807b07f8fdab896e2'
EVENT_NULLIFIER='0x2425a832b86b32f7ad27a53c591bf3e4de047adc638caddbe8830fd7038c3545'

old_value_present() {
  local dir="$1"
  grep -R -F -q "$OLD_PARTICIPANT" "$dir" || grep -R -F -q "$OLD_NULLIFIER" "$dir"
}

check_old_absent() {
  local dir="$1"
  ! old_value_present "$dir"
}

old_absence_probe() {
  local mutant="$WORK/web-old-mutant"
  grep -R -n -F "$OLD_PARTICIPANT" "$WEB" > "$TRACES/t01-old-participant-grep.out" 2>&1 || true
  grep -R -n -F "$OLD_NULLIFIER" "$WEB" > "$TRACES/t01-old-nullifier-grep.out" 2>&1 || true
  check_old_absent "$WEB" || { echo "stale cand-0032 rollback value still present in staged web"; return 0; }
  cp -R "$WEB" "$mutant"
  printf '\n<!-- stale participant_set mutant: %s -->\n' "$OLD_PARTICIPANT" >> "$mutant/src/content/docs/components.mdx"
  if check_old_absent "$mutant"; then
    echo "old-value mutant unexpectedly passed"
    return 0
  fi
  echo "old participant_set/event_nullifier values are absent from staged web; reintroduced old participant_set mutant rejected"
  return 41
}

check_new_values_in_file() {
  local f="$1" v
  for v in "$EVENT_COMMITMENT" "$PARTICIPANT_SET" "$JOURNAL_COMMITMENT" "$EVENT_NULLIFIER"; do
    grep -Fq "$v" "$f" || return 1
  done
}

check_new_values() {
  check_new_values_in_file "$1/src/components/aac-receipt.ts" || return 1
  check_new_values_in_file "$1/src/content/docs/components.mdx" || return 1
  grep -Fq 'participant_set · tag 124' "$1/src/components/aac-receipt.ts" || return 1
  grep -Fq 'event_nullifier · tag 125' "$1/src/components/aac-receipt.ts" || return 1
  grep_prose '`participant_set` (tag 124)' "$1/src/content/docs/components.mdx" >/dev/null || return 1
  grep_prose '`event_nullifier` (tag 125)' "$1/src/content/docs/components.mdx" >/dev/null || return 1
}

new_values_probe() {
  local mutant="$WORK/web-new-mutant"
  check_new_values "$WEB" || { echo "new public inputs are missing from a cited staged web surface"; return 0; }
  cp -R "$WEB" "$mutant"
  perl -0pi -e "s/\Q$EVENT_NULLIFIER\E/0xdeadbeef/g" "$mutant/src/components/aac-receipt.ts"
  if check_new_values "$mutant"; then
    echo "new-value mutant unexpectedly passed"
    return 0
  fi
  echo "all four current public inputs are present in aac-receipt.ts and /components; event_nullifier removal mutant rejected"
  return 42
}

resolve_nargo14() {
  local p out
  for p in "${NARGO_BIN:-}" "$ROOT/result/bin/nargo" "/nix/store/hcry83mvwyxbfx9xdfz3399938jf6p6x-nargo-v1.0.0-beta.14/bin/nargo" "$(command -v nargo || true)"; do
    [[ -n "$p" && -x "$p" ]] && { printf '%s\n' "$p"; return 0; }
  done
  if command -v nix >/dev/null 2>&1; then
    out="$(cd "$ROOT" && nix build .#nargo --no-link --print-out-paths 2>"$TRACES/t03-nix-build-nargo.err")" || return 1
    p="$out/bin/nargo"
    [[ -x "$p" ]] && { printf '%s\n' "$p"; return 0; }
  fi
  return 1
}

check_recompute_output() {
  local test_out="$1" exec_out="$2" v
  grep -Fq 'nargo version = 1.0.0-beta.14' "$TRACES/t03-nargo-version.out" || return 1
  grep -Fq 'print_public_inputs' "$test_out" || return 1
  grep -Fq '5 tests passed' "$test_out" || return 1
  for v in "$EVENT_COMMITMENT" "$PARTICIPANT_SET" "$JOURNAL_COMMITMENT" "$EVENT_NULLIFIER"; do
    grep -Fq "$v" "$test_out" || return 1
  done
  grep -Fq 'Circuit witness successfully solved' "$exec_out" || return 1
}

check_recompute_blocker() {
  local f="$1"
  grep -Fq 'BLOCKER: beta.14 nargo unavailable' "$f" || return 1
  grep -Fq 'recomputation not claimed' "$f" || return 1
}

recompute_probe() {
  local nargo home test_out exec_out mutant blocker
  if nargo="$(resolve_nargo14)"; then
    home="$WORK/nargo-home"
    mkdir -p "$home"
    HOME="$home" "$nargo" --version > "$TRACES/t03-nargo-version.out" 2>&1 || return 0
    test_out="$TRACES/t03-event-complete-test.out"
    if ! ( cd "$STAGED/circuits" && HOME="$home" "$nargo" test --package event_complete --show-output ) > "$test_out" 2>&1; then
      cat "$test_out"
      return 0
    fi
    exec_out="$TRACES/t03-event-complete-execute.out"
    if ! ( cd "$STAGED/circuits" && HOME="$home" "$nargo" execute --package event_complete "$WORK/event-complete.gz" ) > "$exec_out" 2>&1; then
      cat "$exec_out"
      return 0
    fi
    check_recompute_output "$test_out" "$exec_out" || { echo "positive recomputation trace check failed"; return 0; }
    mutant="$WORK/event-complete-test-mutant.out"
    cp "$test_out" "$mutant"
    perl -0pi -e "s/\Q$PARTICIPANT_SET\E/0xdeadbeef/g" "$mutant"
    if check_recompute_output "$mutant" "$exec_out"; then
      echo "recompute-output mutant unexpectedly passed"
      return 0
    fi
    echo "beta.14 event_complete test printed all four public inputs and execute solved; participant_set trace mutant rejected"
    return 43
  fi
  blocker="$TRACES/t03-recompute-blocker.txt"
  {
    printf 'BLOCKER: beta.14 nargo unavailable in this sandbox; recomputation not claimed.\n'
    printf 'Checked NARGO_BIN, result/bin/nargo, known beta.14 store path, PATH nargo, and nix build .#nargo.\n'
  } > "$blocker"
  check_recompute_blocker "$blocker" || { echo "positive recomputation blocker check failed"; return 0; }
  mutant="$WORK/recompute-blocker-mutant.txt"
  sed 's/BLOCKER: //' "$blocker" > "$mutant"
  if check_recompute_blocker "$mutant"; then
    echo "recompute blocker mutant unexpectedly passed"
    return 0
  fi
  echo "honest recomputation blocker recorded; blocker-marker mutant rejected"
  return 43
}

paint_available() {
  [[ -n "${PAINT_BIN:-}" && -x "$PAINT_BIN" ]] && return 0
  command -v paint >/dev/null 2>&1
}

check_build_success() {
  local dist="$1" v
  [[ -f "$dist/components/index.html" ]] || return 1
  grep -R -F -q "$PARTICIPANT_SET" "$dist" || return 1
  grep -R -F -q "$EVENT_NULLIFIER" "$dist" || return 1
  for v in "$OLD_PARTICIPANT" "$OLD_NULLIFIER"; do
    ! grep -R -F -q "$v" "$dist" || return 1
  done
}

check_build_blocker() {
  local f="$1"
  grep -Fq 'BLOCKER: web build not run' "$f" || return 1
  grep -Fq 'web/node_modules/.bin/astro absent' "$f" || return 1
  grep -Fq 'syntax check passed: web/scripts/sync-specs.mjs' "$f" || return 1
}

build_probe() {
  local out mutant blocker
  if [[ -x "$WEB/node_modules/.bin/astro" ]] && paint_available; then
    out="$TRACES/t04-web-build.out"
    if ! ( cd "$WEB" && ASTRO_TELEMETRY_DISABLED=1 npm run build ) > "$out" 2>&1; then
      cat "$out"
      return 0
    fi
    check_build_success "$WEB/dist" || { echo "positive built-dist check failed"; return 0; }
    mutant="$WORK/dist-mutant"
    cp -R "$WEB/dist" "$mutant"
    grep -R -l -F "$EVENT_NULLIFIER" "$mutant" | while IFS= read -r f; do
      perl -0pi -e "s/\Q$EVENT_NULLIFIER\E/0xdeadbeef/g" "$f"
    done
    if check_build_success "$mutant"; then
      echo "built-dist mutant unexpectedly passed"
      return 0
    fi
    echo "web npm build passed; built /components carries new values and rejects event_nullifier mutant"
    return 44
  fi
  blocker="$TRACES/t04-web-build-blocker.txt"
  if ! node --check "$WEB/scripts/sync-specs.mjs" > "$TRACES/t04-node-check-sync-specs.out" 2>&1; then
    cat "$TRACES/t04-node-check-sync-specs.out"
    return 0
  fi
  {
    printf 'BLOCKER: web build not run because web/node_modules/.bin/astro absent'
    paint_available || printf ' and paint unavailable'
    printf '.\n'
    printf 'node: %s\n' "$(node --version 2>/dev/null || printf unavailable)"
    printf 'npm: %s\n' "$(npm --version 2>/dev/null || printf unavailable)"
    printf 'syntax check passed: web/scripts/sync-specs.mjs\n'
  } > "$blocker"
  check_build_blocker "$blocker" || { echo "positive web build blocker check failed"; return 0; }
  mutant="$WORK/web-build-blocker-mutant.txt"
  sed 's/BLOCKER: //' "$blocker" > "$mutant"
  if check_build_blocker "$mutant"; then
    echo "web build blocker mutant unexpectedly passed"
    return 0
  fi
  echo "web build blocker recorded with syntax-level sync-specs check; blocker-marker mutant rejected"
  return 44
}

check_queue_update() {
  local q="$1" open_count resolved_count
  BOAT_ROOT="$STAGED" QUEUE_MD="$q" bash "$STAGED/tools/queue-lint.sh" >/dev/null 2>&1 || return 1
  open_count="$(awk '$0 == "## Open" { c++ } END { print c + 0 }' "$q")"
  resolved_count="$(awk '$0 == "## Resolved" { c++ } END { print c + 0 }' "$q")"
  [[ "$open_count" == "1" && "$resolved_count" == "1" ]] || return 1
  ! grep_prose '[open] (claude, 2026-06-14) **Web `aac-receipt` value cascade (cand-0032 follow-up).' "$q" >/dev/null || return 1
  grep_prose '[resolved cand-0097-web-receipt-value-cascade, 2026-07-03] **Web `aac-receipt` value cascade (cand-0032 follow-up).' "$q" >/dev/null || return 1
  grep_prose 'participant_set `0x2be2070bf701535452f715ebd9898b4fb71a09732ae2401e05a698b227459667`' "$q" >/dev/null || return 1
  grep_prose 'event_nullifier `0x2425a832b86b32f7ad27a53c591bf3e4de047adc638caddbe8830fd7038c3545`' "$q" >/dev/null || return 1
}

queue_probe() {
  local mutant="$WORK/QUEUE-duplicate-header.md"
  check_queue_update "$QUEUE" || { echo "positive queue update check failed"; return 0; }
  cp "$QUEUE" "$mutant"
  printf '\n## Open\n' >> "$mutant"
  if BOAT_ROOT="$STAGED" QUEUE_MD="$mutant" bash "$STAGED/tools/queue-lint.sh" > "$TRACES/t05-queue-dup-header.out" 2>&1; then
    echo "duplicate-header queue mutant unexpectedly passed"
    return 0
  fi
  echo "queue resolves the web receipt value cascade and duplicate-header mutant is rejected"
  return 45
}

run_failing_probe \
  t01-old-values-absent \
  "old cand-0032 rollback participant_set/event_nullifier values are absent from staged web; reintroduction mutant rejected" \
  "old-value absence probe did not reject its mutant" \
  old_absence_probe

run_failing_probe \
  t02-new-values-present \
  "current event_commitment, participant_set, journal_commitment, and event_nullifier are present in aac-receipt.ts and /components; removal mutant rejected" \
  "new-value presence probe did not reject its mutant" \
  new_values_probe

run_failing_probe \
  t03-recompute \
  "beta.14 event_complete recomputation trace printed the four public inputs and execute solved, or an honest blocker was recorded; mutant rejected" \
  "recomputation probe did not reject its mutant" \
  recompute_probe

run_failing_probe \
  t04-web-build \
  "web build passed, or an honest build blocker with syntax-level check was recorded; mutant rejected" \
  "web build/blocker probe did not reject its mutant" \
  build_probe

run_failing_probe \
  t05-queue-update \
  "queue entry resolved and duplicate-header mutant rejected" \
  "queue update probe did not reject its mutant" \
  queue_probe

attest_tail "cand-0097 web aac-receipt value cascade: update component and /components public inputs after cand-0032 receipt tag reassignment, verify beta.14 event_complete values, build or block honestly, and resolve the queue entry."
