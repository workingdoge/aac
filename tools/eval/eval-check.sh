#!/usr/bin/env bash
set -u

# Reviewer-safe evidence reproduction (verifier-set member; cand-0025,
# from the cand-0023 review finding: reviewers re-running eval-self.sh
# clobber attested evidence).
#
# Usage:
#   eval-check.sh CAND_DIR ROOT
#   EVAL_CHECK_REVIEWER_SAFE=1 eval-check.sh CAND_DIR ROOT
#
# Re-runs a candidate's evaluator WITHOUT destroying its attested
# evidence: verifies the existing attestation, snapshots scores.json and
# traces/, runs eval-self.sh in place, captures the fresh verdict,
# restores the snapshot byte-exact, and re-verifies the attestation.
#
# Reviewer-safe mode is opt-in with EVAL_CHECK_REVIEWER_SAFE=1. It exists for
# review sandboxes where Nix daemon isolation is intentional. It has no effect
# unless eval-self.sh declares this exact header marker line before the first
# non-comment body line:
#
#   # eval-requires: nix-daemon
#
# Marker grammar is intentionally narrow: one exact line, in the header, and no
# other "eval-requires" line. In reviewer-safe mode, malformed, duplicate, or
# non-header eval-requires lines are refused with an eval-requires marker
# violation (exit 70). Undeclared candidates in reviewer-safe mode are treated
# exactly like normal mode: no daemon probe and full reproduction.
#
# For a declared candidate in reviewer-safe mode, eval-check first verifies the
# existing attestation, then mechanically probes daemon reachability with
# "nix store ping" under a 5 second watchdog. If the probe succeeds, eval-check
# runs the existing full reproduction path, unsetting EVAL_CHECK_REVIEWER_SAFE
# for the child evaluator so the control knob does not become harness input; a
# failing eval remains a real NOT REPRODUCED failure. If the probe fails,
# eval-check does not run eval-self.sh. It verifies byte-integrity and
# attestation for scores.json and traces/, marks the rerun leg
# "not-run-with-reason" naming the declaration and failed daemon probe, and
# emits this distinct final verdict:
#
#   REVIEWER-SAFE NOT-RUN-WITH-REASON
#
# That verdict exits 0 only when the attested verdict is pass and evidence is
# intact. It is not, and must not be reported as, full REPRODUCED.
#
# Exit codes:
#   0  — pre-run attestation verified, fresh run verdict is exactly
#        "pass", attested verdict is exactly "pass", post-restore
#        attestation verified (evidence reproduced AND intact)
#        OR reviewer-safe declared nix-daemon exclusion: attested verdict is
#        "pass", daemon probe failed, rerun leg was not-run-with-reason,
#        and attested evidence remained byte-intact
#   1  — fresh run did not reproduce a pass (evidence restored intact)
#   64 — usage
#   65 — candidate is missing scores.json / eval-self.sh / traces
#   66 — pre-run attestation does not verify (refusing to run: there is
#        no attested evidence to protect a reproduction of)
#   67 — restore self-check failed (should not happen: restore is a
#        byte-exact copy; investigate before trusting the store)
#   68 — this candidate already has a live eval-check run; refused before
#        touching scores.json or traces/
#   69 — this candidate's eval-check lock is corrupt; refused instead of
#        guessing whether scores.json or traces/ are safe to touch
#   70 — reviewer-safe eval-requires marker violation
#
# Boundary (honest): protects scores.json and traces/ only. A harness
# that writes other candidate files (e.g. scores.archived.*) re-runs
# those effects for real; a harness that writes outside its candidate
# dir is a review finding on that candidate, not this tool's scope. The
# per-candidate lock directory is ephemeral coordination state outside
# the attested evidence surface.

die() { printf 'eval-check: %s\n' "$2" >&2; exit "$1"; }

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

evidence_digest() {
  local scores_file="$1" traces_dir="$2" f
  {
    printf 'scores.json %s\n' "$(sha_file "$scores_file")"
    while IFS= read -r f; do
      printf 'traces/%s %s\n' "$(basename "$f")" "$(sha_file "$f")"
    done < <(find "$traces_dir" -maxdepth 1 -type f | sort)
  } | sha_stdin
}

reviewer_safe_enabled() {
  [[ "${EVAL_CHECK_REVIEWER_SAFE:-}" == "1" ]]
}

