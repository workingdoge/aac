#!/usr/bin/env bash
set -u

# queue-archive: bound the queue as working memory (Yegge's lesson —
# a backlog the agent holds in context should stay small; resolved
# entries are history, not working memory). Two subcommands:
#
#   archive [QUEUE_MD] [ARCHIVE_MD]
#     Move every RESOLVED-status entry verbatim out of the working queue
#     into the archive (candidates/QUEUE-archive.md by default). Content-
#     preserving and idempotent: open entries and the preamble are
#     byte-untouched, resolved entries move verbatim, a second run is a
#     no-op. Self-checking: it computes the result, asserts that no entry
#     was lost or duplicated against the entry grammar, writes to temps,
#     and renames ONLY if the assertion holds — a failed assertion leaves
#     both files untouched and exits nonzero. The candidate STORE is never
#     touched (it is immutable evidence, like git log); only the queue's
#     working view is bounded.
#
#   check [QUEUE_MD]
#     Report the open-entry count (via the ONE canonical parser,
#     queue-lib.sh) and WARN on stderr if it exceeds a soft bound
#     (QUEUE_OPEN_BOUND, default 40). ADVISORY ONLY — exit 0 always: a
#     large backlog is a signal to triage, never a violation that should
#     block a landing. Triage of open entries stays a human judgment;
#     this tool never drops unresolved work.
#
# Exit: 0 ok (incl. check warnings, incl. archive no-op); 1 archive
#       safety assertion failed (nothing written) or usage; 66 substrate.

ROOT="${BOAT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
LIB="$ROOT/tools/queue-lib.sh"
PY="$(command -v python3 || true)"
BOUND="${QUEUE_OPEN_BOUND:-40}"

[[ -n "$PY" && -x "$PY" ]] || { printf 'queue-archive: python3 unavailable\n' >&2; exit 66; }
[[ -f "$LIB" ]] || { printf 'queue-archive: queue-lib.sh missing (the ONE canonical parser)\n' >&2; exit 66; }

cmd="${1:-}"
shift || true

case "$cmd" in

archive)
  queue="${1:-$ROOT/candidates/QUEUE.md}"
  archive="${2:-$ROOT/candidates/QUEUE-archive.md}"
  [[ -f "$queue" ]] || { printf 'queue-archive: queue not found: %s\n' "$queue" >&2; exit 66; }
  instance="$(awk -F'\t' '!/^#/ && $1 == "instance" { print $2; exit }' "$ROOT/tools/schemas/instance.tsv" 2>/dev/null)"
  [[ -n "$instance" ]] || instance="boat"
  "$PY" - "$queue" "$archive" "$instance" <<'PYEOF'
import os
import re
import sys

queue_path, archive_path, instance = sys.argv[1], sys.argv[2], sys.argv[3]
text = open(queue_path, encoding="utf-8").read()
lines = text.split("\n")
n = len(lines)


def status_of(line):
    m = re.match(r'^- \[([^\]]*)\]', line)
    if not m:
        return ""
    b = m.group(1).strip()
    return b.split(":", 1)[0].split()[0] if b else ""


out, moved = [], []
i = 0
while i < n:
    line = lines[i]
    if re.match(r'^## (.+?)\s*$', line) or not line.startswith("- ["):
        out.append(line)
        i += 1
        continue
    start = i + 1
    block = [line]
    while start < n and not lines[start].startswith("- [") and not lines[start].startswith("## "):
        block.append(lines[start])
        start += 1
    # Anti-fragmentation (review finding): a resolved entry whose block was
    # terminated by a column-0 '## ' heading would lose its tail to the
    # queue (the heading and following body strand behind). REFUSE rather
    # than fragment — the operator fixes the queue's markdown and retries.
    if status_of(line) == "resolved" and start < n and lines[start].startswith("## "):
        sys.exit("queue-archive: SAFETY FAIL — a column-0 '## ' heading interrupts a resolved "
                 "entry (line %d), which would fragment it; no column-0 '## ' may sit inside an "
                 "entry body — fix the queue and retry; nothing written" % (start + 1))
    if status_of(line) == "resolved":
        moved.append("\n".join(block))
    else:
        out.extend(block)
    i = start

