#!/usr/bin/env bash

# Shared helpers for candidate eval-self.sh harnesses. Source this file from
# a staged root, then call eval_init before recording probes.

EVAL_LIB_LOADED=1
EVAL_LIB_PATH="${BASH_SOURCE[0]}"

eval_lib_err() {
  printf 'eval-lib: %s\n' "$*" >&2
}

# Usage: eval_init [CAND_DIR] [ROOT_DIR]
# Initializes CAND, ROOT, TRACES, RESULTS, and failures for a candidate eval.
eval_init() {
  CAND="${1:-${CAND:-}}"
  ROOT="${2:-${ROOT:-}}"
  [[ -n "${CAND:-}" && -d "$CAND" ]] || { eval_lib_err 'eval_init needs CAND_DIR'; return 64; }
  [[ -n "${ROOT:-}" && -d "$ROOT" ]] || { eval_lib_err 'eval_init needs ROOT_DIR'; return 64; }
  CAND="$(cd "$CAND" && pwd)"
  ROOT="$(cd "$ROOT" && pwd)"
  TRACES="${TRACES:-$CAND/traces}"
  RESULTS="${RESULTS:-$CAND/.eval-results.tsv}"
  mkdir -p "$TRACES" || return 1
  rm -f "$TRACES"/t*.txt "$TRACES"/t*.out "$TRACES"/t*.err
  : > "$RESULTS"
  failures=0
}

# Usage: record NAME pass|fail
# Appends one probe result row to the current eval result table.
record() {
  local name="$1" result="$2"
  printf '%s\t%s\n' "$name" "$result" >> "$RESULTS"
}

# Usage: pass NAME MESSAGE
# Records a passing probe and writes its short human trace.
pass() {
  local name="$1" msg="$2"
  printf '%s\n' "$msg" > "$TRACES/$name.txt"
  record "$name" pass
}

# Usage: bad NAME MESSAGE
# Records a failing probe, writes its short trace, and increments failures.
bad() {
  local name="$1" msg="$2"
  printf '%s\n' "$msg" > "$TRACES/$name.txt"
  record "$name" fail
  failures=$((failures + 1))
}

# Usage: sha_file PATH
# Prints a sha256 digest using whichever standard tool exists on the host.
sha_file() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    sha256sum "$1" | awk '{print $1}'
  fi
}

# Usage: shell_quote VALUE
# Prints a shell-escaped representation suitable for trace commands.
shell_quote() {
  printf '%q' "$1"
}

# Usage: row_count TSV
# Counts non-empty, non-comment rows in a simple TSV/list file.
row_count() {
  awk 'NF && $1 !~ /^#/ { c++ } END { print c + 0 }' "$1"
}

