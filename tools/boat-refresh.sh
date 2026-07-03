#!/usr/bin/env bash
set -u

# boat-refresh: the kernel bundle's CONNECTION (realizes the connection
# clause of premath.workspace-kernel-bundle.v0; workspace tracker
# irai-xbu). Transports a kernel-home landing into an EXISTING instance:
# where boat-init trivializes a fresh fibre, boat-refresh parallel-
# transports an existing one back onto the typical fibre.
#
# Statement terms realized here:
#   - the typical fibre is the manifest set at the SOURCE's current
#     state, pinned by commit in the receipt;
#   - per-instance adaptations are DECLARED DATA: the target's
#     tools/schemas/kernel-adaptations.tsv (path <TAB> sha256 <TAB>
#     admitting-candidate). A declared path is left untouched, and its
#     on-disk digest must match the declaration (else
#     adaptation_witness_stale, fail closed);
#   - an UNDECLARED divergence is kernel_skew: refresh REFUSES by
#     default and lists every skewed path (curvature escalates to the
#     operator). --restore-conformance overwrites skewed paths and
#     records every restored file in the receipt — restoration is
#     visible, never silent;
#   - two soul carve-outs are never refreshed: tools/schemas/instance.tsv
#     and tools/schemas/kernel-adaptations.tsv (manifest-listed for
#     birth transport, instance-owned thereafter);
#   - the manifest chart itself (tools/schemas/export-manifest.tsv) is
#     NOT a manifest row: boat-init self-copies it structurally at birth
#     to avoid the chicken-and-egg of needing the row chart before the
#     row chart has travelled. Refresh closes that gap by classifying
#     the manifest file after its rows are read, through the same
#     per-file logic as ordinary cargo: byte-identical counts
#     identical; bytes from a committed source-history state are
#     transport-lag and copy; invented bytes are kernel_skew; declared
#     adaptations are honored through kernel-adaptations.tsv like any
#     other path;
#   - manifest `dir` rows transport their whole file tree: every source
#     file under the dir classifies exactly like a file row, and files
#     present in the TARGET dir but absent at the source are EXTRANEOUS
#     — gated like skew (refused by default; removed and itemized under
#     --restore-conformance); a dir row can never lag under a green
#     refresh;
#   - the transport is discharge-determined: it finishes by replaying
#     the loop-model differential INSIDE the target and fails closed if
#     the transported loop and its model disagree;
#   - the witness is REFRESH-RECEIPT.md (boat.refresh.v0) in the target:
#     source rev, per-file counts, adaptation and restoration lists,
#     conformance result. The manifest self-transport adds no schema
#     field: it appears in the existing counts, and if it travelled in
#     the normal updated set the receipt adds one indented note under
#     `updated`. Per the statement, transport along this connection
#     needs THIS witness, not an independent semantic re-review; the
#     receipt is committed by the instance (loop: kernel refresh from
#     <src>@<rev>).
#
# usage:
#   boat-refresh.sh TARGET [--restore-conformance] [--dry-run] [--check]
#   boat-refresh.sh --wave [--dry-run|--check]
#   TARGET  an existing kernel-bearing instance (tools/loop present)
#   --wave  iterate the declared bundle base
#   --check read-only digest convergence check (no receipts, copies, or logs)
#
# env: BOAT_ROOT overrides the source (default: this script's own
#      instance); BOAT_EXPORT_MANIFEST overrides the manifest.
#      BOAT_BUNDLE_BASE overrides tools/schemas/bundle-base.tsv.
#      BOAT_DEPENDENCY_SHIM_ALLOWLIST overrides the dependency-mode
#      kernel-file allowlist (default: tools/loop).
#
# Exit: 0 refreshed + conformant (or dry-run clean); 1 conformance
#       failed after copy (tree kept, receipt records the failure);
#       64 usage; 65 target refused; 66 manifest/source missing;
#       67 kernel_skew (undeclared divergence, nothing written);
#       68 adaptation_witness_stale (nothing written);
#       69 convergence_lag (wave/check saw refreshable lag, nothing written);
#       70 dependency_lock_stale (dependency-mode loop pin is not an ancestor
#          of source HEAD);
#       71 dependency_kernel_copy_carried (dependency-mode target carries
#          kernel files outside the local soul + shim boundary);
#       72 dependency_shim_missing (dependency-mode target has no tools/loop
#          shim).

TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="${BOAT_ROOT:-$(cd "$TOOLS_DIR/.." && pwd)}"
MANIFEST_SELF_PATH="tools/schemas/export-manifest.tsv"
MANIFEST="${BOAT_EXPORT_MANIFEST:-$SRC/$MANIFEST_SELF_PATH}"
BUNDLE_BASE="${BOAT_BUNDLE_BASE:-$SRC/tools/schemas/bundle-base.tsv}"
SUMMARY_FILE="${BOAT_REFRESH_SUMMARY_FILE:-}"
DEPENDENCY_SHIM_ALLOWLIST="${BOAT_DEPENDENCY_SHIM_ALLOWLIST:-tools/loop}"

die() { printf 'boat-refresh: %s\n' "$1" >&2; exit "${2:-1}"; }

sha_file() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    sha256sum "$1" | awk '{print $1}'
  fi
}

usage() {
  die "usage: boat-refresh.sh TARGET [--restore-conformance] [--dry-run] [--check] OR boat-refresh.sh --wave [--dry-run|--check]" 64
}

exit_priority() {
  case "$1" in
    64) printf '900' ;;
    66) printf '800' ;;
    65) printf '700' ;;
    72) printf '650' ;;
    71) printf '640' ;;
    70) printf '630' ;;
    68) printf '600' ;;
    67) printf '500' ;;
    69) printf '400' ;;
    1) printf '300' ;;
    0) printf '0' ;;
    *) printf '200' ;;
  esac
}

rc_class() {
  case "$1" in
    0) printf 'clean' ;;
    1) printf 'conformance_failed' ;;
    64) printf 'usage' ;;
    65) printf 'target_refused' ;;
    66) printf 'manifest_or_base_missing' ;;
    67) printf 'kernel_skew' ;;
    68) printf 'adaptation_witness_stale' ;;
    69) printf 'transport_lag' ;;
    70) printf 'dependency_lock_stale' ;;
    71) printf 'dependency_kernel_copy_carried' ;;
    72) printf 'dependency_shim_missing' ;;
    *) printf 'unknown_failure' ;;
  esac
}

class_exit() {
  local class="$1" mode="${2:-transport}"
  case "$class" in
    adaptation_witness_stale) printf '68' ;;
    kernel_skew) printf '67' ;;
    transport_lag)
      if [[ "$mode" == "transport" ]]; then printf '0'; else printf '69'; fi
      ;;
    identical|declared_adaptation|clean) printf '0' ;;
    conformance_failed) printf '1' ;;
    usage) printf '64' ;;
    target_refused) printf '65' ;;
    manifest_or_base_missing) printf '66' ;;
    dependency_lock_stale) printf '70' ;;
    dependency_kernel_copy_carried) printf '71' ;;
    dependency_shim_missing) printf '72' ;;
    *) printf '1' ;;
  esac
}

is_dependency_allowlisted() {
  local path="$1" allowed
  for allowed in $DEPENDENCY_SHIM_ALLOWLIST; do
    [[ "$path" == "$allowed" ]] && return 0
  done
  return 1
}

dependency_kernel_paths() {
  local kind path extra file rel
  [[ -f "$MANIFEST" ]] || {
    printf 'boat-refresh: export manifest missing: %s\n' "$MANIFEST" >&2
    return 66
  }
  while IFS=$'\t' read -r kind path extra; do
    [[ -n "$kind" && "$kind" != \#* ]] || continue
    [[ -z "${extra:-}" ]] || {
      printf 'boat-refresh: malformed manifest row for dependency check: %s %s %s\n' "$kind" "$path" "$extra" >&2
      return 66
    }
    case "$kind" in
      file)
        [[ -f "$SRC/$path" ]] || {
          printf 'boat-refresh: manifest names a missing source file: %s\n' "$path" >&2
          return 66
        }
        printf '%s\n' "$path"
        ;;
      dir)
        [[ -d "$SRC/$path" ]] || {
          printf 'boat-refresh: manifest names a missing source dir: %s\n' "$path" >&2
          return 66
        }
        while IFS= read -r file; do
          rel="${file#"$SRC/"}"
          printf '%s\n' "$rel"
        done < <(find "$SRC/$path" -type f | sort)
        ;;
      *)
        printf 'boat-refresh: manifest kind unknown: %s (file|dir)\n' "$kind" >&2
        return 66
        ;;
    esac
  done < "$MANIFEST"
  printf '%s\n' "$MANIFEST_SELF_PATH"
}

