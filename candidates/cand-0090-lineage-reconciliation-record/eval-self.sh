#!/usr/bin/env bash
# eval-self.sh -- evidence for cand-0090-lineage-reconciliation-record.
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"

# shellcheck source=../../tools/eval/eval-lib.sh
source "$ROOT/tools/eval/eval-lib.sh"

eval_init "$CAND_DIR" "$ROOT" || exit 1
rm -rf "$TRACES"
mkdir -p "$TRACES"
: > "$RESULTS"
failures=0

WORK="$(mktemp -d /private/tmp/aac-lineage-reconciliation.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

STAGED="$WORK/staged"
stage_root "$STAGED" --apply-landing --include-candidate || {
  bad stage-root "stage_root failed to apply candidate landing"
  attest_tail "lineage reconciliation record evidence"
  exit 1
}

RECORD="$STAGED/sites/ledger/design/0005-lineage-reconciliation-record.md"
QUEUE="$STAGED/candidates/QUEUE.md"

record_probe=record-file-and-prose
record_bad=0
if [[ ! -f "$RECORD" ]]; then
  printf 'missing record file: %s\n' "$RECORD" > "$TRACES/$record_probe.out"
  record_bad=1
else
  : > "$TRACES/$record_probe.out"
  for phrase in \
    'number-only references into `cand-0037..cand-0044` are ambiguous and must cite the slug' \
    'The verified remote-wins policy is narrower than the informal summary' \
    'Memory Chain Repair' \
    'Kernel Restoration' \
    'Atlas registry mirror re-pin' \
    'Push decision for origin' \
    'Staleness triage of the three re-appended local queue entries'
  do
    if grep_prose "$phrase" "$RECORD" >> "$TRACES/$record_probe.out" 2>&1; then
      :
    else
      printf 'missing phrase: %s\n' "$phrase" >> "$TRACES/$record_probe.out"
      record_bad=1
    fi
  done
fi
if [[ "$record_bad" -eq 0 ]]; then
  pass "$record_probe" "record exists and grep_prose finds collision ambiguity, remote-wins policy, chain repair, kernel restoration, and all three follow-ups"
else
  bad "$record_probe" "record file or required prose missing; see $TRACES/$record_probe.out"
fi

record_mutant="$WORK/record-mutant.md"
if [[ -f "$RECORD" ]]; then
  sed '/remote-wins policy/d' "$RECORD" > "$record_mutant"
else
  : > "$record_mutant"
fi
run_failing_probe record-prose-mutant-fails \
  "record prose probe rejects a mutant with the remote-wins policy line removed" \
  "record prose mutant unexpectedly satisfied grep_prose" \
  bash -c 'source "$1"; grep_prose "The verified remote-wins policy is narrower than the informal summary" "$2"' \
  _ "$ROOT/tools/eval/eval-lib.sh" "$record_mutant"

cand_probe=dual-cand-0037-directories
if [[ -d "$STAGED/candidates/cand-0037-event-harness" && -d "$STAGED/candidates/cand-0037-vnet-profile-vectors" ]]; then
  pass "$cand_probe" "both cand-0037 collision directories exist in the staged root"
else
  bad "$cand_probe" "missing one or both cand-0037 collision directories"
fi
run_failing_probe dual-cand-0037-missing-fails \
  "dual-directory probe rejects a nonexistent cand-0037 slug" \
  "dual-directory mutant unexpectedly passed" \
  test -d "$STAGED/candidates/cand-0037-not-a-real-slug"

memory_probe=memory-verify-staged-root
if ( cd "$STAGED" && bash tools/memory.sh verify ) > "$TRACES/$memory_probe.out" 2>&1; then
  pass "$memory_probe" "memory.sh verify passes in the staged root"
else
  bad "$memory_probe" "memory.sh verify failed in the staged root; see $TRACES/$memory_probe.out"
fi

BROKEN_MEMORY="$WORK/broken-memory"
cp -R "$STAGED" "$BROKEN_MEMORY"
sed 's/cand-0044-pedersen-vector-profile/cand-0044-pedersen-vector-profile-mutant/' "$BROKEN_MEMORY/memory/log.jsonl" > "$BROKEN_MEMORY/memory/log.jsonl.tmp"
mv "$BROKEN_MEMORY/memory/log.jsonl.tmp" "$BROKEN_MEMORY/memory/log.jsonl"
run_failing_probe memory-body-mutation-fails \
  "memory verifier rejects a body mutation with the old hash left in place" \
  "memory verifier unexpectedly accepted a mutated record body" \
  bash -c 'cd "$1" && bash tools/memory.sh verify' _ "$BROKEN_MEMORY"

queue_probe=queue-update-well-formed
queue_bad=0
: > "$TRACES/$queue_probe.out"
if QUEUE_MD="$QUEUE" bash "$STAGED/tools/queue-lint.sh" >> "$TRACES/$queue_probe.out" 2>&1; then
  :
else
  queue_bad=1