# Usage: stage_root OUT [--head-only] [--apply-landing] [--include-candidate]
# Copies ROOT's HEAD tree to OUT and, by default, overlays CAND/LANDING seeds.
stage_root() {
  local out="${1:-}" apply_landing=yes include_candidate=no arg src dest kind tmp merge_out
  [[ -n "$out" ]] || { eval_lib_err 'stage_root needs OUT'; return 64; }
  shift || true
  for arg in "$@"; do
    case "$arg" in
      --head-only) apply_landing=no ;;
      --apply-landing) apply_landing=yes ;;
      --include-candidate) include_candidate=yes ;;
      *) eval_lib_err "stage_root unknown option: $arg"; return 64 ;;
    esac
  done
  [[ -n "${ROOT:-}" && -d "$ROOT" ]] || { eval_lib_err 'stage_root needs ROOT'; return 64; }
  [[ -n "${CAND:-}" && -d "$CAND" ]] || { eval_lib_err 'stage_root needs CAND'; return 64; }
  rm -rf "$out"
  mkdir -p "$out" || return 1
  ( cd "$ROOT" && git archive --format=tar HEAD ) | ( cd "$out" && tar -xf - ) || return 1
  if [[ "$include_candidate" == yes ]]; then
    mkdir -p "$out/candidates/$(basename "$CAND")" || return 1
    cp -R "$CAND/." "$out/candidates/$(basename "$CAND")/" || return 1
  fi
  if [[ "$apply_landing" == yes ]]; then
    [[ -f "$CAND/LANDING" ]] || { eval_lib_err "stage_root missing LANDING: $CAND/LANDING"; return 65; }
    while read -r src dest kind; do
      [[ -n "$src" && "$src" != \#* ]] || continue
      kind="${kind:-file}"
      [[ -n "$dest" ]] || { eval_lib_err "bad LANDING row: $src $dest ${kind:-}"; return 65; }
      [[ -e "$CAND/$src" ]] || { eval_lib_err "LANDING source missing: $src"; return 65; }
      dest="${dest#./}"
      case "$dest" in
        ""|/*|*..*) eval_lib_err "LANDING destination invalid: $dest"; return 65 ;;
      esac
      mkdir -p "$out/$(dirname "$dest")" || return 1
      case "$kind" in
        file)
          cp -R "$CAND/$src" "$out/$dest" || return 1
          case "$dest" in
            tools/loop|*.sh) chmod +x "$out/$dest" ;;
          esac
          ;;
        queue-merge)
          [[ "$dest" == "candidates/QUEUE.md" ]] || {
            eval_lib_err "queue-merge LANDING destination must be candidates/QUEUE.md: $dest"; return 65; }
          [[ -f "$CAND/QUEUE.base" ]] || {
            eval_lib_err "QUEUE.base missing for queue-merge LANDING row"; return 65; }
          [[ -f "$out/tools/queue-merge.sh" ]] || {
            eval_lib_err "staged queue-merge tool missing"; return 65; }
          tmp="$(mktemp -d)" || return 1
          merge_out="$tmp/QUEUE.md"
          if ! bash "$out/tools/queue-merge.sh" "$dest" "$CAND/QUEUE.base" "$CAND/$src" "$out/$dest" "$merge_out"; then
            rm -rf "$tmp"
            return 65
          fi
          cp "$merge_out" "$out/$dest" || { rm -rf "$tmp"; return 1; }
          rm -rf "$tmp"
          ;;
        *) eval_lib_err "LANDING kind invalid: $kind"; return 65 ;;
      esac
    done < "$CAND/LANDING"
  fi
}

# Usage: make_synth ROOT ID [STATUS] [INTENT]
# Creates a minimal synthetic candidate; callers may add fixtures/eval bodies.
make_synth() {
  local root="${1:-}" id="${2:-}" status="${3:-open}" intent="${4:-synthetic probe}" cand
  [[ -n "$root" && -d "$root" && -n "$id" ]] || { eval_lib_err 'make_synth needs ROOT ID'; return 64; }
  cand="$root/candidates/$id"
  [[ ! -e "$cand" ]] || { eval_lib_err "synthetic candidate already exists: $id"; return 65; }
  mkdir -p "$cand/traces" || return 1
  {
    printf 'candidate_id: %s\n' "$id"
    printf 'cycle_id: loop-2026-06-26\n'
    printf 'opened: 2026-07-03T00:00:00Z\n'
    printf 'intent: %s\n' "$intent"
    printf 'status: %s\n' "$status"
  } > "$cand/META" || return 1
  printf '# %s\n\nIntent: %s\n' "$id" "$intent" > "$cand/README.md" || return 1
  {
    printf 'layer: artifact\n'
    printf 'implements: none\n'
    printf 'preserves: none\n'
    printf 'compares_to: none\n'
  } > "$cand/DECLARATION" || return 1
  : > "$cand/LANDING"
  printf '%s\n' "$cand"
}

eval_lib_normalize_ws() {
  local s="$1"
  s="${s//$'\t'/ }"
  s="${s//$'\r'/ }"
  s="${s//$'\n'/ }"
  while [[ "$s" == *"  "* ]]; do
    s="${s//  / }"
  done
  s="${s# }"
  s="${s% }"
  printf '%s' "$s"
}

# Usage: grep_prose "literal phrase" FILE...
# Folds line-wrapped prose and normalizes whitespace before literal matching.
grep_prose() {
  local needle="${1:-}" f text line norm_needle norm_text
  [[ "$#" -ge 2 ]] || { eval_lib_err 'grep_prose needs PHRASE FILE...'; return 64; }
  shift
  norm_needle="$(eval_lib_normalize_ws "$needle")"
  for f in "$@"; do
    [[ -f "$f" ]] || { eval_lib_err "grep_prose missing file: $f"; return 65; }
    text=''
    while IFS= read -r line || [[ -n "$line" ]]; do
      text+="$line "
    done < "$f"
    norm_text="$(eval_lib_normalize_ws "$text")"
    if [[ "$norm_text" == *"$norm_needle"* ]]; then
      printf '%s: %s\n' "$f" "$norm_needle"
      return 0
    fi
  done
  return 1
}

# Usage: run_probe NAME PASS_MSG FAIL_MSG COMMAND [ARG...]
# Runs COMMAND in a standalone subshell, records pass/fail from its exit code.
run_probe() {
  local name="$1" ok_msg="$2" fail_msg="$3" rc
  shift 3
  ( set -e; "$@" ) > "$TRACES/$name.out" 2>&1
  rc=$?
  if [[ "$rc" -eq 0 ]]; then
    pass "$name" "$ok_msg"
  else
    bad "$name" "$fail_msg; rc=$rc; see $TRACES/$name.out"
  fi
  return "$rc"
}

# Usage: run_failing_probe NAME PASS_MSG FAIL_MSG COMMAND [ARG...]
# Runs COMMAND in a standalone subshell and passes only when it fails.
run_failing_probe() {
  local name="$1" ok_msg="$2" fail_msg="$3" rc
  shift 3
  ( set -e; "$@" ) > "$TRACES/$name.out" 2>&1
  rc=$?
  if [[ "$rc" -ne 0 ]]; then
    pass "$name" "$ok_msg"
    return 0
  fi
  bad "$name" "$fail_msg; command unexpectedly passed; see $TRACES/$name.out"
  return 1
}

eval_lib_json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\b'/\\b}"
  s="${s//$'\f'/\\f}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

# Usage: attest_tail "task description"
# Writes scores.json from RESULTS, appends attest.sh provenance, prints scores.
attest_tail() {
  local task="${1:-candidate eval}" verdict=pass first=yes name result
  [[ "${failures:-0}" -eq 0 ]] || verdict=fail
  {
    printf '{\n'
    printf '  "evaluated_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf '  "task": "%s",\n' "$(eval_lib_json_escape "$task")"
    printf '  "checks": [\n'
    while IFS=$'\t' read -r name result; do
      [[ -n "$name" ]] || continue
      if [[ "$first" == yes ]]; then
        first=no
      else
        printf ',\n'
      fi
      printf '    {"name": "%s", "result": "%s"}' \
        "$(eval_lib_json_escape "$name")" "$(eval_lib_json_escape "$result")"
    done < "$RESULTS"
    printf '\n  ],\n'
    printf '  "verdict": "%s"\n' "$verdict"
    printf '}\n'
  } > "$CAND/scores.json" || return 1
  bash "$ROOT/tools/eval/attest.sh" write "$CAND/scores.json" "$CAND/eval-self.sh" "$TRACES" || return 1
  cat "$CAND/scores.json"
  [[ "$verdict" == pass ]]
}
