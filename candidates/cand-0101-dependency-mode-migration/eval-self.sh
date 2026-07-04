#!/usr/bin/env bash
set -u

CAND="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND/../.." && pwd)"

# shellcheck source=/dev/null
source "$ROOT/tools/eval/eval-lib.sh" || exit 1
eval_init "$CAND" "$ROOT" || exit 1

work="$(mktemp -d "${TMPDIR:-/tmp}/aac-cand-0101.XXXXXX")"
cleanup() {
  chmod -R u+w "$work" 2>/dev/null || true
  rm -rf "$work" "$RESULTS"
}
trap cleanup EXIT

LOOP_ROOT="/Users/arj/irai/loop"
LOOP_PIN="932d0d408273d26e2a818dbad91e1af7828e2480"
LOOP_NAR="sha256-tmWl/4nBvRp4vFLJgryFMAmJqXlnHxvUlo9wa1yt50k="
INSTANCE_SOUL="tools/schemas/instance.tsv"
ADAPTATION_SOUL="tools/schemas/kernel-adaptations.tsv"
MANIFEST_SELF_PATH="tools/schemas/export-manifest.tsv"
SHIM_PATH="tools/loop"

is_soul_or_shim() {
  case "$1" in
    "$INSTANCE_SOUL"|"$ADAPTATION_SOUL"|"$SHIM_PATH") return 0 ;;
    *) return 1 ;;
  esac
}

path_state() {
  local path="$1"
  if [[ -f "$path" ]]; then
    printf 'file:%s' "$(sha_file "$path")"
  elif [[ -e "$path" ]]; then
    printf 'other'
  else
    printf 'absent'
  fi
}

write_declared_adaptation() {
  local root="$1"
  mkdir -p "$root/tools/schemas" || return 1
  {
    printf '# AAC dependency-mode eval adaptation soul\n'
    printf 'adaptation\tfixture-local\n'
  } > "$root/$ADAPTATION_SOUL"
}

write_store_souls() {
  local store="$1"
  mkdir -p "$store/tools/schemas" || return 1
  {
    printf '# store soul must not replace AAC instance soul\n'
    printf 'cycle_id\tstore-cycle\n'
    printf 'instance\tstore-kernel\n'
  } > "$store/$INSTANCE_SOUL"
  {
    printf '# store adaptation must not replace AAC declared adaptation soul\n'
    printf 'adaptation\tstore-kernel\n'
  } > "$store/$ADAPTATION_SOUL"
}

make_readonly_kernel_store() {
  local stage="$1" store="$2"
  manifest_store_fixture "$stage" "$store" || return "$?"
  write_store_souls "$store" || return "$?"
  chmod +x "$store/$SHIM_PATH" "$store/tools/kernel-shim.template.sh" 2>/dev/null || true
  readonly_store_fixture "$store"
}

write_manifest_paths() {
  local root="$1" out="$2" manifest kind path extra file rel
  manifest="$root/$MANIFEST_SELF_PATH"
  : > "$out"
  while IFS=$'\t' read -r kind path extra; do
    case "$kind" in
      ""|\#*) continue ;;
    esac
    [[ -n "${path:-}" && -z "${extra:-}" ]] || return 66
    case "$kind" in
      file)
        printf '%s\n' "$path" >> "$out"
        ;;
      dir)
        [[ -d "$root/$path" ]] || return 66
        while IFS= read -r file; do
          rel="${file#"$root/"}"
          printf '%s\n' "$rel" >> "$out"
        done < <(find "$root/$path" -type f | sort)
        ;;
      *) return 66 ;;
    esac
  done < "$manifest"
  printf '%s\n' "$MANIFEST_SELF_PATH" >> "$out"
  sort -u "$out" -o "$out"
}

assert_no_kernel_copies() {
  local root="$1" paths="$2" rel remaining=()
  while IFS= read -r rel; do
    [[ -n "$rel" ]] || continue
    is_soul_or_shim "$rel" && continue
    if [[ -e "$root/$rel" ]]; then
      remaining+=("$rel")
    fi
  done < "$paths"
  if [[ "${#remaining[@]}" -gt 0 ]]; then
    printf 'remaining kernel copies:\n' >&2
    printf '  %s\n' "${remaining[@]}" >&2
    return 1
  fi
}

