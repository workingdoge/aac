#!/usr/bin/env bash
set -u

MANIFEST_SELF_PATH="tools/schemas/export-manifest.tsv"
INSTANCE_SOUL="tools/schemas/instance.tsv"
ADAPTATION_SOUL="tools/schemas/kernel-adaptations.tsv"
SHIM_PATH="tools/loop"
RECEIPT="MIGRATION-RECEIPT.md"

die() {
  printf 'migrate-to-dependency: %s\n' "$1" >&2
  exit "${2:-1}"
}

sha_file() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    sha256sum "$1" | awk '{print $1}'
  fi
}

require_repo_root() {
  [[ -f "flake.lock" ]] || die "run from repo root: flake.lock not found" 64
  [[ -f "migrate-to-dependency.sh" ]] || die "run from repo root: migrate-to-dependency.sh not found" 64
  [[ -d "tools" ]] || die "run from repo root: tools/ not found" 64
}

lock_value() {
  local key="$1" lock="${2:-flake.lock}"
  python3 - "$key" "$lock" <<'PYEOF'
import json
import sys

key, path = sys.argv[1:3]
try:
    with open(path, encoding="utf-8") as fh:
        data = json.load(fh)
    loop = data["nodes"]["loop"]
except Exception as exc:
    print(f"cannot read flake.lock loop node: {exc}", file=sys.stderr)
    sys.exit(65)

if key == "rev":
    value = loop.get("locked", {}).get("rev")
elif key == "url":
    value = (
        loop.get("locked", {}).get("url")
        or loop.get("original", {}).get("url")
        or loop.get("original", {}).get("path")
    )
else:
    raise SystemExit(64)

if not isinstance(value, str) or not value:
    print(f"nodes.loop {key} is empty or non-string", file=sys.stderr)
    sys.exit(65)
print(value)
PYEOF
}

