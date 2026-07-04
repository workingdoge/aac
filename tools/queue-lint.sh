#!/usr/bin/env bash
set -u

# queue-lint: lint candidates/QUEUE.md as a record surface (STONE S4,
# QJ-1.1/1.2). Reads through the ONE canonical parser (queue-lib.sh).
#
# FAIL-CLOSED (exit 1) on the one clean, enforceable invariant:
#   - QJ-1.2 section cardinality — exactly one literal `## Open` header and
#     exactly one literal `## Resolved` header. Duplicate/missing sections make
#     later appends ambiguous, so this is record formation, not report-only.
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
#   - owner-split mirror drift: open queue entries that look like work items
#     but carry no canonical tracker ref (`issue:<scope>:<n>`) or bd
#     provenance ref (`external(bd:...)` / `bd:<id>`).
# `--strict` promotes the report-only findings to fail-closed (for a
# future cleaned queue), except the owner-split mirror check, which is always
# report-only. The evaluate-landed suite runs the default mode.
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

# Portable capitalize-first: macOS ships bash 3.2, which has no ${var^} (a
# bash 4.0+ idiom — on 3.2 it is a "bad substitution" that silently aborts the
# strict-reject path, so the misfiling guard never fires). The section name is
# only ever open|resolved (the ## headings), so a case mapping is exact.
cap() { case "$1" in open) printf 'Open' ;; resolved) printf 'Resolved' ;; *) printf '%s' "$1" ;; esac; }

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
    QUEUE_MD="$fixdir/queue-duplicate-open-fail.md" bash "$0" >/dev/null 2>&1 \
      && { printf '  FIXTURE queue-duplicate-open-fail should fail\n' >&2; rc=1; }
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

open_headers="$(awk '$0 == "## Open" { c++ } END { print c + 0 }' "$QUEUE")"
resolved_headers="$(awk '$0 == "## Resolved" { c++ } END { print c + 0 }' "$QUEUE")"
if [[ "$open_headers" -ne 1 ]]; then
  refuse record-formation-incomplete "QUEUE.section.Open" "expected exactly one ## Open header, found $open_headers"
  hard=$((hard+1))
fi
if [[ "$resolved_headers" -ne 1 ]]; then
  refuse record-formation-incomplete "QUEUE.section.Resolved" "expected exactly one ## Resolved header, found $resolved_headers"
  hard=$((hard+1))
fi

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
      refuse record-formation-incomplete "QUEUE.line.$lineno.section" "status '$status' misfiled under ## $(cap "$section")"
      hard=$((hard+1))
    else
      printf 'queue-lint: REPORT line %s: %s entry under ## %s (QJ-1.2 misfiling)\n' "$lineno" "$status" "$(cap "$section")" >&2
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

mirror_findings="$(python3 - "$QUEUE" <<'PYEOF' 2>/dev/null || true
import re
import sys

try:
    lines = open(sys.argv[1], encoding="utf-8").read().splitlines()
except OSError:
    sys.exit(0)

TRACKER_REF = re.compile(r"\bissue:(?:workspace|instance-[^:\s/]+):[1-9][0-9]*\b")
BD_REF = re.compile(r"\b(?:external\(bd:[^)]+\)|bd:[A-Za-z0-9._-]+)\b")
ACTION = re.compile(
    r"\b(add|admit|build|carry|close|consume|create|fix|implement|land|migrate|"
    r"produce|prove|replace|retire|run|sync|transport|update|wire)\b|"
    r"\b(must|needs?|should)\b",
    re.I,
)
HOLDER = re.compile(r"\b(holder[- ]?to[- ]?be|owner|assignee|worker|agent|operator|codex|claude)\b", re.I)
RECORD_MARKER = re.compile(
    r"course record of what happened|landing recorded|names no remaining work|"
    r"audit transcript|close-out ledger",
    re.I,
)

def origin_for(block):
    joined = "\n".join(block)
    m = re.match(r"^- \[[^\]]+\]\s*\((.*)$", joined, re.S)
    if not m:
        return ""
    rest = m.group(1)
    close = rest.find(")")
    paren = rest if close < 0 else rest[:close]
    paren = re.sub(r"\s+", " ", paren).strip()
    return paren.rsplit(",", 1)[0].strip() if "," in paren else paren

def first_body_line(block):
    joined = "\n".join(block)
    m = re.match(r"^- \[[^\]]+\]\s*(?:\([^)]*\))?\s*(.*)$", joined, re.S)
    body = m.group(1) if m else joined
    return re.sub(r"\s+", " ", body).strip()[:160]

def lifecycle_record(origin, text):
    low = origin.lower()
    return low.startswith("dispatch escalation") or low.startswith("reflect ") or RECORD_MARKER.search(text)

def work_item_shaped(origin, text):
    holderish = HOLDER.search(text) or re.match(r"^(agent:|codex|claude|operator\b)", origin, re.I)
    return bool(holderish and ACTION.search(text))

section = None
i = 0
while i < len(lines):
    line = lines[i]
    h = re.match(r"^## (.+?)\s*$", line)
    if h:
        section = h.group(1).strip().lower()
        i += 1
        continue
    if not line.startswith("- ["):
        i += 1
        continue
    start = i + 1
    block = [line]
    i += 1
    while i < len(lines) and not lines[i].startswith("- [") and not lines[i].startswith("## "):
        block.append(lines[i])
        i += 1
    joined = "\n".join(block)
    if section != "open" or not block[0].startswith("- [open]"):
        continue
    if TRACKER_REF.search(joined) or BD_REF.search(joined):
        continue
    origin = origin_for(block)
    if lifecycle_record(origin, joined):
        continue
    if work_item_shaped(origin, joined):
        print(f"{start}\t{first_body_line(block)}")
PYEOF
)"
if [[ -n "$mirror_findings" ]]; then
  while IFS=$'\t' read -r lineno first; do
    [[ -n "$lineno" ]] || continue
    printf 'queue-lint: REPORT line %s: open work-item-shaped entry has no tracker ref token (owner-split mirror): %s\n' "$lineno" "$first" >&2
    soft=$((soft+1))
  done <<< "$mirror_findings"
fi

if [[ "$hard" -gt 0 ]]; then
  printf 'queue-lint: %s fail-closed violation(s), %s report-only finding(s)\n' "$hard" "$soft" >&2
  exit 1
fi
printf 'queue-lint: ok (status vocabulary clean; %s report-only finding(s))\n' "$soft"