check_receipt() {
  local root="$1" receipt removed shim_sha
  receipt="$root/MIGRATION-RECEIPT.md"
  [[ -f "$receipt" ]] || return 1
  grep -Fx 'MigrationReceipt:' "$receipt"
  grep -Fx '  schema: boat.migration.v0' "$receipt"
  grep -Fx '  law: premath.workspace-kernel-bundle.v0 (connection clause)' "$receipt"
  grep -Fx '  from: copy-mode' "$receipt"
  grep -Fx '  to: dependency-mode' "$receipt"
  grep -Fx "  kernel_rev_pinned: $LOOP_PIN" "$receipt"
  grep -Fx "  shim: $SHIM_PATH" "$receipt"
  grep -Fx "    - $INSTANCE_SOUL" "$receipt"
  grep -Fx "    - $ADAPTATION_SOUL" "$receipt"
  grep -Fx '  follow_up: loop-side bundle-base.tsv mode flip is a separate loop-side change' "$receipt"
  removed="$(awk -F': ' '$1 == "  removed" { print $2; exit }' "$receipt" | awk '{print $1}')"
  [[ "$removed" =~ ^[1-9][0-9]*$ ]]
  shim_sha="$(awk -F': ' '$1 == "  shim_sha256" { print $2; exit }' "$receipt")"
  [[ -n "$shim_sha" && "$shim_sha" == "$(sha_file "$root/$SHIM_PATH")" ]]
}

prepare_stage_and_store() {
  local stage="$1" store="$2"
  stage_root "$stage" || return "$?"
  write_declared_adaptation "$stage" || return "$?"
  make_readonly_kernel_store "$stage" "$store" || return "$?"
  readonly_store_fixture "$store"
}

t01_candidate_shape() {
  grep -Fx 'layer: evidence-tooling' "$CAND/DECLARATION"
  grep -Fx 'implements: premath.workspace-kernel-bundle.v0 (connection clause: aac dependency-mode base-change machinery)' "$CAND/DECLARATION"
  grep -Fx 'preserves: dm.identity, dm.transport.location, dm.profile.evidence, dm.commitment.attest, dm.refine.context' "$CAND/DECLARATION"
  grep -Fx 'compares_to: kcir.cand-0002-dependency-mode-pilot, loop.cand-0018-dependency-mode-support, loop.cand-0022-instance-root-override, loop.tools/kernel-shim.template.sh' "$CAND/DECLARATION"
  [[ "$(row_count "$CAND/LANDING")" -eq 3 ]]
  grep -Fx $'seeds/flake.nix\tflake.nix' "$CAND/LANDING"
  grep -Fx $'seeds/flake.lock\tflake.lock' "$CAND/LANDING"
  grep -Fx $'seeds/migrate-to-dependency.sh\tmigrate-to-dependency.sh' "$CAND/LANDING"
  bash -n "$CAND/seeds/migrate-to-dependency.sh"
  command -v nix-instantiate >/dev/null
  nix-instantiate --parse "$CAND/seeds/flake.nix" >/dev/null
  grep -Fx '    loop.url = "git+file:///Users/arj/irai/loop";' "$CAND/seeds/flake.nix"
  grep -Fx '      loop,' "$CAND/seeds/flake.nix"
  grep -Fx '            kernelStore = loop.packages.${system}.kernelExport;' "$CAND/seeds/flake.nix"
  grep_prose 'This candidate does not run the migration' "$CAND/README.md"
  grep_prose 'bash migrate-to-dependency.sh' "$CAND/README.md"
  grep_prose 'kernel_store="$(awk -F' "$CAND/README.md"
  grep_prose 'bash "$kernel_store/tools/lock-bump.sh" . --dry-run' "$CAND/README.md"
  grep_prose 'bash tools/loop status cand-0101-dependency-mode-migration' "$CAND/README.md"
}