fi
open_count="$(awk 'BEGIN{s=""} /^## Open$/{s="open"; next} /^## Resolved$/{s="resolved"; next} /^## /{s=""} s=="open" && /^- \[open\]/{c++} END{print c + 0}' "$QUEUE")"
resolved_count="$(awk 'BEGIN{s=""} /^## Open$/{s="open"; next} /^## Resolved$/{s="resolved"; next} /^## /{s=""} s=="resolved" && /^- \[resolved/{c++} END{print c + 0}' "$QUEUE")"
printf 'open_count=%s resolved_count=%s\n' "$open_count" "$resolved_count" >> "$TRACES/$queue_probe.out"
[[ "$open_count" == "24" && "$resolved_count" == "87" ]] || queue_bad=1
for phrase in \
  'Atlas registry mirror re-pin after lineage reconciliation' \
  'Origin push decision after lineage reconciliation' \
  'Staleness triage for re-appended local queue entries' \
  'resolved cand-0090-lineage-reconciliation-record'
do
  if grep_prose "$phrase" "$QUEUE" >> "$TRACES/$queue_probe.out" 2>&1; then
    :
  else
    queue_bad=1
  fi
done
if [[ "$queue_bad" -eq 0 ]]; then
  pass "$queue_probe" "queue seed lints clean, has 24 open and 87 resolved entries, and carries the cand-0090 resolved entry plus three follow-ups"
else
  bad "$queue_probe" "queue seed is malformed or missing expected cand-0090 entries; see $TRACES/$queue_probe.out"
fi

BROKEN_QUEUE="$WORK/QUEUE-duplicate-open.md"
cp "$QUEUE" "$BROKEN_QUEUE"
printf '\n## Open\n\n- [open] (codex, 2026-07-03) duplicate header mutant.\n' >> "$BROKEN_QUEUE"
run_failing_probe queue-duplicate-header-fails \
  "queue-lint rejects a duplicate ## Open header" \
  "queue-lint unexpectedly accepted a duplicate ## Open header" \
  bash -c 'QUEUE_MD="$1" bash "$2/tools/queue-lint.sh"' _ "$BROKEN_QUEUE" "$STAGED"

landing_probe=landing-map-scope
landing_bad=0
: > "$TRACES/$landing_probe.out"
for row in \
  $'seeds/sites/ledger/design/0005-lineage-reconciliation-record.md\tsites/ledger/design/0005-lineage-reconciliation-record.md' \
  $'seeds/sites/ledger/design/README.md\tsites/ledger/design/README.md' \
  $'seeds/candidates/QUEUE.md\tcandidates/QUEUE.md'
do
  if grep -Fxq "$row" "$CAND_DIR/LANDING"; then
    printf 'found landing row: %s\n' "$row" >> "$TRACES/$landing_probe.out"
  else
    printf 'missing landing row: %s\n' "$row" >> "$TRACES/$landing_probe.out"
    landing_bad=1
  fi
done
if grep -Eq $'\t(tools/|sites/premath/)| tools/| sites/premath/' "$CAND_DIR/LANDING"; then
  printf 'unexpected tier-guarded destination in LANDING\n' >> "$TRACES/$landing_probe.out"
  landing_bad=1
fi
if [[ "$(row_count "$CAND_DIR/LANDING")" == "3" && "$landing_bad" -eq 0 ]]; then
  pass "$landing_probe" "LANDING maps exactly the design note, design index, and queue seed; no tools or premath destinations"
else
  bad "$landing_probe" "LANDING scope is wrong; see $TRACES/$landing_probe.out"
fi
run_failing_probe landing-missing-row-fails \
  "landing scope probe rejects a missing record landing row" \
  "landing missing-row mutant unexpectedly passed" \
  bash -c 'grep -Fxq "$1" "$2"' _ \
  $'seeds/sites/ledger/design/0005-lineage-reconciliation-record.md\tsites/ledger/design/0005-lineage-reconciliation-record.md' \
  "$WORK/no-such-landing"

synth_probe=make-synth-helper
SYNTH_ROOT="$WORK/synth-root"
mkdir -p "$SYNTH_ROOT/candidates"
if make_synth "$SYNTH_ROOT" cand-9999-lineage-synthetic open "synthetic lineage probe" > "$TRACES/$synth_probe.out" 2>&1; then
  pass "$synth_probe" "make_synth creates a minimal synthetic candidate for the evaluator scratch space"
else
  bad "$synth_probe" "make_synth failed in scratch space; see $TRACES/$synth_probe.out"
fi
run_failing_probe make-synth-duplicate-fails \
  "make_synth refuses to overwrite an existing synthetic candidate" \
  "make_synth unexpectedly overwrote an existing synthetic candidate" \
  bash -c 'source "$1"; make_synth "$2" cand-9999-lineage-synthetic open "duplicate synthetic probe"' \
  _ "$ROOT/tools/eval/eval-lib.sh" "$SYNTH_ROOT"

attest_tail "lineage reconciliation record evidence"