dependency_lock_rev() {
  local lock="$1" python
  python="$(command -v python3 || true)"
  [[ -n "$python" ]] || {
    printf 'boat-refresh: python3 unavailable for flake.lock dependency check\n' >&2
    return 65
  }
  "$python" - "$lock" <<'PYEOF'
import json
import sys

lock = sys.argv[1]
try:
    with open(lock, encoding="utf-8") as fh:
        data = json.load(fh)
except Exception as exc:
    print(f"boat-refresh: cannot read flake.lock: {exc}", file=sys.stderr)
    sys.exit(65)

try:
    rev = data["nodes"]["loop"]["locked"]["rev"]
except Exception:
    print("boat-refresh: flake.lock has no nodes.loop.locked.rev", file=sys.stderr)
    sys.exit(65)

if not isinstance(rev, str) or not rev:
    print("boat-refresh: nodes.loop.locked.rev is empty or non-string", file=sys.stderr)
    sys.exit(65)

print(rev)
PYEOF
}

emit_dependency_summary() {
  local summary="$1" verdict="$2" carried_count="${3:-0}"
  [[ -n "$summary" ]] || return 0
  printf '0\t0\t%s\t0\t0\t0\t%s\n' "$carried_count" "$verdict" > "$summary"
}

check_dependency_instance() {
  local target_path="$1" summary="$2" rev paths rel carried=() shim_path
  [[ -d "$target_path" ]] || {
    emit_dependency_summary "$summary" "target_refused"
    printf 'boat-refresh: dependency target does not exist: %s\n' "$target_path" >&2
    return 65
  }
  target_path="$(cd "$target_path" && pwd)"
  [[ -f "$target_path/flake.lock" ]] || {
    emit_dependency_summary "$summary" "dependency_lock_stale"
    printf 'boat-refresh: dependency_lock_stale — target has no flake.lock: %s\n' "$target_path" >&2
    return 70
  }
  rev="$(dependency_lock_rev "$target_path/flake.lock")" || {
    emit_dependency_summary "$summary" "dependency_lock_stale"
    return 70
  }
  git -C "$SRC" rev-parse --git-dir >/dev/null 2>&1 || {
    emit_dependency_summary "$summary" "manifest_or_base_missing"
    printf 'boat-refresh: source git history unavailable for dependency check: %s\n' "$SRC" >&2
    return 66
  }
  if ! git -C "$SRC" merge-base --is-ancestor "$rev" HEAD >/dev/null 2>&1; then
    emit_dependency_summary "$summary" "dependency_lock_stale"
    printf 'boat-refresh: dependency_lock_stale — loop rev is not an ancestor of source HEAD: %s\n' "$rev" >&2
    return 70
  fi

  paths="$(dependency_kernel_paths)" || {
    emit_dependency_summary "$summary" "manifest_or_base_missing"
    return 66
  }
  while IFS= read -r rel; do
    [[ -n "$rel" ]] || continue
    case "$rel" in
      tools/schemas/instance.tsv|tools/schemas/kernel-adaptations.tsv)
        continue
        ;;
    esac
    is_dependency_allowlisted "$rel" && continue
    if [[ -e "$target_path/$rel" ]]; then
      carried+=("$rel")
    fi
  done <<< "$paths"
  if [[ "${#carried[@]}" -gt 0 ]]; then
    emit_dependency_summary "$summary" "dependency_kernel_copy_carried" "${#carried[@]}"
    printf 'boat-refresh: dependency_kernel_copy_carried — dependency-mode target carries kernel file(s):\n' >&2
    printf '  %s\n' ${carried[@]+"${carried[@]}"} >&2
    return 71
  fi

  shim_path="tools/loop"
  if [[ ! -f "$target_path/$shim_path" ]]; then
    emit_dependency_summary "$summary" "dependency_shim_missing"
    printf 'boat-refresh: dependency_shim_missing — target has no %s shim\n' "$shim_path" >&2
    return 72
  fi

  emit_dependency_summary "$summary" "clean"
  printf 'boat-refresh: dependency clean: loop rev %s is an ancestor of source HEAD; no kernel copies carried; shim present\n' "$rev"
  return 0
}

