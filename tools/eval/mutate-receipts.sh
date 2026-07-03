#!/usr/bin/env bash
set -u

# Negative-corpus generator (verifier-set member; candidates may not modify).
#
# Usage: mutate-receipts.sh OUT_DIR RECEIPT_MD [RECEIPT_MD...]
#
# For each input receipt, deterministically emits four labeled mutants:
#   drop-field    a required-ish field line is deleted
#   empty-field   a field's value is blanked
#   bad-enum      threshold_outcome set to an invalid token
#   wrong-header  the record header line is renamed
#
# Appends to OUT_DIR/labels.tsv:  <relative-path>\t<label>\t<mutation>
# Genuine inputs are NOT copied here; the caller records them in labels.tsv
# itself. Mutants of a valid receipt must be rejected by a sound checker.

if [[ "$#" -lt 2 ]]; then
  printf 'usage: %s OUT_DIR RECEIPT_MD [RECEIPT_MD...]\n' "$(basename "$0")" >&2
  exit 64
fi

OUT_DIR="$1"
shift
mkdir -p "$OUT_DIR"
LABELS="$OUT_DIR/labels.tsv"

# Fields whose removal/blanking should always be caught (present in every
# receipt type's schema).
DROP_FIELD="recorder"
EMPTY_FIELD="receipt_id"

# Emit a mutant only if the mutation actually changed the file; otherwise a
# byte-identical "mutant" would unfairly count against any sound checker.
# Mutants are staged in a temp file so no-ops never touch OUT_DIR.
STAGE="$(mktemp)"
trap 'rm -f "$STAGE"' EXIT

emit() {
  local src="$1"
  local out="$2"
  local mutation="$3"

  if cmp -s "$src" "$STAGE"; then
    return
  fi
  cp "$STAGE" "$OUT_DIR/$out"
  printf '%s\tmutant\t%s\n' "$out" "$mutation" >> "$LABELS"
}

for receipt in "$@"; do
  if [[ ! -f "$receipt" ]]; then
    printf 'mutate-receipts: missing input: %s\n' "$receipt" >&2
    exit 66
  fi
  base="$(basename "$receipt" .md)"

  out="$base.mut-drop-field.md"
  sed "/^[[:space:]]\{1,\}$DROP_FIELD:/d" "$receipt" > "$STAGE"
  emit "$receipt" "$out" drop-field

  out="$base.mut-empty-field.md"
  sed "s/^\([[:space:]]\{1,\}$EMPTY_FIELD:\).*/\1/" "$receipt" > "$STAGE"
  emit "$receipt" "$out" empty-field

  out="$base.mut-bad-enum.md"
  sed 's/^\([[:space:]]\{1,\}threshold_outcome:\).*/\1 not-a-valid-outcome/' \
    "$receipt" > "$STAGE"
  emit "$receipt" "$out" bad-enum

  out="$base.mut-wrong-header.md"
  sed 's/^\([A-Za-z]\{1,\}\)Receipt:/UnknownRecord:/' "$receipt" > "$STAGE"
  emit "$receipt" "$out" wrong-header
done

printf 'mutate-receipts: wrote mutants for %s receipt(s) to %s\n' "$#" "$OUT_DIR"
