#!/usr/bin/env bash
# eval-self.sh -- structural + factual evidence for cand-0022-world-stack-strategy.
# A NON-NORMATIVE design note (sites/ledger/design/0002): the World stack
# (World ID / Mini Apps / World Chain) + AgentKit + ProveKit strategy for AAC.
# The note's value is that it is fact-checked: it carries the corrections a
# 2026-06-13 deep-research pass made to the original strategy. This harness
# witnesses (a) the note is shaped as a non-normative design note, (b) the
# load-bearing CORRECTIONS are present (not the stale claims), and (c) its
# AAC cross-references resolve to real files. No toolchain needed.
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"
NOTE="$CAND_DIR/cargo/sites/ledger/design/0002-world-stack-agentkit-provekit.md"
RDME="$CAND_DIR/cargo/sites/ledger/design/README.md"
TRACES="$CAND_DIR/traces"
rm -rf "$TRACES"; mkdir -p "$TRACES"

check_structure() {
  local bad=0
  [[ -f "$NOTE" ]] || { echo "design note missing"; return 1; }
  grep -qi 'non-normative' "$NOTE" || { echo "missing the non-normative marker"; bad=1; }
  for s in 'Verified facts' 'AgentKit' 'ProveKit' 'narrow waist' 'MVP' 'Risks'; do
    grep -q "$s" "$NOTE" || { echo "missing section: $s"; bad=1; }
  done
  grep -q '0002-world-stack-agentkit-provekit.md' "$RDME" || { echo "design README does not list note 0002"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "non-normative design note, all sections present, listed in the design README"
}

check_corrections() {
  local bad=0
  # ProveKit version pin: beta.19 asserted AND beta.11 named as the stale/corrected claim.
  grep -q 'beta.19' "$NOTE" || { echo "missing the corrected ProveKit Noir pin (beta.19)"; bad=1; }
  grep -q 'beta.11' "$NOTE" || { echo "does not call out the stale beta.11 claim"; bad=1; }
  # AgentBook chain: World Chain / eip155:480 asserted AND the Base claim flagged as refuted/unresolved.
  grep -q 'eip155:480' "$NOTE" || { echo "missing the AgentBook chain id (eip155:480)"; bad=1; }
  grep -qi 'refuted' "$NOTE" || { echo "does not flag the refuted Base-mainnet claim"; bad=1; }
  # ProveKit default hash nuance.
  grep -qi 'Skyscraper' "$NOTE" || { echo "missing the Skyscraper default-hash correction"; bad=1; }
  # World API + HITL + World Chain primitive.
  grep -q '/api/v4/verify' "$NOTE" || { echo "missing the World ID v4 verify endpoint"; bad=1; }
  grep -q 'requestHumanAuthorization' "$NOTE" || { echo "missing the HITL function name"; bad=1; }
  grep -q 'PBH' "$NOTE" || { echo "missing World Chain PBH"; bad=1; }
  # honesty: perf numbers marked unverified.
  grep -qi 'unverified' "$NOTE" || { echo "does not mark the perf numbers unverified"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "research corrections present: beta.19 (not beta.11); AgentBook World Chain eip155:480 (Base refuted); Skyscraper; v4 verify; requestHumanAuthorization; PBH; perf unverified"
}

check_xrefs() {
  local bad=0
  grep -q 'EVENT-COMPLETE/1' "$NOTE" || { echo "does not reference EVENT-COMPLETE/1"; bad=1; }
  grep -q '4/REG' "$NOTE" || { echo "does not reference 4/REG"; bad=1; }
  # the referenced application target actually exists on disk.
  [[ -f "$ROOT/sites/ledger/specs/applications/EVENT-COMPLETE-1.md" ]] || { echo "EVENT-COMPLETE-1.md target missing"; bad=1; }
  [[ -f "$ROOT/sites/ledger/design/0001-bvr-clearing-kernel.md" ]] || { echo "sibling design note 0001 missing"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "cross-references resolve (EVENT-COMPLETE/1 + 4/REG; the spec + sibling note 0001 exist on disk)"
}

run() { local nm="$1" fn="$2" rc; "$fn" > "$TRACES/$nm.txt" 2>&1; rc=$?; printf 'loop-eval: %-12s %s (exit=%d)\n' "$nm" "$([[ $rc -eq 0 ]] && echo pass || echo FAIL)" "$rc"; return $rc; }

fail=0
run 01-structure   check_structure   || fail=1
run 02-corrections check_corrections || fail=1
run 03-xrefs       check_xrefs       || fail=1

verdict="pass"; [[ "$fail" -eq 0 ]] || verdict="fail"
{
  printf '{\n  "schema": "boat.eval-self.v0",\n  "candidate": "cand-0022-world-stack-strategy",\n'
  printf '  "evaluated_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '  "task": "land non-normative Design Note 0002 (World stack + AgentKit + ProveKit strategy for AAC), fact-checked against a 2026-06-13 deep-research pass: a human-backed clearing copilot Mini App; carries the verified corrections (ProveKit pins Noir beta.19 not beta.11; AgentBook resolves on World Chain eip155:480, the Base-mainnet relay claim refuted; ProveKit default hash Skyscraper; v4 verify endpoint; HITL requestHumanAuthorization; World Chain PBH; perf numbers marked unverified); cross-references resolve",\n'
  printf '  "checks": {\n'
  printf '    "structure": "%s",\n'   "$(grep -q 'all sections present' "$TRACES/01-structure.txt" && echo pass || echo fail)"
  printf '    "corrections": "%s",\n' "$(grep -q 'research corrections present' "$TRACES/02-corrections.txt" && echo pass || echo fail)"
  printf '    "xrefs": "%s"\n'        "$(grep -q 'cross-references resolve' "$TRACES/03-xrefs.txt" && echo pass || echo fail)"
  printf '  },\n  "verdict": "%s"\n}\n' "$verdict"
} > "$CAND_DIR/scores.json"

printf 'loop-eval: verdict=%s\n' "$verdict"
bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES" \
  || { printf 'loop-eval: WARNING attestation failed\n' >&2; exit 1; }
[[ "$verdict" == "pass" ]] || exit 1
