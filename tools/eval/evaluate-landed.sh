#!/usr/bin/env bash
set -u

# Post-land evidence form (verifier-set member).
#
# Usage: evaluate-landed.sh CAND_DIR
#
# A landed candidate's evidence is no longer "how would this change behavior"
# (that was the pre-land differential) but "is the landed state conformant":
#   manifest   every LANDED dest on disk is byte-identical to the cargo src
#   snapshot   the landing's git snapshot exists and is an ancestor of HEAD
#   suite      the live verifier suite passes on the landed tree
#
# Suite membership (documented, deliberate): charter-conformance,
# regular-doctrine --all, sigpi --all, cwf-comprehension --all,
# RLM trace dry-run harness over the prior-landed corpus (if present),
# KB receipt-memory projection checks (if present), projection descent gate over
# the prior-landed packet corpus (if present), provider-operation section
# projection over the current Harbor publication-provider packet cover (if
# present), Bridge capability/session judgment over the current redacted
# host-runtime-file fixture (if present), Harbor publication cover projection
# over the current cover packet (if present), review-query health
# (conditional on the source-local query helper being present).
# receipt-index-check is EXCLUDED: it asserts cross-workspace paths
# (fish/...) that fail in sandboxes regardless of cargo; its inclusion would
# make post-land evidence environment-dependent. Revisit if that check gains
# an env-independent mode.
#
# Output: scores.json (attested) + traces/post-land.*.trace. ANY pre-existing
# scores.json is archived first (never silently overwritten) — landed
# candidates carry historical pre-land evidence worth keeping.
#
# BOAT_POSTLAND_SKIP_SUITE=1 skips the suite checks (unit testing only;
# recorded in scores.json as skipped, and verdict cannot be pass).

TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$TOOLS_DIR/.." && pwd)"

CAND_DIR="${1:-}"
[[ -n "$CAND_DIR" && -d "$CAND_DIR" ]] || {
  printf 'usage: %s CAND_DIR\n' "$(basename "$0")" >&2
  exit 64
}
CAND_DIR="$(cd "$CAND_DIR" && pwd)"

cand_status="$(awk -F': ' '$1 == "status" { gsub(/[ \t\r]+$/, "", $2); print $2; exit }' "$CAND_DIR/META" 2>/dev/null)"
[[ "$cand_status" == "landed" ]] || {
  printf 'evaluate-landed: candidate status is "%s", not landed\n' "$cand_status" >&2
  exit 70
}
[[ -f "$CAND_DIR/LANDED" ]] || {
  printf 'evaluate-landed: no LANDED manifest\n' >&2
  exit 70
}

# Local writer lock: post-land evidence rewrites scores.json and traces, so
# concurrent runs for the same candidate must fail before any mutation.
LOCK_DIR="$CAND_DIR/.evaluate-landed.lock"
LOCK_PID="$LOCK_DIR/pid"
LOCK_OWNED=0

lock_pid_alive() {
  local pid="${1:-}"
  [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null
}

cleanup_evaluate_landed_lock() {
  [[ "${LOCK_OWNED:-0}" == "1" ]] || return 0
  local owner=""
  owner="$(cat "$LOCK_PID" 2>/dev/null || true)"
  if [[ "$owner" == "$$" ]]; then
    rm -rf "$LOCK_DIR"
  fi
}

acquire_evaluate_landed_lock() {
  local owner attempt
  for attempt in 1 2 3; do
    if mkdir "$LOCK_DIR" 2>/dev/null; then
      LOCK_OWNED=1
      printf '%s\n' "$$" > "$LOCK_PID"
      printf '%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$LOCK_DIR/started_at"
      trap cleanup_evaluate_landed_lock EXIT
      trap 'cleanup_evaluate_landed_lock; exit 130' INT
      trap 'cleanup_evaluate_landed_lock; exit 143' TERM
      return 0
    fi

    owner="$(cat "$LOCK_PID" 2>/dev/null || true)"
    if lock_pid_alive "$owner"; then
      printf 'evaluate-landed: another run is active for %s (pid %s, lock %s)\n' \
        "$(basename "$CAND_DIR")" "$owner" "$LOCK_DIR" >&2
      exit 75
    fi
    if [[ "$owner" =~ ^[0-9]+$ ]]; then
      printf 'evaluate-landed: removing stale lock %s (pid %s is not active)\n' \
        "$LOCK_DIR" "$owner" >&2
      rm -rf "$LOCK_DIR"
      continue
    fi

    printf 'evaluate-landed: lock %s has unknown owner; refusing to mutate evidence\n' \
      "$LOCK_DIR" >&2
    exit 75
  done

  printf 'evaluate-landed: could not acquire lock %s\n' "$LOCK_DIR" >&2
  exit 75
}

acquire_evaluate_landed_lock

TRACES="$CAND_DIR/traces"
mkdir -p "$TRACES"

sha_file() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    sha256sum "$1" | awk '{print $1}'
  fi
}

