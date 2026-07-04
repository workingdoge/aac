#!/usr/bin/env bash
set -u

# lock-bump.sh TARGET [--to REV] [--dry-run]
#
# Mechanizes dependency-mode kernel transport for instances that consume Loop
# through a flake.lock `loop` input plus a tools/loop shim.
#
# Env:
#   BOAT_LOCK_BUMP_SOURCE overrides the Loop source git repo used for monotone
#     checks and default --to resolution (default: lock input file URL, then this
#     script's root when it is a git repo).
#   BOAT_ROOT is accepted as a source-root alias for boat-refresh parity.
#   BOAT_BUNDLE_BASE overrides tools/schemas/bundle-base.tsv.
#   BOAT_LOCK_BUMP_STORE_CMD overrides store materialization. The default is:
#     nix --extra-experimental-features "nix-command flakes" build .#kernelStore --no-link --print-out-paths
#
# Exit: 0 success or dry-run; 80 usage; 81 target_refused;
#       82 non_dependency_target; 83 lock_parse_failed;
#       84 non_monotone_update; 85 lock_update_failed;
#       86 store_materialization_failed; 87 shim_sync_failed;
#       88 receipt_write_failed.
# These codes deliberately avoid boat-refresh/lane/loop's documented tables
# (notably 1 and 64-72, plus loop's 69/70).

TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_ROOT="$(cd "$TOOLS_DIR/.." && pwd)"
SRC="${BOAT_LOCK_BUMP_SOURCE:-${BOAT_ROOT:-$DEFAULT_ROOT}}"
BUNDLE_BASE="${BOAT_BUNDLE_BASE:-$SRC/tools/schemas/bundle-base.tsv}"
STORE_CMD="${BOAT_LOCK_BUMP_STORE_CMD:-nix --extra-experimental-features \"nix-command flakes\" build .#kernelStore --no-link --print-out-paths}"

die() {
  printf 'lock-bump: %s\n' "$1" >&2
  exit "${2:-1}"
}

usage() {
  die "usage: lock-bump.sh TARGET [--to REV] [--dry-run]" 80
}

sha_file() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    sha256sum "$1" | awk '{print $1}'
  fi
}

short_rev() {
  printf '%s' "$1" | cut -c1-12
}

abs_dir() {
  local path="$1"
  [[ -d "$path" ]] || return 1
  ( cd "$path" && pwd )
}

loop_lock_info() {
  local lock="$1" python
  python="$(command -v python3 2>/dev/null || true)"
  [[ -n "$python" ]] || {
    printf 'lock-bump: python3 unavailable for flake.lock parsing\n' >&2
    return 83
  }
  "$python" - "$lock" <<'PYEOF'
import json
import sys

lock = sys.argv[1]
try:
    with open(lock, encoding="utf-8") as fh:
        data = json.load(fh)
except Exception as exc:
    print(f"lock-bump: cannot read flake.lock: {exc}", file=sys.stderr)
    sys.exit(83)

try:
    node = data["nodes"]["loop"]
    locked = node["locked"]
    rev = locked["rev"]
except Exception:
    print("lock-bump: flake.lock has no nodes.loop.locked.rev", file=sys.stderr)
    sys.exit(83)

if not isinstance(rev, str) or not rev:
    print("lock-bump: nodes.loop.locked.rev is empty or non-string", file=sys.stderr)
    sys.exit(83)

def ref_from(obj):
    if not isinstance(obj, dict):
        return ""
    url = obj.get("url")
    if isinstance(url, str) and url:
        return url
    path = obj.get("path")
    if isinstance(path, str) and path:
        return path
    return ""

ref = ref_from(node.get("original")) or ref_from(locked)
print(f"{rev}\t{ref}")
PYEOF
}

