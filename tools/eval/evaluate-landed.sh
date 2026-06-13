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
# regular-doctrine --all, sigpi --all, cwf-comprehension --all (if present).
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
  # instance every checker exists, so the executed set is unchanged.
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