# Preserve ANY pre-existing evidence before writing new scores — attested
# pre-land evidence (e.g. a differential run) is historical record, and
# silently overwriting genuine evidence is the failure class this tool
# exists to fix.
if [[ -f "$CAND_DIR/scores.json" ]]; then
  archive="$CAND_DIR/scores.archived.$(date -u +%Y%m%dT%H%M%SZ).$$.json"
  cp "$CAND_DIR/scores.json" "$archive"
  printf 'evaluate-landed: archived prior evidence to %s\n' "$(basename "$archive")"
fi

declare -a check_names check_results
record() { check_names+=("$1"); check_results+=("$2"); }

# superseded_by DEST LANDED_AT — succession lookup: among OTHER landed
# candidates whose LANDED manifest claims the same dest with a strictly
# LATER landed_at, find the latest. Echoes "cand_id<TAB>src" when found.
# A dest legitimately re-landed by a newer candidate is SUPERSEDED for an
# older one — drift only if even the latest owner mismatches the live tree
# (the caller checks that). Timestamps are ISO-8601 UTC: lexical compare
# is chronological compare.
superseded_by() {
  local dest="$1" my_at="$2" d at best_at="" best=""
  for d in "$ROOT"/candidates/*/; do
    [[ "$(cd "$d" && pwd)" == "$CAND_DIR" ]] && continue
    [[ -f "$d/LANDED" && -f "$d/META" ]] || continue
    [[ "$(awk -F': ' '$1 == "status" { gsub(/[ \t\r]+$/, "", $2); print $2; exit }' "$d/META")" == "landed" ]] || continue
    at="$(awk -F': ' '/^# landed_at:/ { print $2; exit }' "$d/LANDED")"
    [[ -n "$at" && "$at" > "$my_at" ]] || continue
    local row
    row="$(awk -F'\t' -v dst="$dest" '!/^#/ && $1 != "git_commit" && $2 == dst { print $1; exit }' "$d/LANDED")"
    [[ -n "$row" ]] || continue
    if [[ -z "$best_at" || "$at" > "$best_at" ]]; then
      best_at="$at"; best="$(basename "$d")	$row"
    fi
  done
  [[ -n "$best" ]] && printf '%s' "$best"
}

# --- Check 1: manifest conformance -------------------------------------------

manifest_ok=pass
pairs_checked=0
{
  if compgen -G "$CAND_DIR/LANDED.rolled-back.*" > /dev/null; then
    printf 'note: prior rollback markers present (re-landed candidate)\n'
  fi
  while IFS=$'\t' read -r src dest replaced; do
    [[ -n "$src" && "$src" != \#* && "$src" != "git_commit" ]] || continue
    pairs_checked=$((pairs_checked + 1))
    if [[ -L "$CAND_DIR/$src" || -L "$ROOT/$dest" ]]; then
      printf 'symlink not allowed in evidence path: %s / %s\n' "$src" "$dest"
      manifest_ok=fail; continue
    fi
    if [[ ! -f "$CAND_DIR/$src" ]]; then
      printf 'cargo source missing: %s\n' "$src"; manifest_ok=fail; continue
    fi
    if [[ ! -f "$ROOT/$dest" ]]; then
      printf 'landed dest missing: %s\n' "$dest"; manifest_ok=fail; continue
    fi
    if [[ "$(sha_file "$CAND_DIR/$src")" != "$(sha_file "$ROOT/$dest")" ]]; then
      # Succession, not drift? A NEWER landed candidate may legitimately
      # own this dest now. Pass only if the latest such owner's cargo IS
      # the live tree — anything else is genuine drift.
      my_at="$(awk -F': ' '/^# landed_at:/ { print $2; exit }' "$CAND_DIR/LANDED")"
      succ="$(superseded_by "$dest" "${my_at:-}")"
      if [[ -n "$succ" ]]; then
        succ_cand="${succ%%	*}"; succ_src="${succ#*	}"
        if [[ -f "$ROOT/candidates/$succ_cand/$succ_src" ]] \
          && [[ "$(sha_file "$ROOT/candidates/$succ_cand/$succ_src")" == "$(sha_file "$ROOT/$dest")" ]]; then
          printf 'superseded: %s now owned by %s (live matches its cargo)\n' "$dest" "$succ_cand"
        else
          printf 'cargo drift: %s != %s (claimed successor %s does not match live either)\n' "$src" "$dest" "$succ_cand"
          manifest_ok=fail
        fi
      else
        printf 'cargo drift: %s != %s\n' "$src" "$dest"; manifest_ok=fail
      fi
    else
      printf 'match: %s == %s\n' "$src" "$dest"
    fi
  done < "$CAND_DIR/LANDED"

  if [[ "$pairs_checked" -eq 0 ]]; then
    printf 'manifest lists no cargo pairs — nothing verified is not a pass\n'
    manifest_ok=fail
  fi

  # Completeness: LANDED is proposer-writable, so cross-check it against the
  # LANDING map — a drifted pair cannot be hidden by deleting its line.
  if [[ -f "$CAND_DIR/LANDING" ]]; then
    while read -r lsrc ldest; do
      [[ -n "$lsrc" && "$lsrc" != \#* ]] || continue
      ldest="${ldest#./}"
      if ! awk -F'\t' -v s="$lsrc" -v d="$ldest" \
             '$1 == s && $2 == d { found = 1 } END { exit !found }' "$CAND_DIR/LANDED"; then
        printf 'manifest incomplete: LANDING pair absent from LANDED: %s -> %s\n' "$lsrc" "$ldest"
        manifest_ok=fail
      fi
    done < "$CAND_DIR/LANDING"
  fi
} > "$TRACES/post-land.manifest.trace" 2>&1
record manifest "$manifest_ok"

# --- Check 2: snapshot ancestry ----------------------------------------------

snapshot_ok=fail
snap="$(awk -F'\t' '$1 == "git_commit" { print $2; exit }' "$CAND_DIR/LANDED")"
{
  if [[ -z "$snap" ]]; then
    printf 'no git_commit in LANDED manifest\n'
  elif ! git -C "$ROOT" cat-file -e "$snap^{commit}" 2>/dev/null; then
    printf 'snapshot commit missing from history: %s\n' "$snap"
  elif ! git -C "$ROOT" merge-base --is-ancestor "$snap" HEAD 2>/dev/null; then
    printf 'snapshot %s is not an ancestor of HEAD\n' "$snap"
  else
    printf 'snapshot %s exists and is an ancestor of HEAD\n' "$snap"
    snapshot_ok=pass
  fi
} > "$TRACES/post-land.snapshot.trace" 2>&1
record snapshot "$snapshot_ok"

# --- Check 3: live verifier suite ----------------------------------------------

if [[ "${BOAT_POSTLAND_SKIP_SUITE:-0}" == "1" ]]; then
  record suite skipped
else
  suite_ok=pass
  run_suite() {
    local name="$1"; shift
    if ( cd "$ROOT" && "$@" ) > "$TRACES/post-land.suite-$name.trace" 2>&1; then
      printf 'suite %s: pass\n' "$name"
    else
      printf 'suite %s: FAIL\n' "$name"
      suite_ok=fail
    fi
  }
  # Membership is uniformly conditional (export course): an exported
  # instance carries the kernel subset of the suite; a member whose
  # checker did not travel is absent, not failing. On the source
  # instance every enrolled checker exists, so the full source suite runs.
  [[ -f "$ROOT/tools/charter-conformance-check.sh" ]] \
    && run_suite charter bash tools/charter-conformance-check.sh
  [[ -f "$ROOT/tools/regular-doctrine-check.sh" ]] \
    && run_suite doctrine bash tools/regular-doctrine-check.sh --all
  [[ -f "$ROOT/tools/sigpi-judgment-check.sh" ]] \
    && run_suite sigpi bash tools/sigpi-judgment-check.sh --all
  [[ -f "$ROOT/tools/cwf-comprehension-check.sh" ]] \
    && run_suite cwf bash tools/cwf-comprehension-check.sh --all
  [[ -f "$ROOT/tools/record-judgment-check.sh" ]] \
    && run_suite record-judgments bash tools/record-judgment-check.sh --all
  [[ -f "$ROOT/tools/cross-surface-check.sh" ]] \
    && run_suite cross-surface bash tools/cross-surface-check.sh
  [[ -f "$ROOT/tools/queue-lint.sh" ]] \
    && run_suite queue-judgments bash tools/queue-lint.sh --all
  [[ -f "$ROOT/tools/verdict-tripwire.sh" ]] \
    && run_suite verdict-tripwire bash tools/verdict-tripwire.sh
  [[ -f "$ROOT/tools/loop-model-diff.sh" ]] \
    && run_suite loop-model bash tools/loop-model-diff.sh --fixtures
  [[ -f "$ROOT/tools/skill-kernel-check.sh" ]] \
    && run_suite skill-kernel bash tools/skill-kernel-check.sh
  [[ -f "$ROOT/tools/review-query.sh" ]] \
    && run_suite review-query bash -c '
      set -euo pipefail
      summary="${TMPDIR:-/tmp}/boat-review-query-summary.$$.out"
      cleanup() { rm -f "$summary"; }
      trap cleanup EXIT
      bash tools/review-query.sh --self-test
      bash tools/review-query.sh --summary > "$summary"
      python3 - "$PWD" "$summary" <<'"'"'PY'"'"'
import sys
from pathlib import Path

root = Path(sys.argv[1])
summary = Path(sys.argv[2])
keys = {}
for line in summary.read_text(encoding="utf-8").splitlines():
    if not line.strip():
        continue
    name, sep, value = line.partition(": ")
    if not sep:
        raise SystemExit(f"malformed summary line: {line}")
    if not value.isdigit():
        raise SystemExit(f"non-numeric summary value for {name}: {value}")
    keys[name] = int(value)

required = {"reviews", "typed", "untyped", "malformed"}
missing = sorted(required - set(keys))
if missing:
    raise SystemExit(f"missing summary keys: {missing}")
if keys["reviews"] != keys["typed"] + keys["untyped"]:
    raise SystemExit("summary invariant failed: reviews != typed + untyped")

review_dir = root / "candidates"
if not review_dir.exists():
    if any(keys.values()):
        raise SystemExit("summary reported records without a candidates directory")
elif not review_dir.is_dir():
    raise SystemExit("candidates path exists but is not a directory")
PY
      bash tools/review-query.sh --strict --typed true --jsonl \
        | python3 -c '"'"'import json, sys
for line in sys.stdin:
    rec = json.loads(line)
    if rec.get("authority") != "query-only":
        raise SystemExit("review-query emitted non-query authority")
    if not rec.get("typed"):
        raise SystemExit("typed query emitted an untyped record")
'"'"'
    '
  [[ -f "$ROOT/tools/eval/rlm-trace-harness.sh" \
     && -d "$ROOT/sites/eval/corpus/rlm-trace-v0" ]] \
    && run_suite rlm-trace-harness bash tools/eval/rlm-trace-harness.sh sites/eval/corpus/rlm-trace-v0
  [[ -f "$ROOT/sites/kb/realizations/kb-receipt-memory-premath-check/kb-receipt-memory-premath-check.sh" \
     && -f "$ROOT/sites/kb/examples/boat-receipt-memory-projection.jsonl" ]] \
    && run_suite kb-receipt-memory bash sites/kb/realizations/kb-receipt-memory-premath-check/kb-receipt-memory-premath-check.sh \
      sites/kb/examples/boat-receipt-memory-projection.jsonl .
  [[ -f "$ROOT/sites/kb/realizations/kb-receipt-memory-premath-check/kb-receipt-memory-premath-check.sh" \
     && -f "$ROOT/sites/kb/examples/boat-receipt-memory-projection.verified.jsonl" ]] \
    && run_suite kb-receipt-memory-verified bash sites/kb/realizations/kb-receipt-memory-premath-check/kb-receipt-memory-premath-check.sh \
      sites/kb/examples/boat-receipt-memory-projection.verified.jsonl .
  [[ -f "$ROOT/sites/eval/realizations/projection-descent-check/projection-descent-check.sh" \
     && -f "$ROOT/sites/eval/corpus/projection-descent-v0/manifest.tsv" ]] \
    && run_suite projection-descent bash sites/eval/realizations/projection-descent-check/projection-descent-check.sh \
      sites/eval/corpus/projection-descent-v0/manifest.tsv .
  [[ -f "$ROOT/sites/premath/realizations/provider-operation-section-check/provider-operation-section-check.sh" \
     && -f "$ROOT/sites/harbor/specs/examples/boat-harbor-0.launch-admission-plan.json" \
     && -f "$ROOT/sites/infra/specs/examples/publication.harbor.boat-harbor-0.desired-state.json" \
     && -f "$ROOT/sites/bridge/specs/examples/publication-host-bootstrap.bounded-session-admission.json" \
     && -f "$ROOT/sites/ops/specs/examples/boat-harbor-0.realization.pipeline-admission.json" \
     && -f "$ROOT/sites/connectors/specs/examples/boat-harbor-0.provision-publication-host.receipt-shape.json" \
     && -f "$ROOT/sites/connectors/specs/examples/boat-harbor-0.provision-publication-host.execution-admission.json" \
     && -f "$ROOT/sites/harbor/specs/examples/boat-harbor-0.live-receipt-execution-admission.json" \
     && -f "$ROOT/sites/publication/examples/boat-harbor-0.publication.json" ]] \
    && run_suite provider-operation-section bash -c '
      set -euo pipefail
      out="${TMPDIR:-/tmp}/boat-provider-operation-section.$$.json"
      cleanup() { rm -f "$out"; }
      trap cleanup EXIT
      bash sites/premath/realizations/provider-operation-section-check/provider-operation-section-check.sh \
        sites/harbor/specs/examples/boat-harbor-0.launch-admission-plan.json \
        sites/infra/specs/examples/publication.harbor.boat-harbor-0.desired-state.json \
        sites/bridge/specs/examples/publication-host-bootstrap.bounded-session-admission.json \
        sites/ops/specs/examples/boat-harbor-0.realization.pipeline-admission.json \
        sites/connectors/specs/examples/boat-harbor-0.provision-publication-host.receipt-shape.json \
        sites/connectors/specs/examples/boat-harbor-0.provision-publication-host.execution-admission.json \
        sites/harbor/specs/examples/boat-harbor-0.live-receipt-execution-admission.json \
        sites/publication/examples/boat-harbor-0.publication.json > "$out"
      jq -e "
        .schema == \"premath.provider-operation-section.projection.v0\"
        and .statementRef == \"premath.provider-operation-section-judgment.v0\"
        and .result == \"accepted\"
        and .mode == \"checking-only\"
        and .agreement.refAgreement == true
        and .agreement.boundaryAgreement == true
        and .agreement.receiptObligationAgreement == true
        and (.doesNotAuthorize | index(\"Bridge session issuance\") != null)
        and (.doesNotAuthorize | index(\"provider calls or provider truth\") != null)
      " "$out" >/dev/null
      jq -r "
        \"schema=\" + .schema,
        \"result=\" + .result,
        \"refAgreement=\" + (.agreement.refAgreement | tostring),
        \"boundaryAgreement=\" + (.agreement.boundaryAgreement | tostring),
        \"receiptObligationAgreement=\" + (.agreement.receiptObligationAgreement | tostring)
      " "$out"
    '
  [[ -f "$ROOT/sites/premath/realizations/bridge-capability-session-judgment-check/bridge-capability-session-judgment-check.sh" \
     && -f "$ROOT/sites/bridge/specs/examples/host-runtime-api-token.capability-section.json" \
     && -f "$ROOT/sites/bridge/specs/examples/host-runtime-api-token.materialization-session.allow.json" \
     && -f "$ROOT/sites/bridge/specs/examples/host-runtime-api-token.session-judgment.allow.json" ]] \
    && run_suite bridge-capability-session-judgment bash -c '
      set -euo pipefail
      work="$(mktemp -d "${TMPDIR:-/tmp}/boat-bridge-capability-session.XXXXXX")"
      cleanup() { rm -rf "$work"; }
      trap cleanup EXIT
      mkdir -p "$work/runtime"
      printf "%s\n" "redacted runtime-handle fixture" > "$work/runtime/provider-api-token"
      out="$work/projection.json"
      if ! bash sites/premath/realizations/bridge-capability-session-judgment-check/bridge-capability-session-judgment-check.sh \
          --now 2026-04-13T14:31:00Z \
          --runtime-handle "$work/runtime/provider-api-token" \
          --runtime-roots "$work/runtime" \
          sites/bridge/specs/examples/host-runtime-api-token.capability-section.json \
          sites/bridge/specs/examples/host-runtime-api-token.materialization-session.allow.json \
          sites/bridge/specs/examples/host-runtime-api-token.session-judgment.allow.json > "$out"; then
        cat "$out"
        exit 1
      fi
      jq -e "
        .schema == \"premath.bridge-capability-session-judgment.projection.v0\"
        and .statementRef == \"premath.bridge-capability-session-judgment.v0\"
        and .result == \"accepted\"
        and .mode == \"checking-only\"
        and .judgment.schema_version == \"bridge-session-judgment-0.1\"
        and .judgment.judgment == \"accept\"
        and .judgment.redacted == true
        and .agreement.schemaAgreement == true
        and .agreement.bindingAgreement == true
        and .agreement.consumerAgreement == true
        and .agreement.bridgeTraceAgreement == true
        and .agreement.expiryAgreement == true
        and .agreement.runtimeHandlePolicyAgreement == true
        and .agreement.expectedJudgmentAgreement == true
        and (.doesNotAuthorize | index(\"Bridge session issuance\") != null)
        and (.doesNotAuthorize | index(\"secret materialization\") != null)
        and (.doesNotAuthorize | index(\"provider calls or provider truth\") != null)
      " "$out" >/dev/null
      jq -r "
        \"schema=\" + .schema,
        \"result=\" + .result,
        \"judgment=\" + .judgment.judgment,
        \"bindingAgreement=\" + (.agreement.bindingAgreement | tostring),
        \"expiryAgreement=\" + (.agreement.expiryAgreement | tostring),
        \"runtimeHandlePolicyAgreement=\" + (.agreement.runtimeHandlePolicyAgreement | tostring)
      " "$out"
    '
  [[ -f "$ROOT/sites/premath/realizations/harbor-publication-cover-check/harbor-publication-cover-check.sh" \
     && -f "$ROOT/sites/harbor/specs/examples/boat-harbor-0.publication-cover.json" ]] \
    && run_suite harbor-publication-cover bash -c '
      set -euo pipefail
      work="$(mktemp -d "${TMPDIR:-/tmp}/boat-harbor-publication-cover.XXXXXX")"
      cleanup() { rm -rf "$work"; }
      trap cleanup EXIT
      mkdir -p "$work/runtime"
      printf "%s\n" "redacted runtime-handle fixture" > "$work/runtime/provider-api-token"
      out="$work/projection.json"
      if ! bash sites/premath/realizations/harbor-publication-cover-check/harbor-publication-cover-check.sh \
          --runtime-handle "$work/runtime/provider-api-token" \
          --runtime-roots "$work/runtime" \
          sites/harbor/specs/examples/boat-harbor-0.publication-cover.json . > "$out"; then
        cat "$out"
        exit 1
      fi
      jq -e "
        .schema == \"premath.harbor-publication-cover.projection.v0\"
        and .statementRef == \"premath.harbor-publication-cover.v0\"
        and .coverRef == \"harbor.publication-cover:boat-harbor-0.publication\"
        and .result == \"accepted\"
        and .mode == \"checking-only\"
        and .agreement.memberPathCoverage == true
        and .agreement.refAgreement == true
        and .agreement.delegatedCheckerAgreement == true
        and .agreement.receiptObligationAgreement == true
        and .agreement.runtimeHandlePolicyAgreement == true
        and .agreement.boundaryAgreement == true
        and (.delegates | length) == 14
        and all(.delegates[]; .ok == true)
        and (.fibres.premath | index(\"premath.provider-operation-section.projection.v0\") != null)
        and (.fibres.premath | index(\"premath.bridge-capability-session-judgment.projection.v0\") != null)
        and (.doesNotAuthorize | index(\"Bridge session issuance\") != null)
        and (.doesNotAuthorize | index(\"provider calls or provider truth\") != null)
        and (.doesNotAuthorize | index(\"Harbor readiness\") != null)
      " "$out" >/dev/null
      jq -r "
        \"schema=\" + .schema,
        \"result=\" + .result,
        \"delegates=\" + (.delegates | length | tostring),
        \"refAgreement=\" + (.agreement.refAgreement | tostring),
        \"delegatedCheckerAgreement=\" + (.agreement.delegatedCheckerAgreement | tostring),
        \"runtimeHandlePolicyAgreement=\" + (.agreement.runtimeHandlePolicyAgreement | tostring)
      " "$out"
    '
  [[ -f "$ROOT/tools/rust-premath-gate-diff.sh" \
     && -f "$ROOT/rust/premath-gate/Cargo.toml" \
     && -f "$ROOT/flake.nix" ]] \
    && run_suite rust-premath-gate bash tools/rust-premath-gate-diff.sh
  record suite "$suite_ok"
fi

# --- Verdict + scores ------------------------------------------------------------

verdict=pass
for r in "${check_results[@]}"; do
  [[ "$r" == "pass" ]] || verdict=fail
done

{
  printf '{\n'
  printf '  "evaluated_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '  "task": "post-land conformance",\n'
  printf '  "candidate": "%s",\n' "$(basename "$CAND_DIR")"
  printf '  "snapshot": "%s",\n' "${snap:-none}"
  printf '  "checks": [\n'
  comma=""
  for i in "${!check_names[@]}"; do
    printf '%s    { "name": "%s", "result": "%s" }' "$comma" "${check_names[$i]}" "${check_results[$i]}"
    comma=$',\n'
  done
  printf '\n  ],\n'
  printf '  "verdict": "%s"\n' "$verdict"
  printf '}\n'
} > "$CAND_DIR/scores.json"

if ! bash "$TOOLS_DIR/eval/attest.sh" write "$CAND_DIR/scores.json" "${BASH_SOURCE[0]}" "$TRACES"; then
  printf 'evaluate-landed: attestation failed; evidence is unattested and this run does not pass\n' >&2
  exit 70
fi

printf 'evaluate-landed: verdict=%s\n' "$verdict"
cat "$CAND_DIR/scores.json"
[[ "$verdict" == "pass" ]]
