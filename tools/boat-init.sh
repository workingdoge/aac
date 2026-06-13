#!/usr/bin/env bash
set -u

# boat-init: export the governed loop to a new instance (boat.export.v0;
# the export course). Same mechanism, different soul: the kernel and
# discipline laws travel (per tools/schemas/export-manifest.tsv), the
# source instance's store, queue, cycles, theory program, and
# operator-held surfaces stay home. The init is discharge-determined
# like everything else: it finishes by running the loop-model
# differential INSIDE the target — the Beck–Chevalley-shaped check that
# transport preserved the judgment structure (LM-1.2/1.5) — and fails
# closed if the two models disagree there.
#
# usage: boat-init.sh TARGET --goal "FIRST QUEUE GOAL"
#                     [--instance NAME] [--cycle CYCLE_ID]
#
# Exit: 0 initialized + conformant; 64 usage; 65 target refused;
#       66 manifest/source missing; 1 conformance failed (tree kept for
#       inspection, receipt records the failure honestly).

TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="${BOAT_ROOT:-$(cd "$TOOLS_DIR/.." && pwd)}"
MANIFEST="${BOAT_EXPORT_MANIFEST:-$SRC/tools/schemas/export-manifest.tsv}"

die() { printf 'boat-init: %s\n' "$*" >&2; exit "${2:-1}"; }

target="${1:-}"
[[ -n "$target" && "$target" != --* ]] || die "usage: boat-init.sh TARGET --goal \"...\" [--instance NAME] [--cycle ID]" 64
shift
goal=""; instance=""; cycle=""
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --goal) goal="${2:-}"; shift 2 ;;
    --instance) instance="${2:-}"; shift 2 ;;
    --cycle) cycle="${2:-}"; shift 2 ;;
    *) die "unknown flag: $1" 64 ;;
  esac
done
[[ -n "$goal" ]] || die "a first goal is required (--goal): the instance's telos is the operator's to state, never inherited" 64
[[ -f "$MANIFEST" ]] || die "export manifest missing: $MANIFEST" 66

mkdir -p "$target" || die "cannot create target: $target" 65
target="$(cd "$target" && pwd)"
[[ "$target" != "$SRC" ]] || die "target is the source instance itself" 65
[[ ! -f "$target/tools/loop" ]] || die "target already carries a loop: $target (re-init refused; changes go through ITS candidates)" 65

instance="${instance:-$(basename "$target")}"
today="$(date -u +%Y-%m-%d)"
cycle="${cycle:-$instance-$today}"
case "$instance" in *[!a-zA-Z0-9._-]*) die "instance name must be [a-zA-Z0-9._-]: $instance" 64 ;; esac
case "$cycle" in *[!a-zA-Z0-9._-]*) die "cycle id must be [a-zA-Z0-9._-]: $cycle" 64 ;; esac

# --- materialize the travel set (manifest-driven, fail-closed) ---------------
copied=0
while IFS=$'\t' read -r kind path; do
  [[ -n "$kind" && "$kind" != \#* ]] || continue
  case "$kind" in
    file)
      [[ -f "$SRC/$path" ]] || die "manifest names a missing file: $path" 66
      mkdir -p "$target/$(dirname "$path")"
      cp "$SRC/$path" "$target/$path"
      copied=$((copied + 1))
      ;;
    dir)
      [[ -d "$SRC/$path" ]] || die "manifest names a missing dir: $path" 66
      mkdir -p "$target/$(dirname "$path")"
      cp -R "$SRC/$path" "$target/$path"
      copied=$((copied + 1))
      ;;
    *) die "manifest kind unknown: $kind (file|dir)" 66 ;;
  esac
done < "$MANIFEST"

# Self-hosting by construction: the kit always travels itself (the
# manifest cannot name these two before they land — chicken and egg —
# so the copy is structural, not data).
mkdir -p "$target/tools/schemas"
cp "${BASH_SOURCE[0]}" "$target/tools/boat-init.sh"
cp "$MANIFEST" "$target/tools/schemas/export-manifest.tsv"

