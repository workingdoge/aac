#!/usr/bin/env bash
set -euo pipefail

# review-query: query Boat REVIEW.md files that carry the v0 typed
# ReviewJudgment wire block. This is an index surface only; it does not
# authorize admission, landing, rollback, or review independence.

die() { printf 'review-query: %s\n' "$1" >&2; exit 64; }

self="${BASH_SOURCE[0]}"

if [[ "${1:-}" == "--self-test" ]]; then
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/review-query.XXXXXX")" || exit 66
  cleanup() { rm -rf "$tmp"; }
  trap cleanup EXIT
  root="$tmp/root"
  mkdir -p "$root/candidates/cand-query-admit" \
           "$root/candidates/cand-query-transform" \
           "$root/candidates/cand-query-resolved" \
           "$root/candidates/cand-query-legacy" \
           "$root/candidates/cand-query-malformed"

  cat > "$root/candidates/cand-query-admit/REVIEW.md" <<'EOF'
```text
ReviewJudgment:
  candidate_id: cand-query-admit
  reviewed_at: 2026-06-18T00:00:00Z
  subject:
    brief_sha256: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
    landing_tier: verifier-set
    review_prompt_sha256: bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
  reviewer:
    independence_claim: fresh-session
    write_scope_claim: REVIEW.md-only
  evidence_audit:
    eval_check: reproduced
    witness_ref: tools/eval/eval-check.sh candidates/cand-query-admit .
  findings: none
  recommendation: admit
```
EOF
  cat > "$root/candidates/cand-query-transform/REVIEW.md" <<'EOF'
```text
ReviewJudgment:
  candidate_id: cand-query-transform
  reviewed_at: 2026-06-18T00:01:00Z
  subject:
    brief_sha256: cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
    landing_tier: verifier-set
    review_prompt_sha256: dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
  reviewer:
    independence_claim: fresh-session
    write_scope_claim: REVIEW.md-only
  evidence_audit:
    eval_check: reproduced
    witness_ref: tools/eval/eval-check.sh candidates/cand-query-transform .
  findings:
    - id: R1-F1
      class: correctness
      severity: transform
      status: open
      subject_ref: tools/example.sh
      problem: PREMATH-0002 BIDIR-4.4 would be bypassed by trusting prose
      required_change: use the typed review judgment instead
  recommendation: transform
```
EOF
  cat > "$root/candidates/cand-query-resolved/REVIEW.md" <<'EOF'
```text
ReviewJudgment:
  candidate_id: cand-query-resolved
  reviewed_at: 2026-06-18T00:02:00Z
  subject:
    brief_sha256: eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
    landing_tier: law-spine
    review_prompt_sha256: ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
  reviewer:
    independence_claim: fresh-session
    write_scope_claim: REVIEW.md-only
  evidence_audit:
    eval_check: failed
    witness_ref: traces/eval-check.err
  findings:
    - id: R1-F1
      class: evidence
      severity: transform
      status: resolved
      subject_ref: traces/eval-check.err
      problem: initial evidence rerun failed
      required_change: repair evaluator and rerun eval-check
  recommendation: needs-more-evidence
```
EOF
  printf 'ReviewNote only\n' > "$root/candidates/cand-query-legacy/REVIEW.md"
  cat > "$root/candidates/cand-query-malformed/REVIEW.md" <<'EOF'
```text
ReviewJudgment:
  candidate_id: cand-query-malformed
  reviewed_at: 2026-06-18T00:03:00Z
    bad_indent: true
```
EOF

  count_jsonl() {
    bash "$self" --root "$root" --jsonl "$@" | python3 -c 'import sys; print(sum(1 for _ in sys.stdin))'
  }
  [[ "$(count_jsonl --typed true)" == "4" ]] || die "self-test typed query count failed"
  [[ "$(count_jsonl --typed false)" == "1" ]] || die "self-test untyped query count failed"
  [[ "$(count_jsonl --recommendation admit)" == "1" ]] || die "self-test recommendation filter failed"
  [[ "$(count_jsonl --finding-class correctness --severity transform --status open)" == "1" ]] || die "self-test finding filters failed"
  [[ "$(count_jsonl --file tools/example.sh)" == "1" ]] || die "self-test file filter failed"
  [[ "$(count_jsonl --law-ref PREMATH-0002)" == "1" ]] || die "self-test law filter failed"
  [[ "$(count_jsonl --transform-outcome resolved)" == "1" ]] || die "self-test transform outcome filter failed"
  bash "$self" --root "$root" --summary > "$tmp/summary.out"
  grep -q '^reviews: 5$' "$tmp/summary.out" || die "self-test summary count failed"
  grep -q '^typed: 4$' "$tmp/summary.out" || die "self-test typed summary failed"
  grep -q '^malformed: 1$' "$tmp/summary.out" || die "self-test malformed summary failed"
  printf 'review-query: self-test ok\n'
  exit 0
fi

python3 - "$@" <<'PY'
import argparse
import json
import re
import sys
from collections import Counter
from pathlib import Path


