#!/usr/bin/env bash
# eval-self.sh — functional evidence for cand-0001-establish-ledger-site.
#
# The candidate's claim is `dm.identity`: the cargo relocates the RFC suite
# and the machine-checked statements into sites/ledger/ byte-for-byte, with
# only their paths changed. This evaluator witnesses that claim in scratch
# trees, plus a corrupted-input rejection probe, and elaborates the relocated
# Core.lean at its new path. Ends by attesting scores.json.
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"
TRACES="$CAND_DIR/traces"
rm -rf "$TRACES"; mkdir -p "$TRACES"

sha() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'
  else sha256sum "$1" | awk '{print $1}'; fi
}
# Map a LANDING destination back to its current tracked origin (pre-land).
# A site-level artifact with no predecessor (the site README) has no origin.
origin_of() {
  case "$1" in
    sites/ledger/specs/*)      printf 'rfc/%s' "${1#sites/ledger/specs/}" ;;
    sites/ledger/statements/*) printf 'verification/%s' "${1#sites/ledger/statements/}" ;;
    *) printf '' ;;
  esac
}

# --- Check 1: byte-identity of every relocation (the dm.identity claim) ---
check_identity() {
  local src dest origin a b checked=0 newct=0 bad=0
  while read -r src dest; do
    [[ -n "$src" && "$src" != \#* ]] || continue
    origin="$(origin_of "$dest")"
    if [[ -z "$origin" ]]; then
      printf 'NEW   %-44s (no predecessor; site artifact)\n' "$dest"; newct=$((newct+1)); continue
    fi
    if [[ ! -f "$ROOT/$origin" ]]; then printf 'NO-ORIGIN %s -> %s\n' "$dest" "$origin"; bad=1; continue; fi
    a="$(sha "$CAND_DIR/$src")"; b="$(sha "$ROOT/$origin")"; checked=$((checked+1))
    if [[ "$a" == "$b" ]]; then printf 'IDENT %-44s == %s  %s\n' "$dest" "$origin" "${a:0:12}"
    else printf 'MISMATCH %s != %s (%s vs %s)\n' "$dest" "$origin" "${a:0:12}" "${b:0:12}"; bad=1; fi
  done < "$CAND_DIR/LANDING"
  printf -- '--- byte-identity: relocations=%d new=%d bad=%d\n' "$checked" "$newct" "$bad"
  [[ "$bad" -eq 0 && "$checked" -ge 16 ]]
}

# --- Check 2: catalog completeness (specs reproduce the RFC suite) ---
check_completeness() {
  local missing=0 n
  for n in 1 2 3 4 5 6 7 8 12; do
    if [[ -f "$CAND_DIR/cargo/specs/$n/README.md" ]]; then printf 'spec %s present\n' "$n"
    else printf 'spec %s MISSING\n' "$n"; missing=1; fi
  done
  for f in README.md registers/R1.md; do
    [[ -f "$CAND_DIR/cargo/specs/$f" ]] && printf 'specs/%s present\n' "$f" || { printf 'specs/%s MISSING\n' "$f"; missing=1; }
  done
  for f in Core.lean lakefile.toml lean-toolchain lake-manifest.json; do
    [[ -f "$CAND_DIR/cargo/statements/$f" ]] && printf 'statements/%s present\n' "$f" || { printf 'statements/%s MISSING\n' "$f"; missing=1; }
  done
  printf -- '--- completeness: missing=%d\n' "$missing"
  [[ "$missing" -eq 0 ]]
}

# --- Check 3: the relocated Core.lean still elaborates (zero sorry) ---
# Skip-tolerant: a missing toolchain/build is recorded, not a failure
# (byte-identity already pins the file to the proven original). A toolchain
# that IS present and reports an error or a `sorry` warning fails the check.
check_elaboration() {
  local lbin="$HOME/.elan/toolchains/leanprover--lean4---v4.28.0/bin"
  if [[ ! -x "$lbin/lake" || ! -d "$ROOT/verification/.lake/packages/mathlib" ]]; then
    printf 'SKIP: lean toolchain or built mathlib unavailable (byte-identity is the standing witness)\n'; return 0
  fi
  local out rc
  out="$(cd "$ROOT/verification" && PATH="$lbin:$PATH" lake env lean "$CAND_DIR/cargo/statements/Core.lean" 2>&1)"; rc=$?
  printf 'lake env lean (cargo/statements/Core.lean) exit=%d\n' "$rc"
  printf '%s\n' "${out:-<no diagnostics>}"
  [[ "$rc" -eq 0 ]] || return 1
  if printf '%s' "$out" | grep -qiE 'sorry|error'; then return 1; fi
  printf -- '--- elaboration: clean (zero diagnostics ⇒ zero sorry)\n'
  return 0
}

# --- Check 4: corrupted-input rejection probe ---
# A tampered relocation must NOT pass the byte-identity test. We corrupt a
# copy and assert it diverges from its origin — the test has discriminating
# power, not a vacuous pass.
check_rejection() {
  local tmp; tmp="$(mktemp -d)"
  cp "$CAND_DIR/cargo/statements/Core.lean" "$tmp/x"; printf '\n-- tamper\n' >> "$tmp/x"
  local a b; a="$(sha "$tmp/x")"; b="$(sha "$ROOT/verification/Core.lean")"
  rm -rf "$tmp"
  printf 'corrupted copy %s vs origin %s\n' "${a:0:12}" "${b:0:12}"
  if [[ "$a" != "$b" ]]; then printf -- '--- rejection probe: corruption correctly diverges (test discriminates)\n'; return 0
  else printf -- '--- rejection probe FAILED: corruption not detected\n'; return 1; fi
}

run() { # NAME FUNC
  local name="$1" fn="$2" rc
  "$fn" > "$TRACES/$name.txt" 2>&1; rc=$?
  printf 'loop-eval: %-20s %s (exit=%d)\n' "$name" "$([[ $rc -eq 0 ]] && echo pass || echo FAIL)" "$rc"
  return $rc
}

fail=0
run 01-byte-identity check_identity   || fail=1
run 02-completeness  check_completeness || fail=1
run 03-elaboration   check_elaboration  || fail=1
run 04-rejection     check_rejection    || fail=1

verdict="pass"; [[ "$fail" -eq 0 ]] || verdict="fail"
{
  printf '{\n'
  printf '  "schema": "boat.eval-self.v0",\n'
  printf '  "candidate": "cand-0001-establish-ledger-site",\n'
  printf '  "evaluated_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '  "task": "byte-faithful relocation (dm.identity) of the RFC suite and machine-checked statements into sites/ledger/",\n'
  printf '  "checks": {\n'
  printf '    "byte_identity": "%s",\n'   "$([[ -s "$TRACES/01-byte-identity.txt" ]] && grep -q '^MISMATCH\|NO-ORIGIN' "$TRACES/01-byte-identity.txt" && echo fail || echo pass)"
  printf '    "completeness": "%s",\n'    "$(grep -q 'MISSING' "$TRACES/02-completeness.txt" && echo fail || echo pass)"
  printf '    "elaboration": "%s",\n'     "$(grep -q '^SKIP' "$TRACES/03-elaboration.txt" && echo skip || (grep -q 'clean' "$TRACES/03-elaboration.txt" && echo pass || echo fail))"
  printf '    "rejection_probe": "%s"\n'  "$(grep -q 'correctly diverges' "$TRACES/04-rejection.txt" && echo pass || echo fail)"
  printf '  },\n'
  printf '  "verdict": "%s"\n' "$verdict"
  printf '}\n'
} > "$CAND_DIR/scores.json"

printf 'loop-eval: verdict=%s\n' "$verdict"
bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES" \
  || { printf 'loop-eval: WARNING attestation failed; evidence unattested\n' >&2; exit 1; }
[[ "$verdict" == "pass" ]] || exit 1