parse_eval_requires_nix_daemon() {
  local file="$1" line nr=0 in_header=1 found=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    nr=$((nr + 1))
    if [[ "$in_header" -eq 1 ]]; then
      case "$line" in
        '#!'*) ;;
        ''|'#'*) ;;
        *) in_header=0 ;;
      esac
    fi
    case "$line" in
      *eval-requires*)
        [[ "$in_header" -eq 1 ]] \
          || die 70 "eval-requires marker violation at eval-self.sh:$nr (marker must be in the header as: # eval-requires: nix-daemon)"
        [[ "$line" == '# eval-requires: nix-daemon' ]] \
          || die 70 "eval-requires marker violation at eval-self.sh:$nr (expected exactly: # eval-requires: nix-daemon)"
        found=$((found + 1))
        ;;
    esac
  done < "$file"
  case "$found" in
    0) return 1 ;;
    1) return 0 ;;
    *) die 70 "eval-requires marker violation (duplicate declarations; expected exactly one marker line: # eval-requires: nix-daemon)" ;;
  esac
}

nix_daemon_probe() {
  local out="$1" pid watchdog timeout_marker rc
  if ! command -v nix >/dev/null 2>&1; then
    printf 'nix command not found in PATH\n' > "$out"
    return 127
  fi
  timeout_marker="$out.timeout"
  rm -f "$timeout_marker"
  nix store ping > "$out" 2>&1 &
  pid=$!
  (
    sleep 5
    if kill "$pid" 2>/dev/null; then
      printf 'timeout\n' > "$timeout_marker"
    fi
  ) &
  watchdog=$!
  wait "$pid"
  rc=$?
  kill "$watchdog" 2>/dev/null || true
  wait "$watchdog" 2>/dev/null || true
  if [[ -f "$timeout_marker" ]]; then
    rm -f "$timeout_marker"
    printf 'nix store ping timed out after 5s\n' >> "$out"
    return 124
  fi
  return "$rc"
}

probe_summary() {
  local out="$1" summary
  summary="$(sed -n '1,3p' "$out" | tr '\n' ' ' | sed 's/[[:space:]][[:space:]]*/ /g; s/^ //; s/ $//')"
  [[ -n "$summary" ]] || summary="no output"
  printf '%s' "$summary"
}

HELD_EVAL_LOCK=""
LOCK_PID_VALUE=""

now_epoch() {
  date +%s
}

pid_alive() {
  local pid="${1:-}"
  case "$pid" in
    ""|*[!0-9]*) return 1 ;;
  esac
  kill -0 "$pid" 2>/dev/null
}

mtime_epoch() {
  stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null || printf '0'
}

lock_created_epoch() {
  local lock="$1" created=""
  if [[ -f "$lock/created_at_epoch" ]]; then
    created="$(cat "$lock/created_at_epoch" 2>/dev/null || true)"
  fi
  if [[ "$created" =~ ^[0-9]+$ ]]; then
    printf '%s' "$created"
  else
    mtime_epoch "$lock"
  fi
}

lock_pid_or_die() {
  local lock="$1" pid_value=""
  [[ -d "$lock" ]] || die 69 "corrupt eval-check lock at $lock (not a directory); refusing"
  pid_value="$(cat "$lock/pid" 2>/dev/null || true)"
  case "$pid_value" in
    ""|*[!0-9]*) die 69 "corrupt eval-check lock at $lock (missing or invalid pid); refusing" ;;
  esac
  LOCK_PID_VALUE="$pid_value"
}

reclaim_dead_lock_or_report_live() {
  local lock="$1" pid created age owner_root
  [[ -e "$lock" ]] || return 0
  lock_pid_or_die "$lock"
  pid="$LOCK_PID_VALUE"
  if pid_alive "$pid"; then
    created="$(lock_created_epoch "$lock")"
    owner_root="$(cat "$lock/root" 2>/dev/null || true)"
    [[ -n "$owner_root" ]] || owner_root="unknown"
    die 68 "candidate lock held by live eval-check run pid=$pid root=$owner_root since=$created; refusing"
  fi
  created="$(lock_created_epoch "$lock")"
  age=$(($(now_epoch) - created))
  printf 'eval-check: reclaiming stale candidate lock %s (pid=%s dead, age=%ss)\n' \
    "$lock" "$pid" "$age" >&2
  rm -rf "$lock"
}