def parse_args(argv):
    parser = argparse.ArgumentParser(
        prog="review-query.sh",
        description="Query Boat REVIEW.md ReviewJudgment records. Results are non-authoritative.",
    )
    parser.add_argument("root_arg", nargs="?", help="repo root (default: current directory)")
    parser.add_argument("--root", default=None, help="repo root")
    parser.add_argument("--jsonl", action="store_true", help="emit one JSON object per review")
    parser.add_argument("--summary", action="store_true", help="emit aggregate counts for matching reviews")
    parser.add_argument("--strict", action="store_true", help="exit nonzero if a typed block has parse errors")
    parser.add_argument("--candidate", help="exact candidate id")
    parser.add_argument("--recommendation", help="admit, transform, deny, or needs-more-evidence")
    parser.add_argument("--eval-check", help="evidence_audit.eval_check value")
    parser.add_argument("--finding-class", dest="finding_class", help="finding class value")
    parser.add_argument("--severity", help="finding severity value")
    parser.add_argument("--status", help="finding status value")
    parser.add_argument("--subject-ref", dest="subject_ref", help="substring match against finding subject_ref")
    parser.add_argument("--file", dest="file_ref", help="alias for --subject-ref, intended for path lookups")
    parser.add_argument("--law-ref", dest="law_ref", help="substring match against finding subject_ref/problem/required_change")
    parser.add_argument(
        "--transform-outcome",
        choices=["none", "open", "resolved", "queued", "superseded", "mixed"],
        help="computed outcome for severity=transform findings",
    )
    parser.add_argument("--typed", choices=["true", "false", "any"], default="any", help="filter typed block presence")
    return parser.parse_args(argv)


def relpath(path, root):
    try:
        return path.relative_to(root).as_posix()
    except ValueError:
        return str(path)


def find_blocks(text):
    blocks = []
    inside = False
    current = []
    for line in text.splitlines():
        if line.startswith("```"):
            if inside:
                blocks.append("\n".join(current))
                current = []
                inside = False
            else:
                inside = True
                current = []
        elif inside:
            current.append(line.rstrip())
    return [b for b in blocks if re.search(r"^ReviewJudgment:\s*$", b, re.M)]


def scalar(line, lineno, errors):
    if ":" not in line:
        errors.append(f"line {lineno}: expected key: value")
        return None, None
    key, value = line.split(":", 1)
    key = key.strip()
    value = value.strip()
    if not key:
        errors.append(f"line {lineno}: empty key")
    return key, value


def transform_outcome(findings):
    transforms = [f for f in findings if f.get("severity") == "transform"]
    if not transforms:
        return "none"
    statuses = {f.get("status") for f in transforms}
    if "open" in statuses:
        return "open"
    if statuses == {"resolved"}:
        return "resolved"
    if statuses == {"queued"}:
        return "queued"
    if statuses == {"superseded"}:
        return "superseded"
    return "mixed"


def parse_review(path, root):
    candidate_id = path.parent.name
    text = path.read_text(encoding="utf-8")
    blocks = find_blocks(text)
    record = {
        "candidate": candidate_id,
        "review_path": relpath(path, root),
        "typed": bool(blocks),
        "well_formed": len(blocks) == 1,
        "parse_errors": [],
        "reviewed_at": None,
        "subject": {},
        "reviewer": {},
        "evidence_audit": {},
        "findings": [],
        "recommendation": None,
        "transform_outcome": "unknown",
        "authority": "query-only",
    }
    if len(blocks) != 1:
        if len(blocks) > 1:
            record["parse_errors"].append(f"expected one ReviewJudgment block, found {len(blocks)}")
        return record

    section = None
    current_finding = None
    for lineno, raw in enumerate(blocks[0].splitlines(), 1):
        if not raw.strip() or raw.strip().startswith("#"):
            continue
        if raw == "ReviewJudgment:":
            continue
        if raw.startswith("  ") and not raw.startswith("    "):
            body = raw[2:]
            if body in ("subject:", "reviewer:", "evidence_audit:", "findings:"):
                section = body[:-1]
                continue
            key, value = scalar(body, lineno, record["parse_errors"])
            if key == "findings" and value == "none":
                section = None
                continue
            if key in ("candidate_id", "reviewed_at", "recommendation"):
                if key == "candidate_id":
                    record["candidate_id"] = value
                elif key == "reviewed_at":
                    record["reviewed_at"] = value
                else:
                    record["recommendation"] = value
                section = None
            elif key:
                record["parse_errors"].append(f"line {lineno}: unexpected top-level key {key}")
        elif raw.startswith("    ") and not raw.startswith("      "):
            body = raw[4:]
            if section in ("subject", "reviewer", "evidence_audit"):
                key, value = scalar(body, lineno, record["parse_errors"])
                if key:
                    record[section][key] = value
            elif section == "findings":
                if not body.startswith("- "):
                    record["parse_errors"].append(f"line {lineno}: expected finding list item")
                    continue
                current_finding = {}
                record["findings"].append(current_finding)
                key, value = scalar(body[2:], lineno, record["parse_errors"])
                if key:
                    current_finding[key] = value
            else:
                record["parse_errors"].append(f"line {lineno}: nested field without active section")
        elif raw.startswith("      "):
            body = raw[6:]
            if section != "findings" or current_finding is None:
                record["parse_errors"].append(f"line {lineno}: finding field without finding item")
                continue
            key, value = scalar(body, lineno, record["parse_errors"])
            if key:
                current_finding[key] = value
        else:
            record["parse_errors"].append(f"line {lineno}: unsupported indentation")

    if record.get("candidate_id") and record["candidate_id"] != candidate_id:
        record["parse_errors"].append(
            f"candidate_id mismatch: got {record['candidate_id']!r}, expected {candidate_id!r}"
        )
    record["well_formed"] = not record["parse_errors"]
    record["transform_outcome"] = transform_outcome(record["findings"])
    return record