t02_lock_pin_shape() {
  python3 - "$CAND/seeds/flake.lock" "$LOOP_PIN" "$LOOP_NAR" <<'PYEOF'
import json
import sys

path, rev, nar = sys.argv[1:4]
with open(path, encoding="utf-8") as fh:
    data = json.load(fh)
loop = data["nodes"]["loop"]
assert loop["locked"]["rev"] == rev
assert loop["locked"]["narHash"] == nar
assert loop["locked"]["url"] == "file:///Users/arj/irai/loop"
assert loop["original"]["url"] == "file:///Users/arj/irai/loop"
assert data["nodes"]["root"]["inputs"]["loop"] == "loop"
for key in [
    "boat",
    "nixpkgs",
    "flake-utils",
    "paintgun",
    "noir-src",
    "co-snarks-src",
    "bignum-paramgen-src",
    "crane",
    "rust-overlay",
    "provekit-src",
]:
    assert key in data["nodes"]["root"]["inputs"], key
PYEOF
  git -C "$LOOP_ROOT" merge-base --is-ancestor "$LOOP_PIN" HEAD
}

t03_migration_removes_kernel_and_preserves_souls() {
  local stage="$work/t03-stage" store="$work/t03-store" paths="$work/t03-paths.tsv"
  local before_instance before_adaptation after_instance after_adaptation
  prepare_stage_and_store "$stage" "$store" || return "$?"
  write_manifest_paths "$stage" "$paths" || return "$?"

  before_instance="$(path_state "$stage/$INSTANCE_SOUL")"
  before_adaptation="$(path_state "$stage/$ADAPTATION_SOUL")"
  (
    cd "$stage" || exit 1
    BOAT_KERNEL_STORE="$store" bash migrate-to-dependency.sh
  ) > "$TRACES/t03_migration.out" 2>&1

  after_instance="$(path_state "$stage/$INSTANCE_SOUL")"
  after_adaptation="$(path_state "$stage/$ADAPTATION_SOUL")"
  [[ "$before_instance" == "$after_instance" ]]
  [[ "$before_adaptation" == "$after_adaptation" ]]
  assert_no_kernel_copies "$stage" "$paths"
  check_receipt "$stage"
  grep -F 'export BOAT_INSTANCE_ROOT="$repo_root"' "$stage/$SHIM_PATH"
  [[ ! -e "$stage/tools/kernel-shim.template.sh" ]]
  [[ ! -e "$ROOT/MIGRATION-RECEIPT.md" ]]

  (
    cd "$stage" || exit 1
    BOAT_KERNEL_STORE="$store" bash migrate-to-dependency.sh
  ) > "$TRACES/t03_idempotent.out" 2>&1
  grep -F 'already dependency-mode; no-op' "$TRACES/t03_idempotent.out"
}

t04_shim_uses_scratch_instance_root() {
  local stage="$work/t04-stage" store="$work/t04-store" paths="$work/t04-paths.tsv"
  local id="cand-synth-root-override" cand
  prepare_stage_and_store "$stage" "$store" || return "$?"
  write_manifest_paths "$stage" "$paths" || return "$?"
  (
    cd "$stage" || exit 1
    BOAT_KERNEL_STORE="$store" bash migrate-to-dependency.sh
  ) > "$TRACES/t04_migration.out" 2>&1
  assert_no_kernel_copies "$stage" "$paths"

  cand="$(make_synth "$stage" "$id" open "dependency-mode root override probe")"
  env -u BOAT_INSTANCE_ROOT BOAT_KERNEL_STORE="$store" \
    bash "$stage/$SHIM_PATH" status > "$TRACES/t04_status.out" 2>&1
  grep -Fx $'cand-synth-root-override\topen\tdependency-mode root override probe' "$TRACES/t04_status.out"
  env -u BOAT_INSTANCE_ROOT BOAT_KERNEL_STORE="$store" \
    bash "$stage/$SHIM_PATH" validate "$id" > "$TRACES/t04_validate.out" 2>&1
  grep -Fx "loop: $id -> validated" "$TRACES/t04_validate.out"
  grep -Fx 'status: validated' "$cand/META"
  [[ -f "$cand/VALIDATE.json" ]]
  [[ ! -e "$store/candidates/$id" ]]
}

