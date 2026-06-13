#!/usr/bin/env bash
set -u

# queue-lint: lint candidates/QUEUE.md as a record surface (STONE S4,
# QJ-1.1/1.2). Reads through the ONE canonical parser (queue-lib.sh).
#
# FAIL-CLOSED (exit 1) on the one clean, enforceable invariant:
#   - QJ-1.1 status vocabulary — every entry's status is in
#     tools/schemas/queue-status.vocab (open|resolved). The loop's
#     appenders only ever write `open`, so this is green by construction;
#     a foreign status is a vocabulary-atom-failure.
#   - grammar: every `- [` entry parses to a non-empty status.
#
# REPORT-ONLY (exit 0, findings to stderr) on the invariants with
# grandfathered exceptions — the queue is load-bearing authored prose,
# not a store (QJ Boundary), so these are surfaced, not gated:
#   - QJ-1.2 section discipline (a resolved entry under ## Open, etc.);
#   - origin parseability.
# `--strict` promotes the report-only findings to fail-closed (for a
# future cleaned queue); the evaluate-landed suite runs the default mode.
#
# Refusals are typed via emit-refusal.sh (witnessIds minted).
# Exit: 0 clean (or only report-only findings); 1 fail-closed violation;
# 66 missing substrate.

ROOT="${BOAT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
QUEUE="${QUEUE_MD:-$ROOT/candidates/QUEUE.md}"
LIB="$ROOT/tools/queue-lib.sh"
VOCAB="$ROOT/tools/schemas/queue-status.vocab"
EMIT="$ROOT/tools/eval/emit-refusal.sh"

strict=no
[[ "${1:-}" == "--strict" ]] && strict=yes

# --all (suite mode): pin the statement's QJ laws (required-text, the
# house pattern), run the fixture pass/fail corpus, then lint the live
# queue in report mode. One suite member covers theory + fixtures + live.
if [[ "${1:-}" == "--all" ]]; then
  stmt="$ROOT/sites/premath/statements/queue-judgments-v0.md"
  fixdir="${QJ_FIXTURE_DIR:-$ROOT/sites/premath/fixtures}"
  rc=0
  printf 'statement: queue-judgments-v0.md\n'
  if [[ -f "$stmt" ]]; then
    for needle in 'Statement id: `premath.queue-judgments.v0`' \
      'Law: QJ-1.1' 'Law: QJ-1.2' 'Law: QJ-1.3' 'Law: QJ-1.4' 'Law: QJ-1.5' \
      'QueueStatusVocab' 'Projection never authorizes' 'LAW-FOR-LATER' \
      'never executable authority'; do
      grep -Fq "$needle" "$stmt" || { printf '  MISSING: %s\n' "$needle" >&2; rc=1; }
    done
    [[ "$rc" -eq 0 ]] && printf '  result: accepted\n'
  else
    printf '  MISSING statement\n' >&2; rc=1
  fi
  # fixtures: clean passes default; bad-status fails; misfiled passes
  # default but fails --strict
  if [[ -f "$fixdir/queue-clean-pass.md" ]]; then
    QUEUE_MD="$fixdir/queue-clean-pass.md" bash "$0" >/dev/null 2>&1 \
      || { printf '  FIXTURE queue-clean-pass should pass\n' >&2; rc=1; }
    QUEUE_MD="$fixdir/queue-bad-status-fail.md" bash "$0" >/dev/null 2>&1 \
      && { printf '  FIXTURE queue-bad-status-fail should fail\n' >&2; rc=1; }
    QUEUE_MD="$fixdir/queue-misfiled-report.md" bash "$0" >/dev/null 2>&1 \
      || { printf '  FIXTURE queue-misfiled-report should pass in default mode\n' >&2; rc=1; }
    QUEUE_MD="$fixdir/queue-misfiled-report.md" bash "$0" --strict >/dev/null 2>&1 \
      && { printf '  FIXTURE queue-misfiled-report should fail under --strict\n' >&2; rc=1; }
    printf 'fixtures: %s\n' "$([[ "$rc" -eq 0 ]] && echo accepted || echo rejected)"
  fi
  # live queue (report mode; never blocks the suite)
  bash "$0" || rc=1
  exit "$rc"
fi

[[ -f "$QUEUE" ]] || { printf 'queue-lint: no QUEUE.md at %s\n' "$QUEUE" >&2; exit 66; }
[[ -f "$LIB" ]] || { printf 'queue-lint: queue-lib.sh missing\n' >&2; exit 66; }
[[ -f "$EMIT" ]] || { printf 'queue-lint: emit-refusal.sh missing\n' >&2; exit 66; }

vocab_list=""
if [[ -f "$VOCAB" ]]; then
  vocab_list="$(grep -vE '^#|^[[:space:]]*$' "$VOCAB" | tr '\n' ' ')"
else
  vocab_list="open resolved"
fi

hard=0
soft=0
refuse() { # CLASS TOKEN REASON
  bash "$EMIT" "$1" "$2" "QJ queue lint" "$3" 'null' \
    || printf 'queue-lint: emission degraded for %s\n' "$2" >&2
}

while IFS=$'\t' read -r lineno section status origin date first; do
  [[ -n "$lineno" ]] || continue
  # grammar: status must be non-empty
  if [[ -z "$status" ]]; then
    refuse record-formation-incomplete "QUEUE.line.$lineno" "entry does not parse to a status"
    hard=$((hard+1))
    continue
  fi
  # QJ-1.1 status vocabulary (fail-closed)
  in_vocab=no
  for v in $vocab_list; do [[ "$status" == "$v" ]] && { in_vocab=yes; break; }; done
  if [[ "$in_vocab" != yes ]]; then
    refuse vocabulary-atom-failure "QUEUE.line.$lineno.status" "status '$status' out of vocabulary (allowed: $vocab_list)"
    hard=$((hard+1))
    continue
  fi
  # QJ-1.2 section discipline (report-only unless --strict)
  if { [[ "$section" == open && "$status" != open ]] || [[ "$section" == resolved && "$status" != resolved ]]; }; then
    if [[ "$strict" == yes ]]; then
      refuse record-formation-incomplete "QUEUE.line.$lineno.section" "status '$status' misfiled under ## ${section^}"
      hard=$((hard+1))
    else
      printf 'queue-lint: REPORT line %s: %s entry under ## %s (QJ-1.2 misfiling)\n' "$lineno" "$status" "${section^}" >&2
      soft=$((soft+1))
    fi
  fi
  # origin parseability (report-only)
  if [[ -z "$origin" ]]; then
    if [[ "$strict" == yes ]]; then
      refuse record-formation-incomplete "QUEUE.line.$lineno.origin" "entry has no parseable origin"
      hard=$((hard+1))
    else
      printf 'queue-lint: REPORT line %s: no parseable origin\n' "$lineno" >&2
      soft=$((soft+1))
    fi
  fi
done < <(bash "$LIB" parse "$QUEUE")

if [[ "$hard" -gt 0 ]]; then
  printf 'queue-lint: %s fail-closed violation(s), %s report-only finding(s)\n' "$hard" "$soft" >&2
  exit 1
fi
printf 'queue-lint: ok (status vocabulary clean; %s report-only finding(s))\n' "$soft"