run_wave() {
  local mode="transport" tmp rows=0 final_rc=0 final_pri=0
  local instance path note entry_mode extra rc cmd_rc pri class out err summary
  local identical lag skew adapted extraneous stale verdict counts
  local identical_targets=0 adapted_targets=0 lag_targets=0 skew_targets=0
  local stale_targets=0 refused_targets=0 missing_targets=0 conform_fail_targets=0 other_targets=0
  local dependency_lock_targets=0 dependency_copy_targets=0 dependency_shim_targets=0 lock_managed_targets=0 dependency_seen=0

  [[ -f "$BUNDLE_BASE" ]] || die "bundle base missing: $BUNDLE_BASE" 66
  if [[ "$check" -eq 1 ]]; then
    mode="check"
  elif [[ "$dryrun" -eq 1 ]]; then
    mode="dry-run"
  fi

  tmp="$(mktemp -d "${TMPDIR:-/tmp}/boat-refresh-wave.XXXXXX")" || exit 1
  trap 'rm -rf "$tmp"' RETURN

  if [[ "$mode" == "check" ]]; then
    printf 'instance\tidentical-count\tlag-count\tskew-count\tadaptation-count\textraneous-count\tverdict\n'
  else
    printf 'boat-refresh wave: base=%s mode=%s\n' "$BUNDLE_BASE" "$mode"
  fi

  while IFS=$'\t' read -r instance path note entry_mode extra; do
    [[ -n "$instance" && "$instance" != \#* ]] || continue
    [[ -n "$path" && -n "${note:-}" && -z "${extra:-}" ]] || die "malformed bundle base row (need instance<TAB>path<TAB>note<TAB>mode): $instance" 66
    entry_mode="${entry_mode:-copy}"
    case "$entry_mode" in
      copy|dependency) ;;
      *) die "malformed bundle base row mode (need copy|dependency): $instance" 66 ;;
    esac
    rows=$((rows + 1))
    if [[ "$entry_mode" == "dependency" && "$mode" != "check" ]]; then
      dependency_seen=1
      lock_managed_targets=$((lock_managed_targets + 1))
      printf 'boat-refresh wave target: instance=%s mode=dependency lock-managed skip rc=0\n' "$instance"
      continue
    fi
    summary="$tmp/summary.$rows.tsv"
    out="$tmp/out.$rows"
    err="$tmp/err.$rows"
    if [[ "$entry_mode" == "dependency" ]]; then
      dependency_seen=1
      check_dependency_instance "$path" "$summary" > "$out" 2> "$err"
    elif [[ "$mode" == "check" ]]; then
      BOAT_ROOT="$SRC" BOAT_EXPORT_MANIFEST="$MANIFEST" BOAT_REFRESH_SUMMARY_FILE="$summary" \
        bash "$TOOLS_DIR/boat-refresh.sh" "$path" --check > "$out" 2> "$err"
    elif [[ "$mode" == "dry-run" ]]; then
      BOAT_ROOT="$SRC" BOAT_EXPORT_MANIFEST="$MANIFEST" BOAT_REFRESH_SUMMARY_FILE="$summary" \
        bash "$TOOLS_DIR/boat-refresh.sh" "$path" --dry-run > "$out" 2> "$err"
    else
      BOAT_ROOT="$SRC" BOAT_EXPORT_MANIFEST="$MANIFEST" BOAT_REFRESH_SUMMARY_FILE="$summary" \
        bash "$TOOLS_DIR/boat-refresh.sh" "$path" > "$out" 2> "$err"
    fi
    cmd_rc=$?
    rc="$cmd_rc"

    identical=0; lag=0; skew=0; adapted=0; extraneous=0; stale=0
    verdict="$(rc_class "$cmd_rc")"
    if [[ -f "$summary" ]]; then
      IFS=$'\t' read -r identical lag skew adapted extraneous stale verdict < "$summary"
    fi
    if [[ "$mode" == "transport" && "$cmd_rc" -eq 1 ]]; then
      verdict="conformance_failed"
    fi

    case "$verdict" in
      identical) identical_targets=$((identical_targets + 1)) ;;
      declared_adaptation) adapted_targets=$((adapted_targets + 1)) ;;
      transport_lag) lag_targets=$((lag_targets + 1)) ;;
      kernel_skew) skew_targets=$((skew_targets + 1)) ;;
      adaptation_witness_stale) stale_targets=$((stale_targets + 1)) ;;
      target_refused) refused_targets=$((refused_targets + 1)) ;;
      manifest_or_base_missing) missing_targets=$((missing_targets + 1)) ;;
      conformance_failed) conform_fail_targets=$((conform_fail_targets + 1)) ;;
      dependency_lock_stale) dependency_lock_targets=$((dependency_lock_targets + 1)) ;;
      dependency_kernel_copy_carried) dependency_copy_targets=$((dependency_copy_targets + 1)) ;;
      dependency_shim_missing) dependency_shim_targets=$((dependency_shim_targets + 1)) ;;
      *) other_targets=$((other_targets + 1)) ;;
    esac

    if [[ "$mode" == "transport" ]]; then
      if [[ "$cmd_rc" -eq 0 ]]; then
        rc=0
      else
        rc="$cmd_rc"
      fi
    elif [[ "$rc" -eq 0 ]]; then
      rc="$(class_exit "$verdict" "$mode")"
    fi
    pri="$(exit_priority "$rc")"
    if (( pri > final_pri )); then
      final_pri="$pri"
      final_rc="$rc"
    fi

    if [[ "$mode" == "check" ]]; then
      printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$instance" "$identical" "$lag" "$skew" "$adapted" "$extraneous" "$verdict"
    else
      printf 'boat-refresh wave target: instance=%s identical=%s lag=%s skew=%s adapted=%s extraneous=%s stale=%s worst=%s rc=%s\n' \
        "$instance" "$identical" "$lag" "$skew" "$adapted" "$extraneous" "$stale" "$verdict" "$rc"
    fi
    if [[ "$rc" -ne 0 && "$mode" != "check" ]]; then
      sed 's/^/  stdout: /' "$out" >&2
      sed 's/^/  stderr: /' "$err" >&2
    fi
  done < "$BUNDLE_BASE"

  if [[ "$mode" != "check" ]]; then
    printf 'boat-refresh wave summary:\n'
    printf '  targets: %s\n' "$rows"
    printf '  identical: %s\n' "$identical_targets"
    printf '  declared_adaptation: %s\n' "$adapted_targets"
    printf '  transport_lag: %s\n' "$lag_targets"
    printf '  kernel_skew: %s\n' "$skew_targets"
    printf '  adaptation_witness_stale: %s\n' "$stale_targets"
    printf '  target_refused: %s\n' "$refused_targets"
    printf '  manifest_or_base_missing: %s\n' "$missing_targets"
    printf '  conformance_failed: %s\n' "$conform_fail_targets"
    if [[ "$dependency_seen" -eq 1 ]]; then
      printf '  lock_managed: %s\n' "$lock_managed_targets"
      printf '  dependency_lock_stale: %s\n' "$dependency_lock_targets"
      printf '  dependency_kernel_copy_carried: %s\n' "$dependency_copy_targets"
      printf '  dependency_shim_missing: %s\n' "$dependency_shim_targets"
    fi
    printf '  other_failure: %s\n' "$other_targets"
    printf '  exit: %s\n' "$final_rc"
  fi
  return "$final_rc"
}

