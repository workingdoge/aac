#!/usr/bin/env bash
set -u

# queue-merge: three-way merge for candidates/QUEUE.md landing rows.
#
# Usage:
#   queue-merge.sh candidates/QUEUE.md BASE SEED LIVE OUT
#
# Exit classes:
#   64 usage or non-QUEUE destination
#   65 malformed queue section surface
#   66 merge conflict
#   67 merged result fails queue-lint

ROOT="${BOAT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

die() {
  local rc="$1"
  shift
  printf 'queue-merge: %s\n' "$*" >&2
  exit "$rc"
}

dest="${1:-}"
base="${2:-}"
seed="${3:-}"
live="${4:-}"
out="${5:-}"

[[ -n "$dest" && -n "$base" && -n "$seed" && -n "$live" && -n "$out" ]] \
  || die 64 "usage: queue-merge.sh candidates/QUEUE.md BASE SEED LIVE OUT"
[[ "$dest" == "candidates/QUEUE.md" ]] \
  || die 64 "queue-merge kind is only valid for candidates/QUEUE.md; got $dest"
[[ -f "$base" && -f "$seed" && -f "$live" ]] \
  || die 65 "BASE, SEED, and LIVE must all exist; refresh QUEUE.base + re-seed + re-brief"

tmp="$(mktemp)"
python3 - "$base" "$seed" "$live" "$tmp" <<'PYEOF'
import re
import sys

base_path, seed_path, live_path, out_path = sys.argv[1:5]
SECTIONS = ("Open", "Resolved")
HEADERS = {name: "## " + name for name in SECTIONS}


class QueueError(Exception):
    def __init__(self, code, message):
        super().__init__(message)
        self.code = code


def read_lines(path):
    with open(path, encoding="utf-8", errors="surrogateescape") as fh:
        return fh.readlines()


def key_for(block):
    first = block[0].rstrip("\n\r")
    norm = re.sub(r"\s+", " ", first).strip()
    return norm[:100]


def parse_queue(path):
    lines = read_lines(path)
    header_positions = {}
    for idx, line in enumerate(lines):
        stripped = line.rstrip("\n\r")
        if stripped in HEADERS.values():
            header_positions.setdefault(stripped[3:], []).append(idx)
    for section in SECTIONS:
        count = len(header_positions.get(section, []))
        if count != 1:
            raise QueueError(
                65,
                "%s malformed: expected exactly one ## %s header, found %s; "
                "refresh QUEUE.base + re-seed + re-brief"
                % (path, section, count),
            )

    section_data = {}
    sorted_headers = sorted(
        (positions[0], section)
        for section, positions in header_positions.items()
        if section in SECTIONS
    )
    for pos, section in sorted_headers:
        end = len(lines)
        for idx in range(pos + 1, len(lines)):
            if lines[idx].startswith("## "):
                end = idx
                break
        body = lines[pos + 1:end]
        prefix = []
        tail = []
        entries = []
        seen_keys = set()
        i = 0
        while i < len(body) and not body[i].startswith("- ["):
            prefix.append(body[i])
            i += 1
        while i < len(body):
            if not body[i].startswith("- ["):
                tail = body[i:]
                break
            start = i
            i += 1
            while i < len(body) and not body[i].startswith("- ["):
                i += 1
            block = body[start:i]
            key = key_for(block)
            if key in seen_keys:
                raise QueueError(
                    65,
                    "%s malformed: duplicate queue entry key %r; "
                    "refresh QUEUE.base + re-seed + re-brief" % (path, key),
                )
            seen_keys.add(key)
            entries.append({"key": key, "block": block})
        section_data[section] = {
            "header_index": pos,
            "end_index": end,
            "header": lines[pos],
            "prefix": prefix,
            "tail": tail,
            "entries": entries,
        }
    return {"lines": lines, "sections": section_data, "headers": sorted_headers}


def by_key(parsed, section):
    return {entry["key"]: entry["block"] for entry in parsed["sections"][section]["entries"]}


def merged_section(base, seed, live, section):
    base_map = by_key(base, section)
    seed_map = by_key(seed, section)
    live_map = by_key(live, section)
    out_entries = [
        {"key": entry["key"], "block": list(entry["block"])}
        for entry in live["sections"][section]["entries"]
    ]
    out_keys = [entry["key"] for entry in out_entries]

    def index_of(key):
        for idx, entry in enumerate(out_entries):
            if entry["key"] == key:
                return idx
        return None

    for key in base_map:
        if key not in seed_map:
            idx = index_of(key)
            if idx is not None:
                del out_entries[idx]

    for key in base_map:
        if key in seed_map and seed_map[key] != base_map[key]:
            if live_map.get(key) != base_map[key]:
                raise QueueError(
                    66,
                    "conflict on %s entry %r; refresh QUEUE.base + re-seed + re-brief"
                    % (section, key),
                )
            idx = index_of(key)
            if idx is None:
                raise QueueError(
                    66,
                    "conflict on %s entry %r; refresh QUEUE.base + re-seed + re-brief"
                    % (section, key),
                )
            out_entries[idx] = {"key": key, "block": list(seed_map[key])}

    for entry in seed["sections"][section]["entries"]:
        key = entry["key"]
        if key in base_map:
            continue
        if key in live_map or key in out_keys:
            continue
        out_entries.append({"key": key, "block": list(entry["block"])})
        out_keys.append(key)

    return out_entries


def render(base, seed, live):
    rendered_sections = {
        section: merged_section(base, seed, live, section)
        for section in SECTIONS
    }
    lines = []
    cursor = 0
    for header_idx, section in live["headers"]:
        lines.extend(live["lines"][cursor:header_idx + 1])
        data = live["sections"][section]
        lines.extend(data["prefix"])
        for entry in rendered_sections[section]:
            lines.extend(entry["block"])
        lines.extend(data["tail"])
        cursor = data["end_index"]
    lines.extend(live["lines"][cursor:])
    return lines


try:
    base = parse_queue(base_path)
    seed = parse_queue(seed_path)
    live = parse_queue(live_path)
    merged = render(base, seed, live)
    with open(out_path, "w", encoding="utf-8", errors="surrogateescape") as fh:
        fh.writelines(merged)
except QueueError as exc:
    print("queue-merge: %s" % exc, file=sys.stderr)
    sys.exit(exc.code)
PYEOF
rc=$?
if [[ "$rc" -ne 0 ]]; then
  rm -f "$tmp"
  exit "$rc"
fi

if ! QUEUE_MD="$tmp" bash "$ROOT/tools/queue-lint.sh" >/dev/null 2>&1; then
  rm -f "$tmp"
  die 67 "merged queue failed tools/queue-lint.sh; refresh QUEUE.base + re-seed + re-brief"
fi

mv "$tmp" "$out" || die 1 "could not write merged output: $out"
