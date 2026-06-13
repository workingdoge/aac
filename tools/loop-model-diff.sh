#!/usr/bin/env bash
set -u

# loop-model-diff: the differential between the two models of the loop
# (premath.loop-model.v0 LM-1.2/LM-1.5; STONE S8).
#
# Ground truth is the LIVE bash loop executed in a scratch root (a copy
# of tools/, flake.lock, and the one record under test — never the live
# store); the prediction is tools/loop-model.py read-only over the
# pristine record. Surfaces compared per LM-1.2:
#
#   validate        VALIDATE.json byte-identical + exit status + post META status
#   scores_verdict  full contract token (reader extracted from the loop
#                   under test, tripwire-style; never re-coded here)
#   auto            first-refusal-point token (die text mapped via the
#                   ground_truth_match patterns in loop-laws.json)
#   reflect         assessment token + basis line
#
# Any disagreement on any surface is a typed refusal:
# model_coherence_failure (GATE-3.5 shaped). Exit: 0 full agreement;
# 1 disagreement; 66 missing substrate (model, laws, loop, or corpus).
#
# usage: loop-model-diff.sh [--fixtures|--store|--all] [--keep]
#   --fixtures  sites/premath/fixtures/loop-model/fix-*/   (default;
#               the evaluate-landed suite member runs this mode)
#   --store     every candidates/cand-*/ with a META
#   --all       both
#
# env (evaluation harness knobs; defaults are the live surfaces):
#   LOOP_MODEL_BIN, LOOP_MODEL_LAWS, LOOP_MODEL_LOOP, LOOP_MODEL_FIXTURE_DIR

TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${BOAT_ROOT:-$(cd "$TOOLS_DIR/.." && pwd)}"

MODEL="${LOOP_MODEL_BIN:-$ROOT/tools/loop-model.py}"
LAWS="${LOOP_MODEL_LAWS:-$ROOT/tools/schemas/loop-laws.json}"
LOOP_SRC="${LOOP_MODEL_LOOP:-$ROOT/tools/loop}"
FIXDIR="${LOOP_MODEL_FIXTURE_DIR:-$ROOT/sites/premath/fixtures/loop-model}"
EMIT="$ROOT/tools/eval/emit-refusal.sh"
PY="$(command -v python3 || true)"

mode="fixtures"
keep=0
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --fixtures) mode="fixtures"; shift ;;
    --store) mode="store"; shift ;;
    --all) mode="all"; shift ;;
    --keep) keep=1; shift ;;
    *) printf 'loop-model-diff: unknown argument: %s\n' "$1" >&2; exit 64 ;;
  esac
done

[[ -n "$PY" && -x "$PY" ]] || { printf 'loop-model-diff: python3 unavailable\n' >&2; exit 66; }
[[ -f "$MODEL" && -f "$LAWS" && -f "$LOOP_SRC" ]] || {
  printf 'loop-model-diff: substrate missing (model, laws, or loop)\n' >&2; exit 66; }

records=()
if [[ "$mode" == "fixtures" || "$mode" == "all" ]]; then
  for d in "$FIXDIR"/fix-*/; do
    [[ -d "$d" && -f "$d/META" ]] && records+=("${d%/}")
  done
fi
if [[ "$mode" == "store" || "$mode" == "all" ]]; then
  for d in "$ROOT"/candidates/cand-*/; do
    [[ -d "$d" && -f "$d/META" ]] && records+=("${d%/}")
  done
fi
[[ "${#records[@]}" -gt 0 ]] || {
  printf 'loop-model-diff: empty corpus for mode %s (fixtures at %s)\n' "$mode" "$FIXDIR" >&2
  exit 66
}

# Ground-truth scores_verdict reader: extracted from the loop UNDER TEST
# (tripwire-style block extraction) so this harness never re-codes the
# reader it is comparing against.
SVRUN="$(mktemp)"
if ! "$PY" - "$LOOP_SRC" > "$SVRUN" <<'PYEOF'
import re
import sys

src = open(sys.argv[1], encoding="utf-8").read()
m = re.search(r'^scores_verdict\(\) \{\n.*?^\}$', src, re.S | re.M)
if not m:
    raise SystemExit("loop-model-diff: scores_verdict not found in loop under test")
print("#!/usr/bin/env bash")
print(m.group(0))
print('scores_verdict "$1"')
PYEOF
then
  rm -f "$SVRUN"
  printf 'loop-model-diff: could not extract scores_verdict from %s\n' "$LOOP_SRC" >&2
  exit 66
fi

# Auto-chain ground-truth mapping (token + die-text pattern, chain order)
# comes from the laws file — data, not harness-local vocabulary.
AUTOMAP="$(mktemp)"
"$PY" - "$LAWS" > "$AUTOMAP" <<'PYEOF'
import json
import sys

laws = json.load(open(sys.argv[1], encoding="utf-8"))
for entry in laws["auto"]["chain"]:
    token = entry.get("refusal") or entry.get("terminal")
    print("%s\t%s" % (token, entry["ground_truth_match"]))
PYEOF