target=""
restore=0; dryrun=0; wave=0; check=0
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --wave) wave=1; shift ;;
    --restore-conformance) restore=1; shift ;;
    --dry-run) dryrun=1; shift ;;
    --check) check=1; shift ;;
    --bundle-base|--base)
      [[ -n "${2:-}" ]] || usage
      BUNDLE_BASE="$2"; shift 2 ;;
    --*) die "unknown flag: $1" 64 ;;
    *)
      [[ -z "$target" ]] || usage
      target="$1"; shift ;;
  esac
done

if [[ "$wave" -eq 1 ]]; then
  [[ -z "$target" ]] || usage
  [[ "$restore" -eq 0 ]] || die "--wave --restore-conformance refused: restoration is a per-target operator decision" 64
  run_wave
  exit "$?"
fi

[[ -n "$target" ]] || usage
[[ "$restore" -eq 0 || "$check" -eq 0 ]] || die "--check --restore-conformance refused: check mode is read-only" 64

[[ -f "$MANIFEST" ]] || die "export manifest missing: $MANIFEST" 66
[[ -d "$target" ]] || die "target does not exist (refresh transports into an EXISTING instance; use boat-init for birth): $target" 65
target="$(cd "$target" && pwd)"
[[ "$target" != "$SRC" ]] || die "target is the source instance itself" 65
[[ -f "$target/tools/loop" ]] || die "target carries no loop (not a kernel-bearing instance): $target" 65

