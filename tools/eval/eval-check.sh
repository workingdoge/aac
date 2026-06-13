#!/usr/bin/env bash
set -u

# Reviewer-safe evidence reproduction (verifier-set member; cand-0025,
# from the cand-0023 review finding: reviewers re-running eval-self.sh
# clobber attested evidence).
#
# Usage:
#   eval-check.sh CAND_DIR ROOT
#
# Re-runs a candidate's evaluator WITHOUT destroying its attested
# evidence: verifies the existing attestation, snapshots scores.json and
# traces/, runs eval-self.sh in place, captures the fresh verdict,
# restores the snapshot byte-exact, and re-verifies the attestation.
#
# Exit codes:
#   0  — pre-run attestation verified, fresh run verdict is exactly
#        "pass", attested verdict is exactly "pass", post-restore
#        attestation verified (evidence reproduced AND intact)
#   1  — fresh run did not reproduce a pass (evidence restored intact)
#   64 — usage
#   65 — candidate is missing scores.json / eval-self.sh / traces
#   66 — pre-run attestation does not verify (refusing to run: there is
#        no attested evidence to protect a reproduction of)
#   67 — restore self-check failed (should not happen: restore is a
#        byte-exact copy; investigate before trusting the store)
#
# Boundary (honest): protects scores.json and traces/ only. A harness
# that writes other candidate files (e.g. scores.archived.*) re-runs
# those effects for real; a harness that writes outside its candidate
# dir is a review finding on that candidate, not this tool's scope.

die() { printf 'eval-check: %s\n' "$2" >&2; exit "$1"; }

cand="${1:-}"; root="${2:-}"
[[ -n "$cand" && -n "$root" && -d "$cand" && -d "$root" ]] \
  || die 64 'usage: eval-check.sh CAND_DIR ROOT'
cand="$(cd "$cand" && pwd)"; root="$(cd "$root" && pwd)"

scores="$cand/scores.json"; harness="$cand/eval-self.sh"; traces="$cand/traces"
[[ -f "$scores" ]] || die 65 'no scores.json — nothing attested to protect; run eval-self.sh directly'
[[ -f "$harness" ]] || die 65 'no eval-self.sh in candidate dir'
[[ -d "$traces" ]] || die 65 'no traces/ in candidate dir'

# Same strict reader contract as tools/loop scores_verdict (duplicated
# here deliberately: this tool must stand alone for reviewers; drift
# between the two readers is itself evidence-suite-checkable).
verdict_of() {
  python3 -c '
import json,sys

def no_dupes(pairs):
    d = {}
    for k, v in pairs:
        if k in d:
            raise ValueError("duplicate key")
        d[k] = v
    return d

try:
    with open(sys.argv[1]) as f:
        d = json.load(f, object_pairs_hook=no_dupes)
except Exception:
    print("MALFORMED-JSON"); sys.exit(0)
v = d.get("verdict") if isinstance(d, dict) else None
if not isinstance(v, str):
    print("")
elif v == "pass":
    print("pass")
else:
    print(json.dumps(v))
' "$1" 2>/dev/null || printf 'MALFORMED-JSON\n'
}

bash "$root/tools/eval/attest.sh" verify "$scores" "$cand" "$root" \
  || die 66 'pre-run attestation does not verify; refusing (nothing trustworthy to reproduce)'
attested_verdict="$(verdict_of "$scores")"

snap="$(mktemp -d)"
cp "$scores" "$snap/scores.json"
cp -R "$traces" "$snap/traces"

printf 'eval-check: snapshot taken; re-running evaluator...\n'
run_rc=0
( cd "$root" && bash "$harness" ) > "$snap/run.out" 2>&1 || run_rc=$?
fresh_verdict='(scores.json missing after run)'
[[ -f "$scores" ]] && fresh_verdict="$(verdict_of "$scores")"

# Restore byte-exact, newest-last so a crash leaves the snapshot alive.
rm -rf "$traces"
cp -R "$snap/traces" "$traces"
cp "$snap/scores.json" "$scores"

bash "$root/tools/eval/attest.sh" verify "$scores" "$cand" "$root" \
  || { printf 'eval-check: snapshot retained at %s\n' "$snap" >&2
       die 67 'restore self-check FAILED: attestation no longer verifies after byte-exact restore'; }

printf 'eval-check: evidence restored byte-exact; attestation re-verified\n'
printf 'eval-check: attested verdict: %s\n' "$attested_verdict"
printf 'eval-check: fresh-run verdict: %s (harness rc=%s)\n' "$fresh_verdict" "$run_rc"
printf 'eval-check: fresh-run output tail:\n'
tail -n 10 "$snap/run.out" | sed 's/^/  | /'

if [[ "$run_rc" -eq 0 && "$fresh_verdict" == "pass" && "$attested_verdict" == "pass" ]]; then
  printf 'eval-check: REPRODUCED (pass attested, pass reproduced, evidence intact)\n'
  rm -rf "$snap"
  exit 0
fi
printf 'eval-check: NOT REPRODUCED — run output kept at %s\n' "$snap/run.out" >&2
exit 1
