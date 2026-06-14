#!/usr/bin/env bash
set -u

# kernel-app crate boundary checker (cand-0033).
#
# The law: a KERNEL circuit crate MUST NOT depend on or import an
# APPLICATION crate. The enshrined trust base is schema-agnostic;
# application schemas and their receipts build ON TOP of it, never the
# reverse (4/REG S5: the base registry MUST NOT require an application
# target; the recompute-vs-consume seam, cand-0030/0032). This checker
# is that doctrine's court at the crate level.
#
# KERNEL is the stable set {pacioli, hash, ledger, transition, nullify}
# -- the algebra leaves, the canonical `ledger` commitment seam, and the
# two enshrined binaries. Everything else in the circuits workspace is
# application (rulebook, receipt, event_complete, and any FUTURE schema
# or receipt lib) and is auto-covered: a kernel crate may reference only
# KERNEL crates plus std. Sound via the manifest alone -- Noir requires a
# Nargo.toml dependency to reference any crate -- so the `use` scan is
# defense-in-depth, not the primary guard.
#
# Read-only, grep-based textual conformance (L0), ROOT-relative; runs in
# any exported instance unmodified. Violations are minted as typed JSON
# (witnessId over {class, lawRef, tokenPath, context}), one per line on
# stdout; human summary on stderr. Exit: 0 clean; 1 violation(s); 66
# missing substrate.

ROOT="${BOAT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
CIRCUITS="${KBC_CIRCUITS:-$ROOT/circuits}"
WID="$ROOT/tools/eval/witness-id.sh"
PY="${BOAT_WITNESS_ID_PYTHON:-$(command -v python3 || true)}"

KERNEL="pacioli hash ledger transition nullify"
LAWREF="4/REG S5 (base MUST NOT require an application target)"
JUDGMENT="kernel-app crate boundary (cand-0033)"

[[ -d "$CIRCUITS" ]] || { printf 'kernel-boundary-check: no circuits dir at %s\n' "$CIRCUITS" >&2; exit 66; }

in_kernel() { local c="$1" k; for k in $KERNEL; do [[ "$k" == "$c" ]] && return 0; done; return 1; }

failures=0
refuse() { # TOKEN_PATH REASON
  local tok="$1" reason="$2" wid="null"
  if [[ -n "$PY" && -x "$PY" && -f "$WID" ]]; then
    local minted
    minted="$(printf '{"class":"kernel-app-boundary-violation","lawRef":"%s","tokenPath":"%s","context":null}' "$LAWREF" "$tok" | bash "$WID" 2>/dev/null)"
    [[ -n "$minted" ]] && wid="\"$minted\""
  fi
  printf '{"failed_judgment": "%s", "obstruction_class": "kernel-app-boundary-violation", "lawRef": "%s", "tokenPath": "%s", "reason": "%s", "witnessId": %s}\n' \
    "$JUDGMENT" "$LAWREF" "$tok" "$reason" "$wid"
  failures=$((failures + 1))
}

checked=0
for k in $KERNEL; do
  manifest="$CIRCUITS/$k/Nargo.toml"
  [[ -f "$manifest" ]] || continue
  checked=$((checked + 1))

  # (a) PRIMARY guard -- every path-dependency must RESOLVE to a kernel crate.
  # Key on the resolved path TARGET (basename), not the declaration alias, so an
  # aliased app crate -- `kernelname = { path = "../receipt" }` -- cannot evade
  # the rule: it is the target dir, not the key, that pulls a crate into scope.
  # Extraction is key-ORDER-INDEPENDENT: it pulls every `path = "..."` value
  # wherever it sits in the inline table (e.g. `app = { tag = "v1", path = ... }`),
  # over non-comment lines only.
  while IFS= read -r dpath; do
    [[ -n "$dpath" ]] || continue
    target="$(basename "$dpath")"
    in_kernel "$target" || refuse "$k.Nargo.toml.$target" \
      "kernel crate '$k' depends on non-kernel crate '$target' (path '$dpath')"
  done < <(grep -vE '^[[:space:]]*#' "$manifest" \
             | grep -oE 'path[[:space:]]*=[[:space:]]*"[^"]*"' \
             | sed -E 's/.*"([^"]*)".*/\1/')

  # (b) defense-in-depth -- every `use <crate>::` first segment must be kernel/std.
  for src in "$CIRCUITS/$k/src"/*.nr; do
    [[ -f "$src" ]] || continue
    while IFS= read -r cr; do
      [[ -n "$cr" && "$cr" != "std" && "$cr" != "crate" && "$cr" != "super" ]] || continue
      in_kernel "$cr" || refuse "$k.$(basename "$src").$cr" \
        "kernel crate '$k' imports non-kernel crate '$cr' (use ${cr}::...)"
    done < <(grep -oE '^[[:space:]]*use[[:space:]]+[a-zA-Z_][a-zA-Z0-9_]*' "$src" | awk '{ print $2 }' | sort -u)
  done
done

if [[ "$failures" -gt 0 ]]; then
  printf 'kernel-boundary-check: %s boundary violation(s) over %s kernel crate(s)\n' "$failures" "$checked" >&2
  exit 1
fi
printf 'kernel-boundary-check: ok (%s kernel crates depend only on kernel crates)\n' "$checked"