# --- load the target's declared transition functions --------------------------
ADAPT="$target/tools/schemas/kernel-adaptations.tsv"
declare -a adapt_paths=() adapt_shas=() adapt_cands=()
if [[ -f "$ADAPT" ]]; then
  while IFS=$'\t' read -r apath asha acand; do
    [[ -n "$apath" && "$apath" != \#* ]] || continue
    [[ -n "$asha" && -n "$acand" ]] || die "malformed adaptation row (need path<TAB>sha256<TAB>candidate): $apath" 68
    adapt_paths+=("$apath"); adapt_shas+=("$asha"); adapt_cands+=("$acand")
  done < "$ADAPT"
fi

is_adapted() { # PATH -> sets ADAPT_SHA/ADAPT_CAND, rc 0 if declared
  local p="$1" i
  for ((i=0; i<${#adapt_paths[@]}; i++)); do
    if [[ "${adapt_paths[$i]}" == "$p" ]]; then
      ADAPT_SHA="${adapt_shas[$i]}"; ADAPT_CAND="${adapt_cands[$i]}"
      return 0
    fi
  done
  return 1
}

matches_source_history() { # PATH -> rc 0 iff the target's copy equals the
  # file at SOME committed state of the source (transport-lag, not skew)
  local p="$1" rev
  git -C "$SRC" rev-parse --git-dir >/dev/null 2>&1 || return 1
  while IFS= read -r rev; do
    if git -C "$SRC" show "$rev:$p" 2>/dev/null | cmp -s - "$target/$p"; then
      return 0
    fi
  done < <(git -C "$SRC" log --format=%H -- "$p" 2>/dev/null)
  return 1
}

# --- classification pass (nothing written yet; fail-closed gates) --------------
declare -a to_copy=() skewed=() stale=() adapted_ok=() extraneous=()
identical=0

refresh_verdict() {
  if [[ "${#stale[@]}" -gt 0 ]]; then
    printf 'adaptation_witness_stale'
  elif [[ "${#skewed[@]}" -gt 0 || "${#extraneous[@]}" -gt 0 ]]; then
    printf 'kernel_skew'
  elif [[ "${#to_copy[@]}" -gt 0 ]]; then
    printf 'transport_lag'
  elif [[ "${#adapted_ok[@]}" -gt 0 ]]; then
    printf 'declared_adaptation'
  else
    printf 'identical'
  fi
}

emit_refresh_summary() {
  local verdict="$1"
  [[ -n "$SUMMARY_FILE" ]] || return 0
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$identical" "${#to_copy[@]}" "${#skewed[@]}" "${#adapted_ok[@]}" \
    "${#extraneous[@]}" "${#stale[@]}" "$verdict" > "$SUMMARY_FILE"
}

classify_file() { # PATH (manifest file row, or a file expanded from a dir row)
  local path="$1"
  case "$path" in
    tools/schemas/instance.tsv|tools/schemas/kernel-adaptations.tsv) return 0 ;;
  esac
  [[ -f "$SRC/$path" ]] || die "manifest names a missing source file: $path" 66
  if is_adapted "$path"; then
    if [[ ! -f "$target/$path" ]] || [[ "$(sha_file "$target/$path")" != "$ADAPT_SHA" ]]; then
      stale+=("$path (declared by ${ADAPT_CAND})")
    else
      adapted_ok+=("$path (${ADAPT_CAND})")
    fi
    return 0
  fi
  if [[ ! -f "$target/$path" ]]; then
    to_copy+=("$path")
  elif cmp -s "$SRC/$path" "$target/$path"; then
    identical=$((identical + 1))
  else
    # Diverged from the CURRENT fibre. If it matches no declaration it
    # is either a pending kernel update (target simply behind) or
    # genuine skew. The connection cannot distinguish intent — but it
    # can distinguish DIRECTION: a file byte-identical to SOME committed
    # state of the source's history is transport-lag, refreshable;
    # anything else is kernel_skew.
    if matches_source_history "$path"; then
      to_copy+=("$path")
    else
      skewed+=("$path")
    fi
  fi
}

while IFS=$'\t' read -r kind path; do
  [[ -n "$kind" && "$kind" != \#* ]] || continue
  case "$kind" in
    file)
      classify_file "$path"
      ;;
    dir)
      # A dir row transports its whole file tree: every source file
      # under it classifies exactly like a file row (round-1 review
      # finding: ignoring dir rows let fixture content lag under a
      # green refresh). Files present in the TARGET dir but absent at
      # the source are extraneous — fibre content the typical fibre
      # does not carry — and gate like skew (visible, never silent).
      [[ -d "$SRC/$path" ]] || die "manifest names a missing source dir: $path" 66
      while IFS= read -r f; do
        classify_file "${f#"$SRC/"}"
      done < <(find "$SRC/$path" -type f | sort)
      if [[ -d "$target/$path" ]]; then
        while IFS= read -r f; do
          rel="${f#"$target/"}"
          if [[ ! -f "$SRC/$rel" ]] && ! is_adapted "$rel"; then
            extraneous+=("$rel")
          fi
        done < <(find "$target/$path" -type f | sort)
      fi
      ;;
    *) die "manifest kind unknown: $kind (file|dir)" 66 ;;
  esac
done < "$MANIFEST"

# The row chart is not a row (boat-init must self-copy it at birth), but
# once a target exists the chart itself rides the connection. It is
# deliberately classified by the same function as ordinary file cargo,
# including declared adaptations, source-history lag, and skew refusal.
classify_file "$MANIFEST_SELF_PATH"

if [[ "$check" -eq 1 ]]; then
  verdict="$(refresh_verdict)"
  emit_refresh_summary "$verdict"
  if [[ -z "$SUMMARY_FILE" ]]; then
    printf 'identical-count\tlag-count\tskew-count\tadaptation-count\textraneous-count\tverdict\n'
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$identical" "${#to_copy[@]}" "${#skewed[@]}" "${#adapted_ok[@]}" \
      "${#extraneous[@]}" "$verdict"
  fi
  case "$verdict" in
    identical|declared_adaptation) exit 0 ;;
    transport_lag) exit 69 ;;
    kernel_skew) exit 67 ;;
    adaptation_witness_stale) exit 68 ;;
    *) exit 1 ;;
  esac