# Source-mode normalization (cand-0049): a nix-store source copies in
# read-only (0444) — the instance must own its files (identity rewrite,
# VALIDATE.json, conformance scratches all write). User-write only;
# nothing wider than the source granted.
chmod -R u+w "$target"

# --- the new soul: instance identity, seeded queue, store ---------------------
{
  printf '# Instance identity registry (boat.instance.v0): the per-instance\n'
  printf '# soul binding, written by boat-init at export. RJ-1.6 compiled\n'
  printf '# artifact. Consumers: tools/loop, tools/boat-init.sh.\n'
  printf 'cycle_id\t%s\n' "$cycle"
  printf 'instance\t%s\n' "$instance"
} > "$target/tools/schemas/instance.tsv"

mkdir -p "$target/candidates"
{
  printf '# %s queue\n\n' "$instance"
  printf 'The obstruction/backlog queue for this instance. Workers consume the\n'
  printf 'top open entry (origin-allowlisted) via `bash tools/loop dispatch`.\n\n'
  printf '## Open\n\n'
  printf -- '- [open] (operator, %s) %s\n\n' "$today" "$goal"
  printf '## Resolved\n'
} > "$target/candidates/QUEUE.md"
{
  printf '# candidates\n\n'
  printf 'The candidate store for the %s instance. Every change is a\n' "$instance"
  printf 'candidate through `tools/loop`; WORKER.md at the root is the binding\n'
  printf 'proposer contract; acceptance is discharge-determined (BIDIR-4.4).\n'
} > "$target/candidates/README.md"

# --- conformance: the differential runs IN the target -------------------------
conformance="FAILED"
if ( cd "$target" && bash tools/loop-model-diff.sh --fixtures ) \
     > "$target/.boat-init-conformance.log" 2>&1; then
  conformance="green"
fi

src_commit="$(git -C "$SRC" rev-parse --short HEAD 2>/dev/null || printf 'unavailable(no-git)')"
{
  printf '# Export receipt: %s\n\n' "$instance"
  printf '```text\n'
  printf 'ExportReceipt:\n'
  printf '  exported_at: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '  source: %s (commit %s)\n' "$SRC" "$src_commit"
  printf '  instance: %s\n' "$instance"
  printf '  cycle_id: %s\n' "$cycle"
  printf '  selected_material: %s manifest entries (tools/schemas/export-manifest.tsv)\n' "$copied"
  printf '  left_behind: source store, queue, cycles, theory program, operator-held surfaces (incl. origin.sh per OB-1.3)\n'
  printf '  verification_boundary: tools/loop-model-diff.sh --fixtures, run inside this instance\n'
  printf '  conformance: %s\n' "$conformance"
  printf '  first_goal: %s\n' "$goal"
  printf '```\n'
} > "$target/EXPORT-RECEIPT.md"

if [[ "$conformance" != "green" ]]; then
  printf 'boat-init: CONFORMANCE FAILED — the transported loop and its model disagree\n' >&2
  printf 'boat-init: (log: %s; tree kept for inspection; receipt records the failure)\n' \
    "$target/.boat-init-conformance.log" >&2
  exit 1
fi

printf 'boat-init: %s initialized at %s (cycle %s; %s entries; conformance green)\n' \
  "$instance" "$target" "$cycle" "$copied"
if ! git -C "$target" rev-parse --git-dir >/dev/null 2>&1; then
  printf 'boat-init: NOTE: target is not a git repository — `loop land` snapshots\n'
  printf 'boat-init: and chain records degrade honestly without git; run: git -C %s init\n' "$target"
fi
printf 'boat-init: next: read WORKER.md, then bash tools/loop dispatch --agent NAME\n'
printf 'boat-init: (or open the first candidate yourself: bash tools/loop open cand-0001-... "...")\n'
exit 0