acquire_eval_lock() {
  local lock="$1" attempts=0 max_attempts=5
  while true; do
    if mkdir "$lock" 2>/dev/null; then
      printf '%s\n' "$$" > "$lock/pid"
      printf '%s\n' "$(now_epoch)" > "$lock/created_at_epoch"
      printf '%s\n' "$root" > "$lock/root"
      HELD_EVAL_LOCK="$lock"
      return 0
    fi
    attempts=$((attempts + 1))
    if [[ "$attempts" -ge "$max_attempts" ]]; then
      reclaim_dead_lock_or_report_live "$lock"
      continue
    fi
    sleep 0.1
  done
}

cleanup_eval_lock() {
  local lock="${HELD_EVAL_LOCK:-}"
  [[ -n "$lock" && -d "$lock" ]] || return 0
  if [[ "$(cat "$lock/pid" 2>/dev/null || true)" == "$$" ]]; then
    rm -rf "$lock"
  fi
}

trap cleanup_eval_lock EXIT
trap 'cleanup_eval_lock; exit 130' INT
trap 'cleanup_eval_lock; exit 143' TERM

cand="${1:-}"; root="${2:-}"
[[ -n "$cand" && -n "$root" && -d "$cand" && -d "$root" ]] \
  || die 64 'usage: eval-check.sh CAND_DIR ROOT'
cand="$(cd "$cand" && pwd)"; root="$(cd "$root" && pwd)"

eval_lock="$cand/.eval-check.lock.d"
acquire_eval_lock "$eval_lock"

scores="$cand/scores.json"; harness="$cand/eval-self.sh"; traces="$cand/traces"
[[ -f "$scores" ]] || die 65 'no scores.json — nothing attested to protect; run eval-self.sh directly'
[[ -f "$harness" ]] || die 65 'no eval-self.sh in candidate dir'
[[ -d "$traces" ]] || die 65 'no traces/ in candidate dir'

declares_nix_daemon=no
if reviewer_safe_enabled; then
  if parse_eval_requires_nix_daemon "$harness"; then
    declares_nix_daemon=yes
  fi
fi

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

if [[ "$declares_nix_daemon" == yes ]]; then
  integrity_before="$(evidence_digest "$scores" "$traces")"
  probe_out="$(mktemp)"
  probe_rc=0
  nix_daemon_probe "$probe_out"
  probe_rc=$?
  if [[ "$probe_rc" -ne 0 ]]; then
    integrity_after="$(evidence_digest "$scores" "$traces")"
    [[ "$integrity_before" == "$integrity_after" ]] \
      || die 67 'reviewer-safe exclusion integrity check FAILED: scores.json/traces changed without rerun'
    bash "$root/tools/eval/attest.sh" verify "$scores" "$cand" "$root" \
      || die 67 'reviewer-safe exclusion attestation re-verify FAILED'
    printf 'eval-check: reviewer-safe declaration: # eval-requires: nix-daemon\n'
    printf 'eval-check: nix-daemon probe failed: nix store ping rc=%s; %s\n' \
      "$probe_rc" "$(probe_summary "$probe_out")"
    printf 'eval-check: rerun leg: not-run-with-reason (declaration="# eval-requires: nix-daemon"; daemon_probe="nix store ping failed rc=%s")\n' \
      "$probe_rc"
    printf 'eval-check: attested verdict: %s\n' "$attested_verdict"
    printf 'eval-check: evidence byte-integrity: intact (%s)\n' "$integrity_after"
    rm -f "$probe_out"
    if [[ "$attested_verdict" == "pass" ]]; then
      printf 'eval-check: REVIEWER-SAFE NOT-RUN-WITH-REASON (pass attested, nix-daemon declared, daemon unreachable, evidence intact)\n'
      exit 0
    fi
    printf 'eval-check: NOT REPRODUCED — reviewer-safe exclusion cannot accept attested verdict %s\n' "$attested_verdict" >&2
    exit 1
  fi
  rm -f "$probe_out"
fi

snap="$(mktemp -d)"
cp "$scores" "$snap/scores.json"
cp -R "$traces" "$snap/traces"

printf 'eval-check: snapshot taken; re-running evaluator...\n'
run_rc=0
( cd "$root" && unset EVAL_CHECK_REVIEWER_SAFE && bash "$harness" ) > "$snap/run.out" 2>&1 || run_rc=$?
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