fi

if [[ "${#stale[@]}" -gt 0 ]]; then
  emit_refresh_summary "adaptation_witness_stale"
  printf 'boat-refresh: adaptation_witness_stale — declared adaptations do not match on-disk state:\n' >&2
  printf '  %s\n' ${stale[@]+"${stale[@]}"} >&2
  printf 'boat-refresh: repair the declaration (or the file) through the instance loop; nothing written\n' >&2
  exit 68
fi

if [[ ( "${#skewed[@]}" -gt 0 || "${#extraneous[@]}" -gt 0 ) && "$restore" -ne 1 ]]; then
  emit_refresh_summary "kernel_skew"
  printf 'boat-refresh: kernel_skew — %s undeclared divergence(s), %s extraneous file(s) under manifest dirs:\n' \
    "${#skewed[@]}" "${#extraneous[@]}" >&2
  printf '  skewed: %s\n' ${skewed[@]+"${skewed[@]}"} >&2
  printf '  extraneous: %s\n' ${extraneous[@]+"${extraneous[@]}"} >&2
  printf 'boat-refresh: curvature escalates to the operator: declare the adaptation through\n' >&2
  printf 'boat-refresh: the instance loop, or rerun with --restore-conformance to overwrite/remove\n' >&2
  printf 'boat-refresh: (every restored or removed file is recorded in the receipt); nothing written\n' >&2
  exit 67
fi

# Keep the receipt schema stable: the manifest remains part of the
# existing updated count, with one note only when that count includes it.
manifest_updated=0
for path in ${to_copy[@]+"${to_copy[@]}"}; do
  [[ "$path" == "$MANIFEST_SELF_PATH" ]] && manifest_updated=1
