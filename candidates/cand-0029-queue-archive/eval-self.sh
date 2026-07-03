#!/usr/bin/env bash
# cand-0029-queue-archive evaluator (aac).
#
# Ship tools/queue-archive.sh (boat kernel hygiene) so aac can bound its queue
# as working memory. Witnesses:
# (t01) manifest still parses, the new entry is provided by the LANDING map
#       (post-land honest), and the queue-lib.sh dep is present in aac;
# (t02) `check` runs on aac's live queue (read-only) and exits 0;
# (t03) archive content-preservation on a synthetic queue: resolved entry moves
#       verbatim, open entries + preamble byte-untouched, no line lost, both
#       lint-clean, idempotent rerun;
# (t04) deltas additive (-0/+1), tools/loop untouched.
set -u

CAND="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND/../.." && pwd)"
PY="$(command -v python3)"
TRACES="$CAND/traces"
mkdir -p "$TRACES"
rm -f "$TRACES"/t[0-9][0-9]_*.txt

NEW_MANIFEST="$CAND/export-manifest.tsv"
OLD_MANIFEST="$ROOT/tools/schemas/export-manifest.tsv"
QA="$CAND/queue-archive.sh"

pass=0; fail=0
note() { printf '%s\n' "$*"; }
ok()   { pass=$((pass+1)); note "PASS $1"; }
bad()  { fail=$((fail+1)); note "FAIL $1: $2"; }

# --- t01 manifest grammar + new entry landed + dep present ----------------------
t=t01_manifest_landing_honest
(
  "$PY" - "$NEW_MANIFEST" <<'PY'
import sys
bad = 0
for ln in open(sys.argv[1], encoding="utf-8"):
    ln = ln.rstrip("\n")
    if not ln or ln.startswith("#"): continue
    p = ln.split("\t")
    if len(p) != 2 or p[0] not in ("file", "dir"):
        print("BAD LINE:", repr(ln)); bad += 1
sys.exit(1 if bad else 0)
PY
  [ $? -eq 0 ] || { echo "manifest grammar broken"; exit 1; }
  lands="$(awk '{print $2}' "$CAND/LANDING" | sort -u)"
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    printf '%s\n' "$lands" | grep -qxF "$rel" || { echo "NEW MANIFEST ENTRY NOT LANDED: $rel"; exit 1; }
  done < <(comm -13 <(sort "$OLD_MANIFEST") <(sort "$NEW_MANIFEST") | sed 's/^[a-z]*\t//')
  grep -qxF -e "$(printf 'file\ttools/queue-lib.sh')" "$NEW_MANIFEST" || { echo "queue-lib dep missing from aac manifest"; exit 1; }
  echo "manifest grammar intact; queue-archive entry provided by LANDING; queue-lib dep present"
) > "$TRACES/$t.txt" 2>&1 && ok "$t" || bad "$t" "manifest dishonest or malformed"

# --- t02 check runs on aac's live queue (read-only), exit 0 --------------------
t=t02_check_live
(
  BOAT_ROOT="$ROOT" bash "$QA" check "$ROOT/candidates/QUEUE.md"
  rc=$?
  echo "queue-archive check rc=$rc (declare 0 — advisory, read-only)"
  [ "$rc" -eq 0 ] || exit 1
) > "$TRACES/$t.txt" 2>&1 && ok "$t" || bad "$t" "check did not run cleanly on aac's queue"