# --- safety: nothing lost, nothing duplicated --------------------------------
def starts(s):
    return [ln for ln in s.split("\n") if ln.startswith("- [")]


new_queue = "\n".join(out)
# (1) LINE-multiset conservation — the unconditional no-data-loss guarantee:
# every original line appears exactly once across the kept queue and the moved
# blocks. Stronger than entry-start counting; catches any body stranding.
moved_lines = [ln for b in moved for ln in b.split("\n")]
if sorted(out + moved_lines) != sorted(lines):
    sys.exit("queue-archive: SAFETY FAIL — line multiset not conserved (a line would be lost or "
             "duplicated); nothing written")
# (2) entry-start grammar: counts balance, only resolved entries moved, each
# moved entry byte-present in the original and absent from the new queue.
orig_entries = starts(text)
moved_entries = [ln for b in moved for ln in starts(b)]
kept_entries = starts(new_queue)
if len(kept_entries) + len(moved_entries) != len(orig_entries):
    sys.exit("queue-archive: SAFETY FAIL — entry count drift (%d kept + %d moved != %d orig); nothing written"
             % (len(kept_entries), len(moved_entries), len(orig_entries)))
if any(status_of(ln) != "resolved" for ln in moved_entries):
    sys.exit("queue-archive: SAFETY FAIL — a non-resolved entry was selected for archive; nothing written")
for ln in moved_entries:
    if ln not in orig_entries or ln in kept_entries:
        sys.exit("queue-archive: SAFETY FAIL — moved entry not cleanly relocated; nothing written")

if not moved:
    print("queue-archive: nothing to archive (0 resolved entries in %s)" % os.path.basename(queue_path))
    sys.exit(0)

archived_text = "\n\n".join(b.strip("\n") for b in moved)
if os.path.isfile(archive_path):
    existing = open(archive_path, encoding="utf-8").read()
    base = existing if existing.endswith("\n") else existing + "\n"
    new_archive = base + "\n" + archived_text + "\n"
else:
    header = (
        "# %s queue archive\n\n"
        "Resolved/landed entries moved out of the working queue\n"
        "(candidates/QUEUE.md) to keep it agent-context-sized. Append-only;\n"
        "entries are verbatim. This is history, not working memory — the\n"
        "candidate store under candidates/cand-*/ remains the authoritative\n"
        "evidence. Written by tools/queue-archive.sh.\n\n"
        "## Resolved\n\n" % instance
    )
    new_archive = header + archived_text + "\n"

with open(queue_path + ".tmp", "w", encoding="utf-8") as fh:
    fh.write(new_queue)
with open(archive_path + ".tmp", "w", encoding="utf-8") as fh:
    fh.write(new_archive)
os.replace(queue_path + ".tmp", queue_path)
os.replace(archive_path + ".tmp", archive_path)
print("queue-archive: archived %d resolved entr%s; queue now %d open, %d resolved-remaining"
      % (len(moved), "y" if len(moved) == 1 else "ies",
         sum(1 for ln in kept_entries if status_of(ln) == "open"),
         sum(1 for ln in kept_entries if status_of(ln) == "resolved")))
PYEOF
  ;;

check)
  queue="${1:-$ROOT/candidates/QUEUE.md}"
  [[ -f "$queue" ]] || { printf 'queue-archive: queue not found: %s\n' "$queue" >&2; exit 66; }
  open_count="$(bash "$LIB" parse "$queue" | awk -F'\t' '$3 == "open"' | grep -c '' || true)"
  printf 'queue-archive: %s open entr%s (soft bound %s)\n' \
    "$open_count" "$([[ "$open_count" == 1 ]] && echo y || echo ies)" "$BOUND"
  if [[ "$open_count" -gt "$BOUND" ]]; then
    printf 'queue-archive: WARNING open backlog %s exceeds soft bound %s — triage the working set (resolve, defer, or drop entries); this is advisory working-memory hygiene, never a gate\n' \
      "$open_count" "$BOUND" >&2
  fi
  ;;

*)
  printf 'usage: queue-archive.sh archive [QUEUE_MD] [ARCHIVE_MD] | check [QUEUE_MD]\n' >&2
  exit 1
  ;;
esac