done

if [[ "$dryrun" -eq 1 ]]; then
  emit_refresh_summary "$(refresh_verdict)"
  printf 'boat-refresh (dry-run): %s to update, %s identical, %s adapted, %s skewed, %s extraneous%s\n' \
    "${#to_copy[@]}" "$identical" "${#adapted_ok[@]}" "${#skewed[@]}" "${#extraneous[@]}" \
    "$([[ "$restore" -eq 1 && ( "${#skewed[@]}" -gt 0 || "${#extraneous[@]}" -gt 0 ) ]] && printf ' (would restore/remove)')"
  exit 0
fi

# --- transport ----------------------------------------------------------------
for path in ${to_copy[@]+"${to_copy[@]}"}; do
  mkdir -p "$target/$(dirname "$path")"
  cp "$SRC/$path" "$target/$path"
done
declare -a restored=() removed=()
if [[ "$restore" -eq 1 ]]; then
  for path in ${skewed[@]+"${skewed[@]}"}; do
    mkdir -p "$target/$(dirname "$path")"
    cp "$SRC/$path" "$target/$path"
    restored+=("$path")
  done
  for path in ${extraneous[@]+"${extraneous[@]}"}; do
    rm -f "$target/$path"
    removed+=("$path")
  done
fi
chmod -R u+w "$target/tools" 2>/dev/null || true

# --- conformance: the differential runs IN the target --------------------------
conformance="FAILED"
if ( cd "$target" && bash tools/loop-model-diff.sh --fixtures ) \
     > "$target/.boat-refresh-conformance.log" 2>&1; then
  conformance="green"
fi

src_commit="$(git -C "$SRC" rev-parse --short HEAD 2>/dev/null || printf 'unavailable(no-git)')"
{
  printf '# Refresh receipt: %s\n\n' "$(basename "$target")"
  printf '```text\n'
  printf 'RefreshReceipt:\n'
  printf '  schema: boat.refresh.v0\n'
  printf '  refreshed_at: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '  source: %s (commit %s)\n' "$SRC" "$src_commit"
  printf '  law: premath.workspace-kernel-bundle.v0 (connection clause)\n'
  printf '  updated: %s file(s)\n' "$(( ${#to_copy[@]} ))"
  if [[ "$manifest_updated" -eq 1 ]]; then
    printf '    - %s (manifest self-transport)\n' "$MANIFEST_SELF_PATH"
  fi
  printf '  identical: %s file(s)\n' "$identical"
  printf '  adapted_skipped: %s file(s)\n' "${#adapted_ok[@]}"
  for a in ${adapted_ok[@]+"${adapted_ok[@]}"}; do printf '    - %s\n' "$a"; done
  printf '  restored_from_skew: %s file(s)\n' "${#restored[@]}"
  for r in ${restored[@]+"${restored[@]}"}; do printf '    - %s\n' "$r"; done
  printf '  removed_extraneous: %s file(s)\n' "${#removed[@]}"
  for x in ${removed[@]+"${removed[@]}"}; do printf '    - %s\n' "$x"; done
  printf '  verification_boundary: tools/loop-model-diff.sh --fixtures, run inside this instance\n'
  printf '  conformance: %s\n' "$conformance"
  printf '```\n'
} > "$target/REFRESH-RECEIPT.md"

emit_refresh_summary "$(refresh_verdict)"

if [[ "$conformance" != "green" ]]; then
  printf 'boat-refresh: CONFORMANCE FAILED — the transported loop and its model disagree\n' >&2
  printf 'boat-refresh: (log: %s; tree kept; receipt records the failure)\n' \
    "$target/.boat-refresh-conformance.log" >&2
  exit 1
fi

printf 'boat-refresh: %s refreshed from %s@%s (%s updated, %s identical, %s adapted, %s restored; conformance green)\n' \
  "$(basename "$target")" "$(basename "$SRC")" "$src_commit" \
  "${#to_copy[@]}" "$identical" "${#adapted_ok[@]}" "${#restored[@]}"
printf 'boat-refresh: commit the receipt in the target: git add -A && git commit (loop: kernel refresh)\n'
exit 0
