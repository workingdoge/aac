#!/usr/bin/env bash
set -u

# queue-lib: the ONE canonical queue parser (STONE S4, QJ-1.1/1.5).
# Resolves the three divergent grammars (tools/loop dispatch, board.sh,
# unit-metrics.sh) and the comma-origin truncation, and — unlike all
# three — handles entries whose `(origin, date)` parenthetical WRAPS
# across lines (most resolved entries do). A READER only (QJ-1.5: never
# mutates). Emits one TSV record per entry to stdout:
#
#   line<TAB>section<TAB>status<TAB>origin<TAB>date<TAB>first_line
#
#   section : open | resolved | none   (current ## heading, lowercased)
#   status  : leading word of the bracket ([open]->open;
#             [resolved: cand-X]->resolved)
#   origin  : the full parenthetical minus its trailing ", date" (board
#             took the whole paren; unit-metrics truncated at the FIRST
#             comma — this takes origin = everything before the LAST
#             comma)
#   date    : the trailing comma field of the parenthetical
#   first_line: the entry's body up to its first line break, flattened
#
# usage: queue-lib.sh parse QUEUE_MD

cmd="${1:-}"
shift || true

case "$cmd" in
parse)
  qfile="${1:-}"
  [[ -f "$qfile" ]] || { printf 'queue-lib: file not found: %s\n' "$qfile" >&2; exit 66; }
  py="$(command -v python3 || true)"
  [[ -n "$py" && -x "$py" ]] || { printf 'queue-lib: python3 unavailable\n' >&2; exit 127; }
  "$py" - "$qfile" <<'PYEOF'
import re
import sys

# Head of an entry: "- [bracket] (paren...) ..." where the paren may not
# close on the first line. We accumulate the entry's lines until the next
# entry/section boundary, join them, then parse the head off the join.
HEAD = re.compile(r'^- \[([^\]]*)\]\s*\((.*)$', re.S)
PAREN = re.compile(r'^\((.*?)\)\s?(.*)$', re.S)

lines = open(sys.argv[1], encoding="utf-8").read().split("\n")
section = "none"
i = 0
n = len(lines)
while i < n:
    line = lines[i]
    h = re.match(r'^## (.+?)\s*$', line)
    if h:
        section = h.group(1).strip().lower()
        i += 1
        continue
    if not line.startswith("- ["):
        i += 1
        continue
    start = i + 1
    block = [line]
    while start < n and not lines[start].startswith("- [") and not lines[start].startswith("## "):
        block.append(lines[start])
        start += 1
    lineno = i + 1
    i = start
    joined = "\n".join(block)
    m = re.match(r'^- \[([^\]]*)\]\s*\((.*)$', joined, re.S)
    if not m:
        # grammar non-parse (e.g. no parenthetical): emit with empty
        # origin/date so the lint can flag it; status still extracted.
        b = re.match(r'^- \[([^\]]*)\]', joined)
        bracket = b.group(1) if b else ""
        status = bracket.strip().split(":", 1)[0].split()[0] if bracket.strip() else ""
        first = re.sub(r'[\t\n]+', ' ', joined[2:]).strip()[:200]
        print("\t".join([str(lineno), section, status, "", "", first]))
        continue
    bracket = m.group(1)
    rest = m.group(2)  # text after the opening paren, possibly multi-line
    status = bracket.strip().split(":", 1)[0].split()[0] if bracket.strip() else ""
    # close the parenthetical at the first ')'
    close = rest.find(")")
    if close < 0:
        paren, body = rest, ""
    else:
        paren, body = rest[:close], rest[close + 1:]
    paren = re.sub(r'\s+', ' ', paren).strip()
    if "," in paren:
        origin, date = paren.rsplit(",", 1)
        origin, date = origin.strip(), date.strip()
    else:
        origin, date = paren.strip(), ""
    first = re.sub(r'[\t\n]+', ' ', body).strip()[:200]
    print("\t".join([str(lineno), section, status, origin, date, first]))
PYEOF
  ;;
*)
  printf 'usage: queue-lib.sh parse QUEUE_MD\n' >&2
  exit 64
  ;;
esac