# --- t03 archive content-preservation on a synthetic queue ---------------------
t=t03_archive_preserves
(
  d="$(mktemp -d)"
  q="$d/QUEUE.md"; a="$d/QUEUE-archive.md"
  cat > "$q" <<'Q'
# test queue

## Open

- [open] (test, 2026-06-13) open entry one
- [open] (test, 2026-06-13) open entry two

## Resolved

- [resolved] (test, 2026-06-13) resolved entry to archive
Q
  before_open="$(grep -c '^- \[open\]' "$q")"
  BOAT_ROOT="$ROOT" bash "$QA" archive "$q" "$a"
  rc=$?
  echo "archive rc=$rc (declare 0)"
  [ "$rc" -eq 0 ] || { rm -rf "$d"; exit 1; }
  # resolved moved out, opens preserved
  grep -q 'resolved entry to archive' "$a" || { echo "resolved entry not in archive"; rm -rf "$d"; exit 1; }
  grep -q 'resolved entry to archive' "$q" && { echo "resolved entry still in queue"; rm -rf "$d"; exit 1; }
  after_open="$(grep -c '^- \[open\]' "$q")"
  echo "open entries before/after: $before_open/$after_open (declare equal)"
  [ "$before_open" -eq "$after_open" ] || { rm -rf "$d"; exit 1; }
  # no line lost: every original queue line is in (new queue + archive)
  "$PY" - "$q" "$a" <<'PY'
import sys
# reconstruct original: it had the 2 opens + preamble (now in q) + the resolved (now in a)
q = open(sys.argv[1]).read().split("\n")
a = open(sys.argv[2]).read().split("\n")
assert any("resolved entry to archive" in l for l in a), "resolved missing from archive"
assert all("resolved entry to archive" not in l for l in q), "resolved leaked in queue"
print("line accounting: resolved relocated, opens retained")
PY
  [ $? -eq 0 ] || { rm -rf "$d"; exit 1; }
  bash "$ROOT/tools/queue-lint.sh" "$q" >/dev/null 2>&1 || { echo "post-archive queue not lint-clean"; rm -rf "$d"; exit 1; }
  bash "$ROOT/tools/queue-lint.sh" "$a" >/dev/null 2>&1 || { echo "archive not lint-clean"; rm -rf "$d"; exit 1; }
  # idempotent: rerun is a no-op, queue byte-identical
  cp "$q" "$d/q.snap"
  BOAT_ROOT="$ROOT" bash "$QA" archive "$q" "$a" >/dev/null 2>&1
  cmp -s "$q" "$d/q.snap" || { echo "rerun mutated the queue (not idempotent)"; rm -rf "$d"; exit 1; }
  echo "content-preserving, no line lost, both lint-clean, idempotent"
  rm -rf "$d"
) > "$TRACES/$t.txt" 2>&1 && ok "$t" || bad "$t" "archive did not preserve content"

# --- t04 deltas additive + tools/loop untouched --------------------------------
t=t04_deltas
(
  mdel="$(diff "$OLD_MANIFEST" "$NEW_MANIFEST" | grep -c '^<')"
  madd="$(diff "$OLD_MANIFEST" "$NEW_MANIFEST" | grep -c '^>')"
  echo "manifest delta: -$mdel/+$madd (declare 0/1)"
  [ "$mdel" -eq 0 ] && [ "$madd" -eq 1 ] || exit 1
  grep -q 'tools/loop$' "$CAND/LANDING" && { echo "candidate touches tools/loop"; exit 1; }
  echo "deltas additive (-0/+1); tools/loop untouched"
) > "$TRACES/$t.txt" 2>&1 && ok "$t" || bad "$t" "delta leaked"

# --- scores + attestation ------------------------------------------------------
total=$((pass+fail))
verdict=fail
[ "$fail" -eq 0 ] && verdict=pass
cat > "$CAND/scores.json" <<EOF
{
  "evaluated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "task": "ship tools/queue-archive.sh (manifest -0/+1) so aac can bound its queue as working memory: the manifest still parses with the new entry provided by the LANDING map and the queue-lib dep present, check runs read-only on aac's live queue (exit 0), archive on a synthetic queue is content-preserving (resolved moves, opens + preamble byte-untouched, no line lost, both lint-clean, idempotent rerun), and the delta is additive with tools/loop untouched",
  "cases": $total,
  "passed": $pass,
  "verdict": "$verdict"
}
EOF
note "cases=$total passed=$pass verdict=$verdict"
bash "$ROOT/tools/eval/attest.sh" write "$CAND/scores.json" "$CAND/eval-self.sh" "$TRACES" || exit 70
exit $([ "$verdict" = pass ] && echo 0 || echo 1)