total=0
disagreements=0
for rec in "${records[@]}"; do
  id="$(basename "$rec")"
  total=$((total + 1))
  scratch="$(mktemp -d)"
  mkdir -p "$scratch/candidates"
  cp -R "$ROOT/tools" "$scratch/tools"
  cp "$LOOP_SRC" "$scratch/tools/loop"
  [[ -f "$ROOT/flake.lock" ]] && cp "$ROOT/flake.lock" "$scratch/flake.lock"
  cp -R "$rec" "$scratch/candidates/$id"

  # --- ground truth, surface order per LM-1.5: validate, reflect, auto ---
  ( cd "$scratch" && bash tools/loop validate "$id" ) > "$scratch/validate.log" 2>&1
  gt_vrc=$?
  if [[ -f "$scratch/candidates/$id/VALIDATE.json" ]]; then
    cp "$scratch/candidates/$id/VALIDATE.json" "$scratch/gt.validate"
  else
    printf 'VALIDATE.json-NOT-WRITTEN\n' > "$scratch/gt.validate"
  fi
  gt_status="$(awk -F': ' '$1 == "status" { sub($1 ": ", ""); print; exit }' \
    "$scratch/candidates/$id/META")"

  ( cd "$scratch" && bash tools/loop reflect "$id" ) > "$scratch/reflect.log" 2>&1 || true
  gt_assessment="$(sed -n 's/^Assessment (agent-drafted): //p' \
    "$scratch/candidates/$id/REFLECT.md" 2>/dev/null | head -n 1)"
  gt_basis="$(sed -n 's/^Basis: //p' \
    "$scratch/candidates/$id/REFLECT.md" 2>/dev/null | head -n 1)"

  ( cd "$scratch" && bash tools/loop auto "$id" --agent loop-model-diff ) \
    > "$scratch/auto.log" 2>&1 || true
  gt_auto=""
  while IFS=$'\t' read -r token pattern; do
    if grep -Fq -- "$pattern" "$scratch/auto.log"; then
      gt_auto="$token"
      break
    fi
  done < "$AUTOMAP"
  [[ -n "$gt_auto" ]] || gt_auto="unmapped($(tail -n 1 "$scratch/auto.log"))"

  if [[ -f "$rec/scores.json" ]]; then
    gt_sv="$(bash "$SVRUN" "$rec/scores.json")"
  else
    gt_sv="no-scores"
  fi

  # --- prediction (pristine record, live root, laws under test) ---
  if ! "$PY" "$MODEL" predict "$rec" --root "$ROOT" --laws "$LAWS" \
      > "$scratch/prediction.json" 2> "$scratch/prediction.err"; then
    printf 'DISAGREE %s: model error (%s)\n' "$id" "$(head -n 1 "$scratch/prediction.err")"
    disagreements=$((disagreements + 1))
    [[ "$keep" -eq 1 ]] && printf 'loop-model-diff: kept %s\n' "$scratch" || rm -rf "$scratch"
    continue
  fi

  verdict="$("$PY" - "$scratch/prediction.json" "$scratch/gt.validate" \
      "$gt_vrc" "$gt_status" "$gt_sv" "$gt_auto" "$gt_assessment" "$gt_basis" <<'PYEOF'
import json
import sys

(pred_path, gt_validate_path, gt_vrc, gt_status,
 gt_sv, gt_auto, gt_assessment, gt_basis) = sys.argv[1:9]
pred = json.load(open(pred_path, encoding="utf-8"))
s = pred["surfaces"]
gt_doc = open(gt_validate_path, encoding="utf-8", errors="surrogateescape").read()
mismatches = []
if s["validate"]["doc"] != gt_doc:
    mismatches.append("validate.doc")
if s["validate"]["rc"] != int(gt_vrc):
    mismatches.append("validate.rc")
if s["validate"]["post_status"] != gt_status:
    mismatches.append("validate.post_status")
if s["scores_verdict"] != gt_sv:
    mismatches.append("scores_verdict")
if s["auto"]["outcome"] != gt_auto:
    mismatches.append("auto")
if s["reflect"]["assessment"] != gt_assessment:
    mismatches.append("reflect.assessment")
if s["reflect"]["basis"] != gt_basis:
    mismatches.append("reflect.basis")
print(",".join(mismatches) if mismatches else "agree")
PYEOF
)"

  if [[ "$verdict" == "agree" ]]; then
    printf 'agree %s\n' "$id"
  else
    printf 'DISAGREE %s: %s\n' "$id" "$verdict"
    printf '  model auto/sv: %s / %s ; ground truth: %s / %s\n' \
      "$("$PY" -c 'import json,sys; p=json.load(open(sys.argv[1])); print(p["surfaces"]["auto"]["outcome"])' "$scratch/prediction.json")" \
      "$("$PY" -c 'import json,sys; p=json.load(open(sys.argv[1])); print(p["surfaces"]["scores_verdict"])' "$scratch/prediction.json")" \
      "$gt_auto" "$gt_sv"
    disagreements=$((disagreements + 1))
  fi
  if [[ "$keep" -eq 1 ]]; then
    printf 'loop-model-diff: kept %s\n' "$scratch"
  else
    rm -rf "$scratch"
  fi
done
rm -f "$SVRUN" "$AUTOMAP"

printf 'loop-model-diff: records=%s disagreements=%s (mode %s)\n' \
  "$total" "$disagreements" "$mode"
if [[ "$disagreements" -gt 0 ]]; then
  [[ -f "$EMIT" ]] && bash "$EMIT" model_coherence_failure loop-model.differential \
    "loop-model differential (LM-1.2 agreement projection)" \
    "$disagreements of $total records disagree between tools/loop and the loop model — coherence evidence does not hold; reconcile loop-laws.json and tools/loop DELIBERATELY (LM-1.3), never silently" \
    "{\"records\": $total, \"disagreements\": $disagreements}" || true
  exit 1
fi
printf 'loop-model-diff: coherence evidence holds over this corpus (LM-1.4)\n'
exit 0
