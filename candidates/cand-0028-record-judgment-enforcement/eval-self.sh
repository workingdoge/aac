#!/usr/bin/env bash
# cand-0028-record-judgment-enforcement evaluator (aac).
#
# aac enrolls run_suite record-judgments in evaluate-landed.sh but the checker
# is absent, so the guard is false and the law is silently skipped. This ships
# the checker + its 8-fixture ALL_FIXTURES closure so the guard flips true.
# Witnesses:
# (t01) the manifest still parses and every new entry is covered by the LANDING
#       map (post-land honesty — names only files this candidate ships);
# (t02) the shipped checker + 8 fixtures RUN green against aac's live statement
#       (the law is enforceable here);
# (t03) the guard footgun: the checker is currently ABSENT in live aac so the
#       enrolled record-judgments member is skipped; the candidate provides it;
# (t04) abroad-enforcement mutant: a corrupted shipped fixture makes --all FAIL;
# (t05) deltas confined/additive (-0/+9, statement not re-added, loop untouched).
set -u

CAND="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND/../.." && pwd)"
PY="$(command -v python3)"
TRACES="$CAND/traces"
mkdir -p "$TRACES"
rm -f "$TRACES"/t[0-9][0-9]_*.txt

NEW_MANIFEST="$CAND/export-manifest.tsv"
OLD_MANIFEST="$ROOT/tools/schemas/export-manifest.tsv"
CARGO_CHECKER="$CAND/record-judgment-check.sh"
CARGO_FIXTURES="$CAND/fixtures"
STATEMENT="$ROOT/sites/premath/statements/record-judgments-v0.md"

pass=0; fail=0
note() { printf '%s\n' "$*"; }
ok()   { pass=$((pass+1)); note "PASS $1"; }
bad()  { fail=$((fail+1)); note "FAIL $1: $2"; }

# --- t01 manifest grammar + every new entry covered by the LANDING map ---------
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
  # destinations the LANDING map provides (post-land these will be real)
  lands="$(awk '{print $2}' "$CAND/LANDING" | sort -u)"
  miss=0
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    printf '%s\n' "$lands" | grep -qxF "$rel" || { echo "NEW MANIFEST ENTRY NOT LANDED: $rel"; miss=$((miss+1)); }
  done < <(comm -13 <(sort "$OLD_MANIFEST") <(sort "$NEW_MANIFEST") | sed 's/^[a-z]*\t//')
  [ "$miss" -eq 0 ] || exit 1
  echo "manifest grammar intact; all 9 new entries are provided by the LANDING map (post-land honest)"
) > "$TRACES/$t.txt" 2>&1 && ok "$t" || bad "$t" "manifest dishonest or malformed"

# --- t02 the shipped closure RUNS green against aac's statement -----------------
t=t02_enforceable_in_aac
(
  n="$(ls "$CARGO_FIXTURES"/record-*.md 2>/dev/null | grep -c .)"
  echo "shipped fixtures: $n (declare 8)"
  [ "$n" -eq 8 ] || { echo "expected 8 fixtures"; exit 1; }
  RJ_STATEMENT="$STATEMENT" RJ_FIXTURE_DIR="$CARGO_FIXTURES" bash "$CARGO_CHECKER" --all
  rc=$?
  echo "record-judgment-check --all rc=$rc (declare 0 — enforceable against aac's statement)"
  [ "$rc" -eq 0 ] || exit 1
) > "$TRACES/$t.txt" 2>&1 && ok "$t" || bad "$t" "shipped closure does not pass in aac"

# --- t03 the guard footgun: absent now -> provided by this candidate -----------
t=t03_guard_footgun
(
  grep -q 'record-judgment-check.sh' "$ROOT/tools/eval/evaluate-landed.sh" \
    || { echo "aac does not even enroll the record-judgments member"; exit 1; }
  if [ -f "$ROOT/tools/record-judgment-check.sh" ]; then
    echo "checker already present in live aac — nothing to fix?"; exit 1; fi
  echo "BEFORE: evaluate-landed enrolls record-judgments guarded by [[ -f tools/record-judgment-check.sh ]]; that file is ABSENT in live aac -> member SILENTLY SKIPPED (the footgun)"
  grep -qxF "record-judgment-check.sh tools/record-judgment-check.sh" "$CAND/LANDING" \
    || { echo "candidate does not land the checker"; exit 1; }
  echo "AFTER: this candidate LANDS tools/record-judgment-check.sh -> guard flips true -> member runs post-land"
) > "$TRACES/$t.txt" 2>&1 && ok "$t" || bad "$t" "guard differential not demonstrated"

# --- t04 abroad-enforcement mutant: corrupt a shipped fixture -> --all fails ----
t=t04_enforcement_real
(
  d="$(mktemp -d)"
  cp "$CARGO_FIXTURES"/record-*.md "$d/"
  echo "BROKEN" > "$d/record-meta-telescope-pass-v0.md"
  RJ_STATEMENT="$STATEMENT" RJ_FIXTURE_DIR="$d" bash "$CARGO_CHECKER" --all >/dev/null 2>&1
  rc=$?
  rm -rf "$d"
  echo "record-judgment-check --all on a corrupted corpus rc=$rc (declare nonzero — enforcement is real)"
  [ "$rc" -ne 0 ] || exit 1
) > "$TRACES/$t.txt" 2>&1 && ok "$t" || bad "$t" "corrupted fixture did not fail the checker"

# --- t05 deltas confined + statement single + loop untouched -------------------
t=t05_deltas
(
  mdel="$(diff "$OLD_MANIFEST" "$NEW_MANIFEST" | grep -c '^<')"
  madd="$(diff "$OLD_MANIFEST" "$NEW_MANIFEST" | grep -c '^>')"
  echo "manifest delta: -$mdel/+$madd (declare 0/9)"
  [ "$mdel" -eq 0 ] && [ "$madd" -eq 9 ] || exit 1
  sc="$(grep -c 'sites/premath/statements/record-judgments-v0.md' "$NEW_MANIFEST")"
  echo "statement entries: $sc (declare 1 — not re-added)"
  [ "$sc" -eq 1 ] || exit 1
  grep -q 'tools/loop$' "$CAND/LANDING" && { echo "candidate touches tools/loop"; exit 1; }
  echo "deltas additive (-0/+9); statement single; tools/loop untouched"
) > "$TRACES/$t.txt" 2>&1 && ok "$t" || bad "$t" "delta leaked"

# --- scores + attestation ------------------------------------------------------
total=$((pass+fail))
verdict=fail
[ "$fail" -eq 0 ] && verdict=pass
cat > "$CAND/scores.json" <<EOF
{
  "evaluated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "task": "ship tools/record-judgment-check.sh + its 8-fixture ALL_FIXTURES closure (manifest -0/+9) so aac enforces premath.record-judgments.v0 instead of silently skipping it: the manifest still parses with every new entry provided by the LANDING map, the shipped checker + fixtures run --all green against aac's byte-identical statement, the evaluate-landed guard is currently false (checker absent -> member skipped, the footgun) and this candidate lands the checker to flip it true, a corrupted shipped fixture makes --all fail (enforcement real not vacuous), and deltas are additive with the statement not re-added and tools/loop untouched",
  "cases": $total,
  "passed": $pass,
  "verdict": "$verdict"
}
EOF
note "cases=$total passed=$pass verdict=$verdict"
bash "$ROOT/tools/eval/attest.sh" write "$CAND/scores.json" "$CAND/eval-self.sh" "$TRACES" || exit 70
exit $([ "$verdict" = pass ] && echo 0 || echo 1)
