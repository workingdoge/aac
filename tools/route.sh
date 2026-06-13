#!/usr/bin/env bash
set -u

# Routing model #1 (eval.routing-model.v0, ROUTE-1.3/1.4; worker-contexts
# v0 CTX-1.2/1.3). Beta-Thompson sampling over the dispatch ledger, with
# forced exploration of under-sampled workers.
#
# Context cells (CTX-1.3): with --context C, admissible evidence is rows
# whose context lies in the pushforward closure of C — contexts whose
# coarsening chain (nix/contexts/base.tsv) reaches C, including C itself.
# Evidence moves finer -> coarser only; sibling contexts never share rows.
# Legacy rows (7 columns, pre-context) carry evidence only at the terminal
# context `any`. Without --context, all rows count (the terminal collapse:
# featureless marginal of ROUTE-1.x).
#
# Usage:
#   route.sh pick  [--context C]   -> prints chosen worker id
#   route.sh stats [--context C]   -> per-worker table
#
# Ledger: candidates/.dispatch/ROUTING.tsv
#   ts worker outcome(landed|escalated|no-binary) attempts budget wall_secs goal [context section]

TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$TOOLS_DIR/.." && pwd)"
LEDGER="$ROOT/candidates/.dispatch/ROUTING.tsv"
BASE_TSV="$ROOT/nix/contexts/base.tsv"
WORKERS="${BOAT_ROUTE_WORKERS:-claude codex}"

CMD="${1:-}"
[[ "$#" -gt 0 ]] && shift
CTX=""
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --context) CTX="${2:-}"; shift 2 ;;
    *) printf 'route.sh: unknown flag: %s\n' "$1" >&2; exit 64 ;;
  esac
done

# closure C -> newline-separated contexts admissible for C (CTX-1.3:
# every context whose coarsening chain reaches C, including C). Fails
# closed on an unknown context or a missing base.
closure() {
  local target="$1"
  [[ -f "$BASE_TSV" ]] || { printf 'route.sh: admitted base missing: %s\n' "$BASE_TSV" >&2; return 1; }
  awk -F'\t' -v t="$target" '
    !/^#/ && NF >= 2 { up[$1] = $2; all[$1] = 1 }
    END {
      if (!(t in all)) exit 1
      for (c in all) {
        x = c; fuel = 100
        while (x != "-" && fuel-- > 0) {
          if (x == t) { print c; break }
          x = (x in up) ? up[x] : "-"
        }
      }
    }' "$BASE_TSV"
}

ADMIT=""
if [[ -n "$CTX" ]]; then
  ADMIT="$(closure "$CTX")" \
    || { printf 'route.sh: unknown context: %s (CTX-1.1: admitted base only)\n' "$CTX" >&2; exit 65; }
fi

counts() {
  # counts WORKER -> "n s" (no-binary rows excluded: environment, not
  # model, evidence). Context filter per CTX-1.3 when CTX is set.
  local w="$1"
  awk -F'\t' -v w="$w" -v admit="$ADMIT" -v ctx="$CTX" '
    BEGIN { na = split(admit, a, "\n"); for (i = 1; i <= na; i++) if (a[i] != "") ok[a[i]] = 1 }
    /^#/ { next }
    $2 == w && $3 != "no-binary" {
      if (ctx != "") {
        if (NF >= 8 && $8 != "") { if (!($8 in ok)) next }
        else if (ctx != "any") next
      }
      n++; if ($3 == "landed") s++
    }
    END { printf "%d %d", n + 0, s + 0 }
  ' "$LEDGER" 2>/dev/null
}

case "$CMD" in

pick)
  # Forced exploration (ROUTE-1.3): any worker with n <= max_n/2 (and at
  # least 2 fewer observations) is picked first, least-sampled wins.
  declare -A N S
  max_n=0
  for w in $WORKERS; do
    read -r n s <<< "$(counts "$w")"
    N[$w]=$n; S[$w]=$s
    [[ "$n" -gt "$max_n" ]] && max_n=$n
  done

  explore=""
  for w in $WORKERS; do
    if [[ "${N[$w]}" -le $((max_n / 2)) && $((max_n - N[$w])) -ge 2 ]]; then
      if [[ -z "$explore" || "${N[$w]}" -lt "${N[$explore]}" ]]; then explore="$w"; fi
    fi
  done
  if [[ -n "$explore" ]]; then
    printf '%s\n' "$explore"
    exit 0
  fi

  # Thompson: sample Beta(s+1, n-s+1) per worker, pick the max.
  best=""; best_score=""
  for w in $WORKERS; do
    score="$(python3 -c "import random,sys; print(random.betavariate(${S[$w]}+1, ${N[$w]}-${S[$w]}+1))")"
    if [[ -z "$best" ]] || python3 -c "import sys; sys.exit(0 if $score > $best_score else 1)"; then
      best="$w"; best_score="$score"
    fi
  done
  printf '%s\n' "$best"
  ;;

stats)
  [[ -n "$CTX" ]] && printf 'context: %s (admissible: %s)\n' "$CTX" "$(tr '\n' ' ' <<< "$ADMIT")"
  printf '%-10s %6s %6s %8s %10s\n' worker n landed rate avg_wall_s
  for w in $WORKERS; do
    read -r n s <<< "$(counts "$w")"
    if [[ "$n" -gt 0 ]]; then
      rate="$(python3 -c "print(f'{$s/$n:.2f}')")"
      avg="$(awk -F'\t' -v w="$w" '$2==w && $3!="no-binary" {t+=$6; c++} END {if(c) printf "%.0f", t/c; else printf "-"}' "$LEDGER" 2>/dev/null)"
    else
      rate="-"; avg="-"
    fi
    printf '%-10s %6s %6s %8s %10s\n' "$w" "$n" "$s" "$rate" "$avg"
  done
  ;;

*)
  printf 'usage: route.sh pick [--context C] | stats [--context C]\n' >&2
  exit 64
  ;;
esac