def contains(value, needle):
    return needle in (value or "")


def finding_filter_requested(args):
    return any([
        args.finding_class,
        args.severity,
        args.status,
        args.subject_ref,
        args.file_ref,
        args.law_ref,
    ])


def finding_matches(finding, args):
    if args.finding_class and finding.get("class") != args.finding_class:
        return False
    if args.severity and finding.get("severity") != args.severity:
        return False
    if args.status and finding.get("status") != args.status:
        return False
    subject_needles = [value for value in (args.subject_ref, args.file_ref) if value]
    if subject_needles and not all(contains(finding.get("subject_ref"), value) for value in subject_needles):
        return False
    if args.law_ref:
        haystack = "\n".join([
            finding.get("subject_ref", ""),
            finding.get("problem", ""),
            finding.get("required_change", ""),
        ])
        if args.law_ref not in haystack:
            return False
    return True


def review_matches(record, args):
    if args.candidate and record["candidate"] != args.candidate:
        return False
    if args.typed == "true" and not record["typed"]:
        return False
    if args.typed == "false" and record["typed"]:
        return False
    if args.recommendation and record.get("recommendation") != args.recommendation:
        return False
    if args.eval_check and record["evidence_audit"].get("eval_check") != args.eval_check:
        return False
    if args.transform_outcome and record.get("transform_outcome") != args.transform_outcome:
        return False
    if finding_filter_requested(args):
        return any(finding_matches(finding, args) for finding in record["findings"])
    return True


def compact_text(record):
    if not record["typed"]:
        return f"{record['candidate']} typed=false review={record['review_path']}"
    malformed = "" if record["well_formed"] else f" malformed={len(record['parse_errors'])}"
    return (
        f"{record['candidate']} typed=true well_formed={str(record['well_formed']).lower()}"
        f" recommendation={record.get('recommendation') or 'unknown'}"
        f" eval_check={record['evidence_audit'].get('eval_check', 'unknown')}"
        f" landing_tier={record['subject'].get('landing_tier', 'unknown')}"
        f" transform_outcome={record['transform_outcome']}"
        f" findings={len(record['findings'])}{malformed}"
        f" review={record['review_path']}"
    )


def emit_summary(records, jsonl):
    summary = {
        "reviews": len(records),
        "typed": sum(1 for r in records if r["typed"]),
        "untyped": sum(1 for r in records if not r["typed"]),
        "malformed": sum(1 for r in records if r["typed"] and not r["well_formed"]),
        "recommendations": Counter(r.get("recommendation") or "unknown" for r in records if r["typed"]),
        "eval_checks": Counter(r["evidence_audit"].get("eval_check", "unknown") for r in records if r["typed"]),
        "transform_outcomes": Counter(r.get("transform_outcome", "unknown") for r in records if r["typed"]),
    }
    if jsonl:
        print(json.dumps(summary, sort_keys=True))
        return
    print(f"reviews: {summary['reviews']}")
    print(f"typed: {summary['typed']}")
    print(f"untyped: {summary['untyped']}")
    print(f"malformed: {summary['malformed']}")
    for label, counter in (
        ("recommendation", summary["recommendations"]),
        ("eval_check", summary["eval_checks"]),
        ("transform_outcome", summary["transform_outcomes"]),
    ):
        for key in sorted(counter):
            print(f"{label}.{key}: {counter[key]}")


def main(argv):
    args = parse_args(argv)
    root = Path(args.root or args.root_arg or ".").resolve()
    reviews_dir = root / "candidates"
    if not reviews_dir.is_dir():
        print(f"review-query: candidates dir missing under {root}", file=sys.stderr)
        return 65
    records = [
        parse_review(path, root)
        for path in sorted(reviews_dir.glob("cand-*/REVIEW.md"))
    ]
    matches = [record for record in records if review_matches(record, args)]
    if args.strict:
        bad = [record for record in matches if record["typed"] and not record["well_formed"]]
        if bad:
            for record in bad:
                print(
                    f"review-query: malformed {record['review_path']}: {'; '.join(record['parse_errors'])}",
                    file=sys.stderr,
                )
            return 1
    if args.summary:
        emit_summary(matches, args.jsonl)
    elif args.jsonl:
        for record in matches:
            print(json.dumps(record, sort_keys=True))
    else:
        for record in matches:
            print(compact_text(record))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
PY
