#!/usr/bin/env bash
set -u

# Evidence attestation (verifier-set member).
#
# Usage:
#   attest.sh write SCORES_JSON HARNESS_PATH TRACES_DIR
#   attest.sh verify SCORES_JSON CAND_DIR ROOT
#
# write: appends a provenance block binding the scores body, the trace files,
# and the harness that produced them into one hash chain.
# verify: recomputes the chain from disk; exit 0 iff everything matches.
#
# Threat model (honest): this defeats fabrication-without-work (a hand-written
# verdict has no consistent traces/attestation) and drift (scores older or
# newer than their traces). It does NOT defeat a forger who recomputes the
# chain over fabricated traces; that requires an operator-held key (open
# queue item, pralaya tier).

sha_file() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    sha256sum "$1" | awk '{print $1}'
  fi
}

sha_stdin() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 | awk '{print $1}'
  else
    sha256sum | awk '{print $1}'
  fi
}

hash_traces() {
  local dir="$1"
  local f
  while IFS= read -r f; do
    printf '%s %s\n' "$(basename "$f")" "$(sha_file "$f")"
  done < <(find "$dir" -maxdepth 1 -type f | sort) | sha_stdin
}

MARKER='  ,"provenance": {'

case "${1:-}" in

write)
  scores="${2:-}"; harness="${3:-}"; traces="${4:-}"
  [[ -f "$scores" && -f "$harness" && -d "$traces" ]] \
    || { printf 'attest: write needs SCORES HARNESS TRACES_DIR\n' >&2; exit 64; }
  if grep -Fq "$MARKER" "$scores"; then
    printf 'attest: %s already has a provenance block\n' "$scores" >&2
    exit 65
  fi
  [[ "$(tail -n 1 "$scores")" == "}" ]] \
    || { printf 'attest: %s does not end with a bare }\n' "$scores" >&2; exit 65; }

  body_sha="$(sha_file "$scores")"
  harness_sha="$(sha_file "$harness")"
  traces_sha="$(hash_traces "$traces")"
  attestation="$(printf '%s%s%s' "$body_sha" "$traces_sha" "$harness_sha" | sha_stdin)"

  tmp="$scores.attest.tmp"
  {
    # all lines but the last (strip the bare closing }). sed '$d' is portable
    # across BSD and GNU; `head -n -1` is a GNU-only idiom that errors on BSD
    # head (macOS), emitting nothing and silently dropping the scores body —
    # which corrupts every attestation on a stock-macOS instance (cand-0057).
    sed '$d' "$scores"
    printf '%s\n' "$MARKER"
    printf '    "harness": "%s",\n' "$(basename "$harness")"
    printf '    "harness_sha256": "%s",\n' "$harness_sha"
    printf '    "traces_sha256": "%s",\n' "$traces_sha"
    printf '    "body_sha256": "%s",\n' "$body_sha"
    printf '    "attestation": "%s"\n' "$attestation"
    printf '  }\n'
    printf '}\n'
  } > "$tmp" && mv "$tmp" "$scores"
  printf 'attest: wrote provenance (%s)\n' "${attestation:0:12}"
  ;;

verify)
  scores="${2:-}"; cand_dir="${3:-}"; root="${4:-}"
  [[ -f "$scores" && -d "$cand_dir" ]] \
    || { printf 'attest: verify needs SCORES CAND_DIR ROOT\n' >&2; exit 64; }
  grep -Fq "$MARKER" "$scores" \
    || { printf 'attest: no provenance block in %s\n' "$scores" >&2; exit 3; }

  get() { sed -n 's/^    "'"$1"'": "\([^"]*\)".*/\1/p' "$scores" | head -n 1; }
  harness_name="$(get harness)"
  stored_harness_sha="$(get harness_sha256)"
  stored_traces_sha="$(get traces_sha256)"
  stored_body_sha="$(get body_sha256)"
  stored_attestation="$(get attestation)"

  # Reconstruct the pre-attestation body byte-exactly.
  body="$(awk -v m="$MARKER" '$0 == m { exit } { print }' "$scores"; printf '}')"
  body_sha="$(printf '%s\n' "$body" | sha_stdin)"

  # The harness must exist in the live verifier set (or the candidate dir,
  # for bespoke eval-self harnesses) and hash to the stored value.
  harness_path=""
  for p in "$root/tools/eval/$harness_name" "$cand_dir/$harness_name" "$root/tools/$harness_name"; do
    [[ -f "$p" ]] && { harness_path="$p"; break; }
  done

  fail=0
  [[ -n "$harness_path" ]] || { printf 'attest: harness not found: %s\n' "$harness_name" >&2; fail=1; }
  [[ "$body_sha" == "$stored_body_sha" ]] \
    || { printf 'attest: body hash mismatch (scores edited after attestation)\n' >&2; fail=1; }
  if [[ -n "$harness_path" ]]; then
    [[ "$(sha_file "$harness_path")" == "$stored_harness_sha" ]] \
      || { printf 'attest: harness hash mismatch (harness changed since run)\n' >&2; fail=1; }
  fi
  [[ "$(hash_traces "$cand_dir/traces")" == "$stored_traces_sha" ]] \
    || { printf 'attest: traces hash mismatch (traces edited or missing)\n' >&2; fail=1; }
  recomputed="$(printf '%s%s%s' "$stored_body_sha" "$stored_traces_sha" "$stored_harness_sha" | sha_stdin)"
  [[ "$recomputed" == "$stored_attestation" ]] \
    || { printf 'attest: attestation chain mismatch\n' >&2; fail=1; }

  if [[ "$fail" -eq 0 ]]; then
    printf 'attest: verified (%s)\n' "${stored_attestation:0:12}"
    exit 0
  fi
  exit 1
  ;;

*)
  printf 'usage: attest.sh write SCORES HARNESS TRACES_DIR | attest.sh verify SCORES CAND_DIR ROOT\n' >&2
  exit 64
  ;;
esac
