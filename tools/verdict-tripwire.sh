#!/usr/bin/env bash
set -u

# verdict-tripwire: the declared verdict-reader duplication, CHECKED
# (STONE S6; discharges the cand-0025 drift-check item).
#
# tools/loop scores_verdict() and tools/eval/eval-check.sh verdict_of()
# are DELIBERATELY duplicated — a trust boundary: the reviewer's
# standalone tool must not share a code path with the loop it audits
# (unifying them would let one landing corrupt both sides of independent
# review). The cost of designed duplication is drift risk; this tripwire
# converts the duplication from declared to checked: both function
# blocks are extracted and byte-compared modulo the function-name line.
# Drift is a typed refusal — glue_non_contractible (two restrictions of
# the same semantic reader disagree; GATE-3.4-shaped at declared
# set-level profile, via the failure-class registry).
#
# Exit: 0 identical; 1 drift; 66 missing substrate.

ROOT="${BOAT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
LOOP="${TRIPWIRE_LOOP:-$ROOT/tools/loop}"
EVAL_CHECK="${TRIPWIRE_EVAL_CHECK:-$ROOT/tools/eval/eval-check.sh}"
EMIT="$ROOT/tools/eval/emit-refusal.sh"
PY="$(command -v python3 || true)"

[[ -n "$PY" && -x "$PY" ]] || { printf 'verdict-tripwire: python3 unavailable\n' >&2; exit 66; }
[[ -f "$LOOP" && -f "$EVAL_CHECK" ]] || { printf 'verdict-tripwire: reader sources missing\n' >&2; exit 66; }

if "$PY" - "$LOOP" "$EVAL_CHECK" <<'PYEOF'
import re
import sys


def block(path, name):
    src = open(path, encoding="utf-8").read()
    m = re.search(rf'^{name}\(\) \{{\n(.*?)^\}}$', src, re.S | re.M)
    if not m:
        raise SystemExit(f"verdict-tripwire: {name} not found in {path}")
    return m.group(1)


a = block(sys.argv[1], "scores_verdict")
b = block(sys.argv[2], "verdict_of")
sys.exit(0 if a == b else 1)
PYEOF
then
  printf 'verdict-tripwire: ok (scores_verdict and verdict_of byte-identical modulo name)\n'
  exit 0
fi

[[ -f "$EMIT" ]] && bash "$EMIT" glue_non_contractible tools.verdict-reader \
  "verdict-reader drift tripwire" \
  "tools/loop scores_verdict and tools/eval/eval-check.sh verdict_of have drifted — the declared duplication is a trust boundary whose copies must stay byte-identical; reconcile BOTH deliberately" \
  'null' || true
printf 'verdict-tripwire: DRIFT between scores_verdict (tools/loop) and verdict_of (eval-check.sh)\n' >&2
exit 1