loop_path_from_lock() {
  local raw="$1"
  case "$raw" in
    file://*) printf '%s\n' "${raw#file://}" ;;
    /*) printf '%s\n' "$raw" ;;
    *) return 1 ;;
  esac
}

verify_loop_lock_ancestor() {
  local rev raw loop_path live_head
  rev="$(lock_value rev)" || die "could not read pinned loop rev from flake.lock" 70
  raw="$(lock_value url)" || die "could not read loop url from flake.lock" 70
  loop_path="$(loop_path_from_lock "$raw")" \
    || die "loop input is not a local file path: $raw" 70
  [[ -d "$loop_path/.git" ]] \
    || die "loop input has no git history for ancestry check: $loop_path" 70
  if ! git -C "$loop_path" merge-base --is-ancestor "$rev" HEAD >/dev/null 2>&1; then
    die "flake.lock loop rev is not an ancestor of live loop HEAD: $rev" 70
  fi
  live_head="$(git -C "$loop_path" rev-parse HEAD)" \
    || die "could not read live loop HEAD: $loop_path" 70
  printf '%s\t%s\t%s\n' "$rev" "$loop_path" "$live_head"
}

resolve_kernel_dir() {
  local root="$1" candidate found="" count=0
  [[ -d "$root" ]] || return 1
  if [[ -x "$root/tools/loop" ]]; then
    printf '%s\n' "$(cd "$root" && pwd)"
    return 0
  fi
  while IFS= read -r candidate; do
    if [[ -x "$candidate/tools/loop" ]]; then
      found="$candidate"
      count=$((count + 1))
    fi
  done < <(find "$root" -mindepth 1 -maxdepth 1 -type d | sort)
  [[ "$count" -eq 1 ]] || return 1
  printf '%s\n' "$(cd "$found" && pwd)"
}

kernel_store() {
  local out err
  if [[ -n "${BOAT_KERNEL_STORE:-}" ]]; then
    resolve_kernel_dir "$BOAT_KERNEL_STORE" \
      || die "BOAT_KERNEL_STORE does not contain an executable kernel tools/loop" 66
    return 0
  fi
  command -v nix >/dev/null 2>&1 \
    || die "nix is required unless BOAT_KERNEL_STORE points at a kernel export" 66
  err="${TMPDIR:-/tmp}/aac-kernelStore.$$.err"
  out="$(
    nix --extra-experimental-features "nix-command flakes" \
      build .#kernelStore --no-link --print-out-paths 2>"$err"
  )" || {
    sed -n '1,120p' "$err" >&2
    rm -f "$err"
    die "nix build .#kernelStore failed; set BOAT_KERNEL_STORE for the offline path" 66
  }
  rm -f "$err"
  resolve_kernel_dir "$out" \
    || die "nix build .#kernelStore did not produce an executable kernel" 66
}

manifest_paths_from_local() {
  local manifest="$1"
  python3 - "$manifest" "$(pwd)" "$INSTANCE_SOUL" "$ADAPTATION_SOUL" <<'PYEOF'
import os
import sys

manifest, root, instance_soul, adaptation_soul = sys.argv[1:5]
try:
    fh = open(manifest, encoding="utf-8")
except Exception as exc:
    print(f"cannot read manifest: {exc}", file=sys.stderr)
    sys.exit(66)

for raw in fh:
    line = raw.rstrip("\n")
    if not line or line.startswith("#"):
        continue
    parts = line.split("\t")
    if len(parts) != 2:
        print(f"malformed manifest row: {line}", file=sys.stderr)
        sys.exit(66)
    kind, path = parts
    full = os.path.join(root, path)
    if kind == "file":
        if not os.path.isfile(full):
            if path in (instance_soul, adaptation_soul):
                print(path)
                continue
            print(f"manifest names missing file: {path}", file=sys.stderr)
            sys.exit(66)
        print(path)
    elif kind == "dir":
        if not os.path.isdir(full):
            print(f"manifest names missing dir: {path}", file=sys.stderr)
            sys.exit(66)
        for dirpath, dirnames, filenames in os.walk(full):
            dirnames.sort()
            for name in sorted(filenames):
                rel = os.path.relpath(os.path.join(dirpath, name), root)
                print(rel)
    else:
        print(f"manifest kind unknown: {kind}", file=sys.stderr)
        sys.exit(66)
print("tools/schemas/export-manifest.tsv")
PYEOF
}

manifest_paths_from_store() {
  local store="$1"
  (
    cd "$store" || exit 66
    find . -type f | sed 's#^\./##' | sort
    printf '%s\n' "$MANIFEST_SELF_PATH"
  )
}

is_soul_or_shim() {
  case "$1" in
    "$INSTANCE_SOUL"|"$ADAPTATION_SOUL"|"$SHIM_PATH") return 0 ;;
    *) return 1 ;;
  esac
}

write_non_carveout_paths() {
  local src="$1" out="$2" rel
  : > "$out" || return 1
  while IFS= read -r rel; do
    [[ -n "$rel" ]] || continue
    is_soul_or_shim "$rel" && continue
    printf '%s\n' "$rel" >> "$out"
  done < "$src"
  sort -u "$out" -o "$out"
}

verify_kernel_store_against_local_manifest() {
  local store="$1" manifest="$2"
  local expected_all expected actual_all actual rel rc
  [[ -f "$manifest" ]] || return 0
  expected_all="$(mktemp "${TMPDIR:-/tmp}/aac-verify-expected-all.XXXXXX")" || return 1
  expected="$(mktemp "${TMPDIR:-/tmp}/aac-verify-expected.XXXXXX")" || {
    rm -f "$expected_all"
    return 1
  }
  actual_all="$(mktemp "${TMPDIR:-/tmp}/aac-verify-actual-all.XXXXXX")" || {
    rm -f "$expected_all" "$expected"
    return 1
  }
  actual="$(mktemp "${TMPDIR:-/tmp}/aac-verify-actual.XXXXXX")" || {
    rm -f "$expected_all" "$expected" "$actual_all"
    return 1
  }

  manifest_paths_from_local "$manifest" > "$expected_all" || {
    rc=$?
    rm -f "$expected_all" "$expected" "$actual_all" "$actual"
    return "$rc"
  }
  (
    cd "$store" || exit 66
    find . -type f | sed 's#^\./##'
  ) > "$actual_all" || {
    rc=$?
    rm -f "$expected_all" "$expected" "$actual_all" "$actual"
    return "$rc"
  }

  write_non_carveout_paths "$expected_all" "$expected" || {
    rc=$?
    rm -f "$expected_all" "$expected" "$actual_all" "$actual"
    return "$rc"
  }
  write_non_carveout_paths "$actual_all" "$actual" || {
    rc=$?
    rm -f "$expected_all" "$expected" "$actual_all" "$actual"
    return "$rc"
  }

  if ! cmp -s "$expected" "$actual"; then
    comm -23 "$expected" "$actual" | awk 'NR <= 40 { print "kernel store missing manifest file: " $0 > "/dev/stderr" }'
    comm -13 "$expected" "$actual" | awk 'NR <= 40 { print "kernel store has non-manifest file: " $0 > "/dev/stderr" }'
    rm -f "$expected_all" "$expected" "$actual_all" "$actual"
    return 66
  fi

  while IFS= read -r rel; do
    [[ -n "$rel" ]] || continue
    if [[ "$(sha_file "$rel")" != "$(sha_file "$store/$rel")" ]]; then
      printf 'kernel store digest mismatch: %s\n' "$rel" >&2
      rm -f "$expected_all" "$expected" "$actual_all" "$actual"
      return 66
    fi
  done < "$expected"

  rm -f "$expected_all" "$expected" "$actual_all" "$actual"
}

write_paths_file() {
  local out="$1" store="$2"
  if [[ -f "$MANIFEST_SELF_PATH" ]]; then
    manifest_paths_from_local "$MANIFEST_SELF_PATH" > "$out"
  else
    manifest_paths_from_store "$store" > "$out"
  fi
}

has_removable_kernel_files() {
  local paths_file="$1" rel found=1
  while IFS= read -r rel; do
    [[ -n "$rel" ]] || continue
    is_soul_or_shim "$rel" && continue
    if [[ -e "$rel" ]]; then
      found=0
      break
    fi
  done < "$paths_file"
  return "$found"
}

assert_no_kernel_copies() {
  local paths_file="$1" rel remaining=()
  while IFS= read -r rel; do
    [[ -n "$rel" ]] || continue
    is_soul_or_shim "$rel" && continue
    if [[ -e "$rel" ]]; then
      remaining+=("$rel")
    fi
  done < "$paths_file"
  if [[ "${#remaining[@]}" -gt 0 ]]; then
    printf 'migrate-to-dependency: dependency-mode tree still carries kernel file(s):\n' >&2
    printf '  %s\n' "${remaining[@]}" >&2
    return 71
  fi
}

install_shim() {
  local template="$1"
  mkdir -p "$(dirname "$SHIM_PATH")" || return 1
  cp "$template" "$SHIM_PATH" || return 1
  chmod +x "$SHIM_PATH" || return 1
}

write_receipt() {
  local pinned="$1" loop_path="$2" live_head="$3" store="$4" removed="$5" shim_sha="$6"
  {
    printf '# Migration receipt: aac dependency mode\n\n'
    printf '```text\n'
    printf 'MigrationReceipt:\n'
    printf '  schema: boat.migration.v0\n'
    printf '  migrated_at: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf '  law: premath.workspace-kernel-bundle.v0 (connection clause)\n'
    printf '  from: copy-mode\n'
    printf '  to: dependency-mode\n'
    printf '  kernel_source: %s\n' "$loop_path"
    printf '  kernel_rev_pinned: %s\n' "$pinned"
    printf '  kernel_rev_live: %s\n' "$live_head"
    printf '  kernel_store: %s\n' "$store"
    printf '  removed: %s file(s)\n' "$removed"
    printf '  shim: %s\n' "$SHIM_PATH"
    printf '  shim_sha256: %s\n' "$shim_sha"
    printf '  preserved_souls:\n'
    printf '    - %s\n' "$INSTANCE_SOUL"
    printf '    - %s\n' "$ADAPTATION_SOUL"
    printf '  verification_boundary: migrate-to-dependency.sh with nix build .#kernelStore or BOAT_KERNEL_STORE fallback\n'
    printf '  follow_up: loop-side bundle-base.tsv mode flip is a separate loop-side change\n'
    printf '```\n'
  } > "$RECEIPT"
}

main() {
  local lock_info pinned loop_path live_head store paths_file template_tmp rel removed=0 shim_sha
  require_repo_root
  lock_info="$(verify_loop_lock_ancestor)" || exit "$?"
  pinned="$(printf '%s\n' "$lock_info" | awk -F'\t' '{print $1}')"
  loop_path="$(printf '%s\n' "$lock_info" | awk -F'\t' '{print $2}')"
  live_head="$(printf '%s\n' "$lock_info" | awk -F'\t' '{print $3}')"
  store="$(kernel_store)" || exit "$?"
  verify_kernel_store_against_local_manifest "$store" "$MANIFEST_SELF_PATH" \
    || die "BOAT_KERNEL_STORE does not match the local manifest set" 66

  paths_file="$(mktemp "${TMPDIR:-/tmp}/aac-kernel-paths.XXXXXX")" \
    || die "mktemp failed" 1
  template_tmp="$(mktemp "${TMPDIR:-/tmp}/aac-loop-shim.XXXXXX")" \
    || die "mktemp failed" 1
  trap "rm -f $(printf '%q' "$paths_file") $(printf '%q' "$template_tmp")" EXIT

  write_paths_file "$paths_file" "$store" || exit "$?"
  if [[ -f "tools/kernel-shim.template.sh" ]]; then
    cp "tools/kernel-shim.template.sh" "$template_tmp" || die "could not copy local shim template" 1
  elif [[ -f "$store/tools/kernel-shim.template.sh" ]]; then
    cp "$store/tools/kernel-shim.template.sh" "$template_tmp" || die "could not copy store shim template" 1
  else
    die "kernel shim template missing from local tree and kernel store" 66
  fi

  if [[ -f "$RECEIPT" && -f "$SHIM_PATH" ]] \
    && cmp -s "$template_tmp" "$SHIM_PATH" \
    && ! has_removable_kernel_files "$paths_file"; then
    printf 'migrate-to-dependency: already dependency-mode; no-op\n'
    printf 'migrate-to-dependency: follow-up: loop-side bundle-base.tsv mode flip is a separate loop-side change\n'
    exit 0
  fi

  while IFS= read -r rel; do
    [[ -n "$rel" ]] || continue
    is_soul_or_shim "$rel" && continue
    if [[ -e "$rel" ]]; then
      rm -f "$rel" || die "could not remove kernel file: $rel" 1
      removed=$((removed + 1))
    fi
  done < "$paths_file"

  install_shim "$template_tmp" || die "could not install tools/loop shim" 1
  assert_no_kernel_copies "$paths_file" || exit "$?"
  shim_sha="$(sha_file "$SHIM_PATH")"
  write_receipt "$pinned" "$loop_path" "$live_head" "$store" "$removed" "$shim_sha"

  printf 'migrate-to-dependency: migrated copy-mode -> dependency-mode (%s file(s) removed; shim_sha256=%s)\n' "$removed" "$shim_sha"
  printf 'migrate-to-dependency: wrote %s\n' "$RECEIPT"
  printf 'migrate-to-dependency: follow-up: loop-side bundle-base.tsv mode flip is a separate loop-side change\n'
}

main "$@"
