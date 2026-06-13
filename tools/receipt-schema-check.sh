#!/usr/bin/env bash
set -u

# Generic receipt schema checker.
#
# Usage:
#   receipt-schema-check.sh RECEIPT_MD [RECEIPT_MD...]
#   receipt-schema-check.sh --schema SCHEMA_FILE RECEIPT_MD [RECEIPT_MD...]
#
# Without --schema, the schema is auto-detected by matching each schema's
# `header` directive against the receipt's record header line.
#
# Schema directives (one per line, # comments allowed):
#   header NAME              receipt must contain line ^NAME:
#   require KEY              field KEY must be present and non-empty
#   literal KEY VALUE...     field KEY must equal VALUE... exactly
#   enum KEY V1 V2...        field KEY must equal one of V1 V2...
#   enum_prefix KEY V1 V2... field KEY must start with one of V1 V2...
#
# Field *values* that depend on context (e.g. cycle_id, receipt_ref paths)
# are checked by the per-cycle tools, not here.
#
# Helpers come from tools/lib.sh (the cand-0001 condition was met
# 2026-06-10; the stale TODO discharged by cand-0045/STONE S6).

SCHEMA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/schemas"
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
failures=0

detect_schema() {
  local receipt="$1"
  local schema header

  for schema in "$SCHEMA_DIR"/*.schema; do
    header="$(awk '$1 == "header" { print $2; exit }' "$schema")"
    [[ -n "$header" ]] || continue
    if grep -q "^${header}:" "$receipt"; then
      printf '%s\n' "$schema"
      return 0
    fi
  done
  return 1
}

check_receipt() {
  local receipt="$1"
  local schema="$2"
  local base line directive key values value v matched
  base="$(basename "$receipt")"

  while IFS= read -r line; do
    line="${line%%#*}"
    [[ -n "${line//[[:space:]]/}" ]] || continue
    read -r directive key values <<< "$line"

    case "$directive" in
      header)
        if ! grep -q "^${key}:" "$receipt"; then
          error "$base missing ${key} header"
        fi
        ;;
      require)
        if [[ -z "$(field_value "$key" "$receipt")" ]]; then
          error "$base missing field: $key"
        fi
        ;;
      literal)
        value="$(field_value "$key" "$receipt")"
        if [[ "$value" != "$values" ]]; then
          error "$base field $key must be '$values', got: '$value'"
        fi
        ;;
      enum)
        value="$(field_value "$key" "$receipt")"
        matched=0
        for v in $values; do
          if [[ "$value" == "$v" ]]; then
            matched=1
            break
          fi
        done
        if [[ "$matched" -eq 0 ]]; then
          error "$base field $key has invalid value '$value' (allowed: $values)"
        fi
        ;;
      enum_prefix)
        value="$(field_value "$key" "$receipt")"
        matched=0
        for v in $values; do
          if [[ "$value" == "$v"* ]]; then
            matched=1
            break
          fi
        done
        if [[ "$matched" -eq 0 ]]; then
          error "$base field $key has invalid value '$value' (allowed prefixes: $values)"
        fi
        ;;
      *)
        error "$(basename "$schema") unknown schema directive: $directive"
        ;;
    esac
  done < "$schema"
}

usage() {
  printf 'usage: %s [--schema SCHEMA_FILE] RECEIPT_MD [RECEIPT_MD...]\n' \
    "$(basename "$0")" >&2
}

schema_override=""
if [[ "${1:-}" == "--schema" ]]; then
  schema_override="${2:-}"
  shift 2 || { usage; exit 64; }
fi

if [[ "$#" -lt 1 ]]; then
  usage
  exit 64
fi

for receipt in "$@"; do
  if [[ ! -f "$receipt" ]]; then
    error "receipt file missing: $receipt"
    continue
  fi

  if [[ -n "$schema_override" ]]; then
    schema="$schema_override"
  else
    if ! schema="$(detect_schema "$receipt")"; then
      error "$(basename "$receipt") matches no known schema header in $SCHEMA_DIR"
      continue
    fi
  fi

  if [[ ! -f "$schema" ]]; then
    error "schema file missing: $schema"
    continue
  fi

  check_receipt "$receipt" "$schema"
done

if [[ "$failures" -eq 0 ]]; then
  printf 'receipt-schema-check: ok\n'
  exit 0
fi

printf 'receipt-schema-check: failed with %s issue(s)\n' "$failures" >&2
exit 1
