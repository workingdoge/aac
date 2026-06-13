#!/usr/bin/env bash
# Shared checker functions for Boat root tools.
# Contract: the sourcing script defines a global `failures` counter (init 0)
# and may rely on `error` incrementing it.
# Candidate cand-0001-tools-lib — not live until admitted.

error() {
  printf 'ERROR: %s\n' "$*" >&2
  failures=$((failures + 1))
}

sha256() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    sha256sum "$1" | awk '{print $1}'
  fi
}

field_value() {
  local key="$1"
  local file="$2"

  awk -v key="$key" '
    $0 ~ "^[[:space:]]+" key ":" {
      sub("^[[:space:]]+" key ":[[:space:]]*", "")
      print
      exit
    }
  ' "$file"
}

require_file() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    error "missing file: $path"
  fi
}

require_field() {
  local key="$1"
  local file="$2"

  if [[ -z "$(field_value "$key" "$file")" ]]; then
    error "$(basename "$file") missing field: $key"
  fi
}

check_hash() {
  local path="$1"
  local expected="$2"
  local label="$3"
  local actual

  if [[ ! -f "$path" ]]; then
    error "$label missing: $path"
    return
  fi

  actual="$(sha256 "$path")"
  if [[ "$actual" != "$expected" ]]; then
    error "$label hash changed: expected $expected got $actual"
  fi
}

# --- Receipt checkers (reconciled strictest union, 2026-06-09) ---

check_import_receipt() {
  local file="$1"
  local cycle_id="$2"
  local base threshold shore ref cycle
  base="$(basename "$file")"

  if ! grep -q '^ImportReceipt:' "$file"; then
    error "$base missing ImportReceipt header"
  fi

  local fields=(
    receipt_id cycle_id cargo source selected_material left_behind owner
    authority_surface predicate predicate_absence_reason projection_surface
    verification_boundary shore_commitment threshold_outcome disposition
    recorder receipt_ref
  )
  local field
  for field in "${fields[@]}"; do
    require_field "$field" "$file"
  done

  cycle="$(field_value cycle_id "$file")"
  if [[ "$cycle" != "$cycle_id" ]]; then
    error "$base has unexpected cycle_id: $cycle"
  fi

  if [[ "$(field_value recorder "$file")" != "Tusk" ]]; then
    error "$base recorder must be Tusk"
  fi

  threshold="$(field_value threshold_outcome "$file")"
  case "$threshold" in
    admit|transform|split) ;;
    *) error "$base has invalid ImportReceipt threshold_outcome: $threshold" ;;
  esac

  if [[ "$(field_value predicate_absence_reason "$file")" != "none" ]]; then
    error "$base ImportReceipt predicate_absence_reason must be none"
  fi

  shore="$(field_value shore_commitment "$file")"
  case "$shore" in
    landed*|archived*|handed_off*|abandoned*|superseded*) ;;
    *) error "$base has invalid shore_commitment: $shore" ;;
  esac

  ref="$(field_value receipt_ref "$file")"
  if [[ "$ref" != "boat/imports/receipts/$base" ]]; then
    error "$base receipt_ref does not match file path: $ref"
  fi
}

check_obstruction_receipt() {
  local file="$1"
  local cycle_id="$2"
  local base threshold ref
  base="$(basename "$file")"

  if ! grep -q '^ObstructionReceipt:' "$file"; then
    error "$base missing ObstructionReceipt header"
  fi

  local fields=(
    receipt_id cycle_id proposed_cargo source missing_authority
    failed_predicate predicate_absence_reason threshold_outcome disposition
    return_conditions recorder receipt_ref
  )
  local field
  for field in "${fields[@]}"; do
    require_field "$field" "$file"
  done

  if [[ "$(field_value cycle_id "$file")" != "$cycle_id" ]]; then
    error "$base has unexpected cycle_id: $(field_value cycle_id "$file")"
  fi

  threshold="$(field_value threshold_outcome "$file")"
  case "$threshold" in
    split|escrow|defer|archive|reject) ;;
    *) error "$base has invalid ObstructionReceipt threshold_outcome: $threshold" ;;
  esac

  ref="$(field_value receipt_ref "$file")"
  if [[ "$ref" != "boat/imports/receipts/$base" ]]; then
    error "$base receipt_ref does not match file path: $ref"
  fi
}

check_genesis_closure() {
  local file="$1"
  local cycle_id="$2"
  local fields=(
    receipt_id cycle_id recorder authority_surface
    final_recording_channel_witness_ref founding_witness_chain_root_ref
    closure_handoff_witness_ref operating_regime_opened
  )
  local field

  if ! grep -q '^GenesisClosureReceipt:' "$file"; then
    error "Genesis Closure receipt missing GenesisClosureReceipt header"
  fi

  for field in "${fields[@]}"; do
    require_field "$field" "$file"
  done

  if [[ "$(field_value cycle_id "$file")" != "$cycle_id" ]]; then
    error "Genesis Closure receipt has unexpected cycle_id: $(field_value cycle_id "$file")"
  fi

  if [[ "$(field_value recorder "$file")" != "Tusk" ]]; then
    error "Genesis Closure receipt recorder must be Tusk"
  fi

  if [[ "$(field_value authority_surface "$file")" != "founding-witness-chain" ]]; then
    error "Genesis Closure receipt authority_surface must be founding-witness-chain"
  fi
}

check_dissolution_receipt() {
  local file="$1"
  local cycle_id="$2"
  local base
  base="$(basename "$file")"

  local fields=(
    receipt_id cycle_id cargo prior_admission_receipt_ref
    reachability_criterion lapse_evidence authority_surface predicate
    threshold_outcome recorder receipt_ref
  )
  local field
  for field in "${fields[@]}"; do
    require_field "$field" "$file"
  done

  if [[ "$(field_value cycle_id "$file")" != "$cycle_id" ]]; then
    error "$base has unexpected cycle_id"
  fi

  if [[ "$(field_value threshold_outcome "$file")" != "admit" ]]; then
    error "$base DissolutionReceipt threshold_outcome must be admit"
  fi

  case "$(field_value reachability_criterion "$file")" in
    compact-expiry|purpose-detachment|source-withdrawal|successor-replacement) ;;
    *) error "$base invalid reachability_criterion: $(field_value reachability_criterion "$file")" ;;
  esac
}