undeclared_divergence_command() {
  local stage="$work/mutant-divergence-stage" store="$work/mutant-divergence-store"
  prepare_stage_and_store "$stage" "$store" || return "$?"
  chmod u+w "$stage/WORKER.md" 2>/dev/null || true
  printf '\nundeclared divergence\n' >> "$stage/WORKER.md"
  (
    cd "$stage" || exit 1
    BOAT_KERNEL_STORE="$store" bash migrate-to-dependency.sh
  )
}

t06_undeclared_divergence_message() {
  grep -F 'kernel store digest mismatch: WORKER.md' "$TRACES/t05_undeclared_divergence_refused.out"
  grep -F 'migrate-to-dependency: BOAT_KERNEL_STORE does not match the local manifest set' "$TRACES/t05_undeclared_divergence_refused.out"
  [[ ! -f "$work/mutant-divergence-stage/MIGRATION-RECEIPT.md" ]]
}

corrupted_manifest_command() {
  local stage="$work/mutant-manifest-stage" store="$work/mutant-manifest-store"
  prepare_stage_and_store "$stage" "$store" || return "$?"
  printf 'bogus\tmanifest\trow\n' >> "$stage/$MANIFEST_SELF_PATH"
  (
    cd "$stage" || exit 1
    BOAT_KERNEL_STORE="$store" bash migrate-to-dependency.sh
  )
}

t08_corrupted_manifest_message() {
  grep -F 'malformed manifest row: bogus	manifest	row' "$TRACES/t07_corrupted_manifest_refused.out"
  grep -F 'migrate-to-dependency: BOAT_KERNEL_STORE does not match the local manifest set' "$TRACES/t07_corrupted_manifest_refused.out"
  [[ ! -f "$work/mutant-manifest-stage/MIGRATION-RECEIPT.md" ]]
}

run_probe \
  t01_candidate_shape \
  "candidate declaration, landing map, flake seed, migration script syntax, and POST-LAND commands are formed" \
  "candidate shape or post-land command checks failed" \
  t01_candidate_shape

run_probe \
  t02_lock_pin_shape \
  "flake.lock seed adds only a loop root input edge with a local Loop pin that is an ancestor of Loop HEAD" \
  "loop lock pin shape or ancestry check failed" \
  t02_lock_pin_shape

run_probe \
  t03_migration_removes_kernel_and_preserves_souls \
  "scratch migration uses a read-only manifest-derived kernel store, removes non-carveout kernel copies, preserves instance/adaptation souls, writes a receipt, and no-ops on rerun" \
  "scratch migration removal, soul preservation, receipt, or idempotency failed" \
  t03_migration_removes_kernel_and_preserves_souls

run_probe \
  t04_shim_uses_scratch_instance_root \
  "post-migration shim exports BOAT_INSTANCE_ROOT so store-kernel status and validate read/write the scratch instance, not the read-only store" \
  "dependency-mode shim pipeline did not use the scratch instance root" \
  t04_shim_uses_scratch_instance_root

run_failing_probe \
  t05_undeclared_divergence_refused \
  "mutant undeclared kernel-file divergence is refused before receipt creation" \
  "mutant undeclared kernel-file divergence unexpectedly migrated" \
  undeclared_divergence_command

run_probe \
  t06_undeclared_divergence_message \
  "undeclared divergence refusal emits the manifest digest mismatch boundary and leaves no receipt" \
  "undeclared divergence refusal message or no-receipt check failed" \
  t06_undeclared_divergence_message

run_failing_probe \
  t07_corrupted_manifest_refused \
  "mutant corrupted manifest row is refused before receipt creation" \
  "mutant corrupted manifest unexpectedly migrated" \
  corrupted_manifest_command

run_probe \
  t08_corrupted_manifest_message \
  "corrupted manifest refusal emits the malformed-row boundary and leaves no receipt" \
  "corrupted manifest refusal message or no-receipt check failed" \
  t08_corrupted_manifest_message

attest_tail "cand-0101 AAC dependency-mode migration machinery"