git_path_from_ref() {
  local ref="$1" path
  ref="${ref%%\?*}"
  case "$ref" in
    git+file://*) path="${ref#git+file://}" ;;
    file://*) path="${ref#file://}" ;;
    /*) path="$ref" ;;
    *) return 1 ;;
  esac
  [[ -d "$path" ]] || return 1
  git -C "$path" rev-parse --git-dir >/dev/null 2>&1 || return 1
  abs_dir "$path"
}

resolve_source_git() {
  local input_ref="$1" path
  if [[ -n "${BOAT_LOCK_BUMP_SOURCE:-}" ]]; then
    path="$(abs_dir "$BOAT_LOCK_BUMP_SOURCE")" || return 1
    git -C "$path" rev-parse --git-dir >/dev/null 2>&1 || return 1
    printf '%s\n' "$path"
    return 0
  fi
  if path="$(git_path_from_ref "$input_ref" 2>/dev/null)"; then
    printf '%s\n' "$path"
    return 0
  fi
  if [[ -d "$SRC" ]] && git -C "$SRC" rev-parse --git-dir >/dev/null 2>&1; then
    abs_dir "$SRC"
    return 0
  fi
  return 1
}

bundle_mode_for_target() {
  local target_path="$1" bundle="$2" instance path note mode extra resolved
  [[ -f "$bundle" ]] || return 2
  while IFS=$'\t' read -r instance path note mode extra; do
    [[ -n "$instance" && "$instance" != \#* ]] || continue
    [[ -n "${path:-}" ]] || continue
    mode="${mode:-copy}"
    if [[ -d "$path" ]]; then
      resolved="$(cd "$path" && pwd)"
    else
      resolved="$path"
    fi
    if [[ "$resolved" == "$target_path" || "$path" == "$target_path" ]]; then
      printf '%s\n' "$mode"
      return 0
    fi
  done < "$bundle"
  return 1
}

lock_override_ref() {
  local input_ref="$1" source_git="$2" rev="$3" base
  if [[ -z "$input_ref" ]]; then
    input_ref="git+file://$source_git"
  fi
  base="${input_ref%%\?*}"
  case "$base" in
    git+*) printf '%s?rev=%s\n' "$base" "$rev" ;;
    file://*) printf 'git+%s?rev=%s\n' "$base" "$rev" ;;
    /*) printf 'git+file://%s?rev=%s\n' "$base" "$rev" ;;
    *) printf '%s?rev=%s\n' "$base" "$rev" ;;
  esac
}

resolve_kernel_dir() {
  local root="$1" candidate found count=0
  [[ -d "$root" ]] || return 1
  if [[ -f "$root/tools/kernel-shim.template.sh" ]]; then
    printf '%s\n' "$root"
    return 0
  fi
  while IFS= read -r candidate; do
    if [[ -f "$candidate/tools/kernel-shim.template.sh" ]]; then
      found="$candidate"
      count=$((count + 1))
    fi
  done < <(find "$root" -mindepth 1 -maxdepth 1 -type d | sort)
  [[ "$count" -eq 1 ]] || return 1
  printf '%s\n' "$found"
}

target_arg=""
to_rev=""
dryrun=0
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --to)
      [[ -n "${2:-}" ]] || usage
      to_rev="$2"
      shift 2
      ;;
    --dry-run)
      dryrun=1
      shift
      ;;
    --*)
      die "unknown flag: $1" 80
      ;;
    *)
      [[ -z "$target_arg" ]] || usage
      target_arg="$1"
      shift
      ;;
  esac
done
[[ -n "$target_arg" ]] || usage

target_path="$(abs_dir "$target_arg")" \
  || die "target does not exist or is not a directory: $target_arg" 81
cwd_path="$(pwd)"

[[ -f "$target_path/flake.lock" ]] \
  || die "dependency target has no flake.lock: $target_path" 82
[[ -f "$target_path/tools/loop" ]] \
  || die "dependency target has no tools/loop shim: $target_path" 82

lock_info="$(loop_lock_info "$target_path/flake.lock")" || exit 83
current_rev="${lock_info%%	*}"
input_ref="${lock_info#*	}"
[[ "$input_ref" != "$lock_info" ]] || input_ref=""

verify_mode="self-shape"
if [[ -f "$BUNDLE_BASE" ]]; then
  mode="$(bundle_mode_for_target "$target_path" "$BUNDLE_BASE")"
  bundle_rc=$?
  if [[ "$bundle_rc" -eq 0 ]]; then
    [[ "$mode" == "dependency" ]] \
      || die "target is bundle-base mode=$mode, not dependency: $target_path" 82
    verify_mode="bundle-base"
  elif [[ "$target_path" != "$cwd_path" ]]; then
    die "target is not declared dependency-mode in bundle base: $target_path" 82
  fi
fi

source_git="$(resolve_source_git "$input_ref")" \
  || die "cannot resolve Loop source git repo for monotone check" 84

if [[ -z "$to_rev" ]]; then
  target_rev="$(git -C "$source_git" rev-parse HEAD 2>/dev/null)" \
    || die "cannot resolve source HEAD for default --to" 84
else
  target_rev="$(git -C "$source_git" rev-parse "$to_rev^{commit}" 2>/dev/null)" \
    || die "cannot resolve requested --to rev: $to_rev" 84
fi

if ! git -C "$source_git" merge-base --is-ancestor "$current_rev" "$target_rev" >/dev/null 2>&1; then
  die "non_monotone_update: current pin $(short_rev "$current_rev") is not an ancestor of target $(short_rev "$target_rev")" 84
fi

override_ref="$(lock_override_ref "$input_ref" "$source_git" "$target_rev")"
receipt_path="$target_path/MIGRATION-RECEIPT.md"
if [[ ! -f "$receipt_path" && -f "$target_path/RECEIPTS.md" ]]; then
  receipt_path="$target_path/RECEIPTS.md"
fi

if [[ "$dryrun" -eq 1 ]]; then
  printf 'lock-bump (dry-run): target=%s\n' "$target_path"
  printf 'lock-bump (dry-run): verify=%s current=%s target=%s source=%s\n' \
    "$verify_mode" "$current_rev" "$target_rev" "$source_git"
  printf 'lock-bump (dry-run): monotone=yes\n'
  printf 'lock-bump (dry-run): would run nix flake lock --update-input loop --override-input loop %s\n' "$override_ref"
  printf 'lock-bump (dry-run): would run store materializer in target: %s\n' "$STORE_CMD"
  printf 'lock-bump (dry-run): would compare store tools/kernel-shim.template.sh with tools/loop\n'
  printf 'lock-bump (dry-run): would append boat.lock-bump.v0 receipt to %s\n' "$receipt_path"
  exit 0
fi

work="$(mktemp -d "${TMPDIR:-/tmp}/lock-bump.XXXXXX")" || exit 88
cleanup() { rm -rf "$work"; }
trap cleanup EXIT

cp "$target_path/flake.lock" "$work/flake.lock.before" \
  || die "failed to snapshot flake.lock before mutation" 88
cp "$target_path/tools/loop" "$work/loop.before" \
  || die "failed to snapshot tools/loop before mutation" 88
receipt_existed=0
if [[ -f "$receipt_path" ]]; then
  cp "$receipt_path" "$work/receipt.before" \
    || die "failed to snapshot receipt before mutation: $receipt_path" 88
  receipt_existed=1
fi

rollback_target() {
  cp "$work/flake.lock.before" "$target_path/flake.lock" 2>/dev/null || true
  cp "$work/loop.before" "$target_path/tools/loop" 2>/dev/null || true
  chmod +x "$target_path/tools/loop" 2>/dev/null || true
  if [[ "$receipt_existed" -eq 1 ]]; then
    cp "$work/receipt.before" "$receipt_path" 2>/dev/null || true
  else
    rm -f "$receipt_path" 2>/dev/null || true
  fi
}

abort_after_mutation() {
  local msg="$1" code="$2"
  rollback_target
  die "$msg" "$code"
}

if ! (
  cd "$target_path" && \
    nix --extra-experimental-features "nix-command flakes" \
      flake lock --update-input loop --override-input loop "$override_ref"
) > "$work/lock.out" 2> "$work/lock.err"; then
  sed -n '1,120p' "$work/lock.err" >&2
  abort_after_mutation "nix flake lock failed while pinning loop to $(short_rev "$target_rev")" 85
fi

post_lock_info="$(loop_lock_info "$target_path/flake.lock")" \
  || abort_after_mutation "cannot parse flake.lock after lock update" 85
post_rev="${post_lock_info%%	*}"
if [[ "$post_rev" != "$target_rev" ]]; then
  abort_after_mutation "nix flake lock did not pin loop to requested rev: got $post_rev wanted $target_rev" 85
fi

if ! store_out="$(
  cd "$target_path" && \
    BOAT_LOCK_BUMP_TARGET="$target_path" \
    BOAT_LOCK_BUMP_FROM_REV="$current_rev" \
    BOAT_LOCK_BUMP_TO_REV="$target_rev" \
    bash -c "$STORE_CMD"
)"; then
  abort_after_mutation "store materializer failed: $STORE_CMD" 86
fi
printf '%s\n' "$store_out" > "$work/store.out"
store_path="$(awk 'NF { print; exit }' "$work/store.out")"
[[ -n "$store_path" ]] \
  || abort_after_mutation "store materializer printed no store path" 86
kernel_dir="$(resolve_kernel_dir "$store_path")" \
  || abort_after_mutation "store materializer output has no tools/kernel-shim.template.sh: $store_path" 86

template="$kernel_dir/tools/kernel-shim.template.sh"
installed="$target_path/tools/loop"
old_shim_sha="$(sha_file "$installed")" \
  || abort_after_mutation "cannot hash installed shim" 87
new_shim_sha="$(sha_file "$template")" \
  || abort_after_mutation "cannot hash store shim template" 87
shim_changed="n"
if ! cmp -s "$template" "$installed"; then
  cp "$template" "$installed" \
    || abort_after_mutation "failed to reinstall tools/loop shim" 87
  chmod +x "$installed" \
    || abort_after_mutation "failed to chmod tools/loop shim" 87
  after_shim_sha="$(sha_file "$installed")" \
    || abort_after_mutation "cannot hash reinstalled shim" 87
  [[ "$after_shim_sha" == "$new_shim_sha" ]] \
    || abort_after_mutation "reinstalled shim digest mismatch" 87
  shim_changed="y"
else
  after_shim_sha="$old_shim_sha"
fi

ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
{
  printf '\n## LockBumpReceipt %s\n\n' "$ts"
  printf '```text\n'
  printf 'LockBumpReceipt:\n'
  printf '  schema: boat.lock-bump.v0\n'
  printf '  ts: %s\n' "$ts"
  printf '  from-rev: %s\n' "$current_rev"
  printf '  to-rev: %s\n' "$target_rev"
  printf '  store-path: %s\n' "$kernel_dir"
  printf '  shim: tools/loop\n'
  printf '  shim-changed: %s\n' "$shim_changed"
  printf '  shim-installed-sha256-before: %s\n' "$old_shim_sha"
  printf '  shim-template-sha256: %s\n' "$new_shim_sha"
  printf '  shim-installed-sha256-after: %s\n' "$after_shim_sha"
  printf '  verification-boundary: tools/lock-bump.sh; store materializer command recorded by operator environment\n'
  printf '```\n'
} > "$work/receipt.block" \
  || abort_after_mutation "failed to form lock-bump receipt" 88

cat "$work/receipt.block" >> "$receipt_path" \
  || abort_after_mutation "failed to append lock-bump receipt: $receipt_path" 88

printf 'lock-bump: %s loop pin %s -> %s; store=%s; shim_changed=%s\n' \
  "$(basename "$target_path")" "$(short_rev "$current_rev")" \
  "$(short_rev "$target_rev")" "$kernel_dir" "$shim_changed"
printf 'lock-bump: receipt appended: %s\n' "$receipt_path"
printf 'lock-bump: commit the receipt in the target: git add -A && git commit (loop: lock bump to %s)\n' \
  "$(short_rev "$target_rev")"
