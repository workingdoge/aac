#!/usr/bin/env bash
set -u

# review-judgment-check: validate the v0 typed ReviewJudgment block inside
# a Boat candidate REVIEW.md.
#
# Usage:
#   review-judgment-check.sh CAND_DIR [ROOT]
#   review-judgment-check.sh --self-test
#
# Boundary: this is a model-layer formation checker for
# premath.review-judgments.v0. It does not prove reviewer independence,
# decide semantic correctness, or authorize admission/landing.

die() { printf 'review-judgment-check: %s\n' "$2" >&2; exit "$1"; }

if [[ "${1:-}" == "--self-test" ]]; then
  self="$0"
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/review-judgment-check.XXXXXX")" || exit 66
  cleanup() { rm -rf "$tmp"; }
  trap cleanup EXIT
  root="$tmp/root"
  cand="$root/candidates/cand-rj-pass"
  mkdir -p "$cand"
  printf '# brief\n' > "$cand/BRIEF.md"
  printf '# prompt\n' > "$cand/REVIEW-PROMPT.md"
  printf 'payload.txt\tsites/demo/payload.txt\n' > "$cand/LANDING"
  printf '{"verdict":"pass"}\n' > "$cand/scores.json"
  brief_sha="$(python3 - "$cand/BRIEF.md" <<'PY'
import hashlib, sys
print(hashlib.sha256(open(sys.argv[1], "rb").read()).hexdigest())
PY
)"
  prompt_sha="$(python3 - "$cand/REVIEW-PROMPT.md" <<'PY'
import hashlib, sys
print(hashlib.sha256(open(sys.argv[1], "rb").read()).hexdigest())
PY
)"
  cat > "$cand/REVIEW.md" <<EOF
\`\`\`text
ReviewJudgment:
  candidate_id: cand-rj-pass
  reviewed_at: 2026-06-18T00:00:00Z
  subject:
    brief_sha256: $brief_sha
    landing_tier: normal
    review_prompt_sha256: $prompt_sha
  reviewer:
    independence_claim: fresh-session
    write_scope_claim: REVIEW.md-only
  evidence_audit:
    eval_check: reproduced
    witness_ref: tools/eval/eval-check.sh candidates/cand-rj-pass .
  findings: none
  recommendation: admit
\`\`\`
EOF
  bash "$self" "$cand" "$root" >/dev/null || die 1 "self-test pass fixture rejected"
  cp -R "$cand" "$root/candidates/cand-rj-fail"
  python3 - "$root/candidates/cand-rj-fail/REVIEW.md" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
s = s.replace("candidate_id: cand-rj-pass", "candidate_id: cand-rj-fail")
s = s.replace("  findings: none", """  findings:
    - id: R1-F1
      class: correctness
      severity: transform
      status: open
      subject_ref: REVIEW.md
      problem: unresolved transform
      required_change: fix it""")
open(p, "w", encoding="utf-8").write(s)
PY
  bash "$self" "$root/candidates/cand-rj-fail" "$root" >/dev/null 2>&1 \
    && die 1 "self-test invalid admit fixture accepted"
  mkdir -p "$root/candidates/cand-rj-mechanical/seeds/tools/schemas" "$root/candidates/cand-rj-mechanical/traces" "$root/tools/schemas"
  mech="$root/candidates/cand-rj-mechanical"
  printf '# bundle base\nkcir\t/tmp/kcir\tpin flip\tcopy\n' > "$root/tools/schemas/bundle-base.tsv"
  printf '# bundle base\nkcir\t/tmp/kcir\tpin flip\tdependency\n' > "$mech/seeds/tools/schemas/bundle-base.tsv"
  printf 'seeds/tools/schemas/bundle-base.tsv\ttools/schemas/bundle-base.tsv\n' > "$mech/LANDING"
  printf 'layer: artifact\nimplements: none\npreserves: none\ncompares_to: none\n' > "$mech/DECLARATION"
  printf '# brief\n' > "$mech/BRIEF.md"
  printf 'eligibility ok\n' > "$mech/traces/eligibility.out"
  printf 'claim ok\n' > "$mech/traces/claim.out"
  mech_brief_sha="$(python3 - "$mech/BRIEF.md" <<'PY'
import hashlib, sys
print(hashlib.sha256(open(sys.argv[1], "rb").read()).hexdigest())
PY
)"
  cat > "$mech/REVIEW.md" <<EOF
\`\`\`text
ReviewMechanicalChecklist:
  candidate_id: cand-rj-mechanical
  reviewed_at: 2026-06-18T00:00:00Z
  subject:
    brief_sha256: $mech_brief_sha
    landing_tier: verifier-set
    review_tier: tier-mechanical
    review_prompt_sha256: unavailable(tier-mechanical-no-convening)
  eligibility:
    classification: mechanical
    allowed_destinations: tools/schemas/bundle-base.tsv
    diff_class: pin-line-or-generated-file-only
    command: bash tools/review-judgment-check.sh candidates/cand-rj-mechanical .
    exit_code: 0
    output_ref: traces/eligibility.out
    result: pass
  claims:
    - id: C1
      statement: dependency-mode pin flip is recorded
  command_runs:
    - id: R1
      command: printf claim-ok
      exit_code: 0
      output_ref: traces/claim.out
  claim_map:
    - claim: C1
      run: R1
  recommendation: admit
\`\`\`
EOF
  bash "$self" "$mech" "$root" >/dev/null || die 1 "self-test mechanical checklist fixture rejected"
  printf 'review-judgment-check: self-test ok\n'
  exit 0
fi

cand="${1:-}"
root="${2:-${BOAT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}}"
[[ -n "$cand" ]] || die 64 'usage: review-judgment-check.sh CAND_DIR [ROOT]'
[[ -d "$cand" ]] || die 65 "candidate dir missing: $cand"
[[ -d "$root" ]] || die 65 "root dir missing: $root"
cand="$(cd "$cand" && pwd)"
root="$(cd "$root" && pwd)"

python3 - "$cand" "$root" <<'PY'
import difflib
import hashlib
import os
import re
import sys
from pathlib import Path

cand = Path(sys.argv[1])
root = Path(sys.argv[2])
errors = []

def err(msg):
    errors.append(msg)

def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def is_unknown(value):
    return re.fullmatch(r"unknown\([^)]+\)", value or "") is not None

def is_unavailable(value):
    return re.fullmatch(r"unavailable\([^)]+\)", value or "") is not None

def scalar(line, lineno):
    if ":" not in line:
        err(f"line {lineno}: expected key: value")
        return None, None
    key, value = line.split(":", 1)
    key = key.strip()
    value = value.strip()
    if not key:
        err(f"line {lineno}: empty key")
    return key, value

def landing_rows():
    landing = cand / "LANDING"
    rows = []
    if not landing.is_file():
        return rows
    for lineno, line in enumerate(landing.read_text(encoding="utf-8").splitlines(), 1):
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split()
        if len(parts) < 2:
            err(f"LANDING line {lineno}: expected source and destination")
            continue
        rows.append((parts[0], parts[1].lstrip("./")))
    return rows

def landing_tier():
    cats = set()
    for _src, dest in landing_rows():
        if dest.startswith("tools/"):
            cats.add("verifier-set")
        elif dest.startswith("sites/premath/specs/") or dest.startswith("sites/premath/statements/"):
            cats.add("law-spine")
        else:
            cats.add("normal")
    if not cats:
        return "normal"
    if len(cats) > 1:
        return "mixed"
    return next(iter(cats))

def parse_list_record(block, header):
    doc = {
        "subject": {},
        "eligibility": {},
        "claims": [],
        "command_runs": [],
        "claim_map": [],
    }
    top_seen = set()
    section = None
    current_item = None
    list_sections = {"claims", "command_runs", "claim_map"}
    map_sections = {"subject", "eligibility"}
    section_names = {f"{name}:" for name in list_sections | map_sections}

    for lineno, raw in enumerate(block.splitlines(), 1):
        if not raw.strip() or raw.strip().startswith("#"):
            continue
        if raw == header:
            continue
        if raw.startswith("  ") and not raw.startswith("    "):
            body = raw[2:]
            if body in section_names:
                section = body[:-1]
                current_item = None
                continue
            key, value = scalar(body, lineno)
            if key in ("candidate_id", "reviewed_at", "recommendation"):
                if key in top_seen:
                    err(f"line {lineno}: duplicate top-level key {key}")
                top_seen.add(key)
                doc[key] = value
                section = None
            else:
                err(f"line {lineno}: unexpected top-level key {key}")
        elif raw.startswith("    ") and not raw.startswith("      "):
            body = raw[4:]
            if section in map_sections:
                key, value = scalar(body, lineno)
                if key in doc[section]:
                    err(f"line {lineno}: duplicate {section}.{key}")
                doc[section][key] = value
            elif section in list_sections:
                if not body.startswith("- "):
                    err(f"line {lineno}: expected {section} list item")
                    continue
                current_item = {}
                doc[section].append(current_item)
                key, value = scalar(body[2:], lineno)
                if key:
                    current_item[key] = value
            else:
                err(f"line {lineno}: nested field without active section")
        elif raw.startswith("      "):
            body = raw[6:]
            if section not in list_sections or current_item is None:
                err(f"line {lineno}: list field without active list item")
                continue
            key, value = scalar(body, lineno)
            if key in current_item:
                err(f"line {lineno}: duplicate {section}.{key}")
            current_item[key] = value
        else:
            err(f"line {lineno}: unsupported indentation")

    return doc

def candidate_ref_exists(value, field):
    if not value:
        err(f"tier-mechanical.output-ref-missing: {field} missing")
        return False
    if value.startswith("/") or any(part == ".." for part in Path(value).parts):
        err(f"tier-mechanical.output-ref-missing: {field} must be candidate-relative")
        return False
    path = cand / value
    if not path.is_file():
        err(f"tier-mechanical.output-ref-missing: {field} does not exist: {value}")
        return False
    return True

def parse_destinations(value):
    return {part.strip().lstrip("./") for part in value.split(",") if part.strip()}

def is_generated_text(dest, text):
    if dest.endswith(".sh") or dest.startswith("sites/premath/"):
        return False
    header = "\n".join(text.splitlines()[:20])
    return re.search(r"(auto-generated|generated file|mechanically generated|do not edit)", header, re.I) is not None

def is_pin_line(dest, line):
    low = line.lower()
    if dest == "tools/schemas/bundle-base.tsv" and ("\tcopy" in line or "\tdependency" in line):
        return True
    if dest.endswith(".lock") or os.path.basename(dest) in {"flake.lock", "package-lock.json"}:
        return re.search(r"(rev|narhash|lastmodified|lastmodifieddate|sha256|sha512|digest|hash|url|ref)", low) is not None
    return re.search(r"(rev|sha256|sha512|digest|hash|narhash|store[-_ ]?path|from-rev|to-rev|source[-_ ]?ref|pin|pinned)", low) is not None

def mechanical_diff_ok(src, dest):
    src_path = cand / src
    dest_path = root / dest
    if not src_path.is_file():
        return False, f"LANDING source missing: {src}"
    try:
        after = src_path.read_text(encoding="utf-8")
        before = dest_path.read_text(encoding="utf-8") if dest_path.is_file() else ""
    except UnicodeDecodeError:
        return False, f"non-text cargo cannot use pin-line mechanical tier: {dest}"
    if before == after:
        return True, ""
    generated = is_generated_text(dest, after)
    for line in difflib.unified_diff(before.splitlines(), after.splitlines(), lineterm=""):
        if line.startswith(("---", "+++", "@@")):
            continue
        if not line.startswith(("+", "-")):
            continue
        content = line[1:].strip()
        if not content or generated or is_pin_line(dest, content):
            continue
        return False, f"diff for {dest} contains non-pin/generated line: {content[:120]}"
    return True, ""

def declaration_is_mechanical():
    decl = cand / "DECLARATION"
    if not decl.is_file():
        return True, ""
    layer = ""
    for line in decl.read_text(encoding="utf-8").splitlines():
        if line.startswith("layer:"):
            layer = line.split(":", 1)[1].strip()
            break
    if layer and layer != "artifact":
        return False, f"DECLARATION layer {layer!r} is semantic-class for tier-mechanical"
    return True, ""

def validate_mechanical(block):
    doc = parse_list_record(block, "ReviewMechanicalChecklist:")
    candidate_id = cand.name

    if doc.get("candidate_id") != candidate_id:
        err(f"candidate_id mismatch: got {doc.get('candidate_id')!r}, expected {candidate_id!r}")

    if not re.fullmatch(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z", doc.get("reviewed_at", "")):
        err("reviewed_at must be UTC timestamp YYYY-MM-DDTHH:MM:SSZ")

    brief_sha = doc["subject"].get("brief_sha256", "")
    brief = cand / "BRIEF.md"
    if not re.fullmatch(r"[0-9a-f]{64}", brief_sha):
        err("subject.brief_sha256 must be 64 lowercase hex")
    elif brief.is_file() and sha256(brief) != brief_sha:
        err("subject.brief_sha256 does not match BRIEF.md")

    expected_tier = landing_tier()
    if doc["subject"].get("landing_tier") != expected_tier:
        err(f"subject.landing_tier mismatch: got {doc['subject'].get('landing_tier')!r}, expected {expected_tier!r}")
    if doc["subject"].get("landing_tier") not in {"normal", "verifier-set", "law-spine", "mixed"}:
        err("subject.landing_tier out of vocabulary")
    if doc["subject"].get("review_tier") != "tier-mechanical":
        err("subject.review_tier must be tier-mechanical")

    prompt_value = doc["subject"].get("review_prompt_sha256", "")
    prompt = cand / "REVIEW-PROMPT.md"
    if re.fullmatch(r"[0-9a-f]{64}", prompt_value):
        if prompt.is_file() and sha256(prompt) != prompt_value:
            err("subject.review_prompt_sha256 does not match REVIEW-PROMPT.md")
    elif not is_unavailable(prompt_value):
        err("subject.review_prompt_sha256 must be 64 lowercase hex or unavailable(reason)")
    elif prompt.is_file():
        err("subject.review_prompt_sha256 cannot be unavailable(reason) when REVIEW-PROMPT.md exists")

    if doc.get("recommendation") != "admit":
        err("recommendation must be admit for tier-mechanical checklist")

    elig = doc["eligibility"]
    required_elig = {"classification", "allowed_destinations", "diff_class", "command", "exit_code", "output_ref", "result"}
    missing_elig = sorted(required_elig - set(elig))
    if missing_elig:
        err(f"tier-mechanical.eligibility-test-missing: {', '.join(missing_elig)}")
    if elig.get("classification") != "mechanical":
        err("tier-mechanical.eligibility-test-failed: eligibility.classification must be mechanical")
    if elig.get("diff_class") != "pin-line-or-generated-file-only":
        err("tier-mechanical.eligibility-test-failed: eligibility.diff_class must be pin-line-or-generated-file-only")
    if elig.get("exit_code") != "0":
        err("tier-mechanical.eligibility-test-failed: eligibility.exit_code must be 0")
    if elig.get("result") != "pass":
        err("tier-mechanical.eligibility-test-failed: eligibility.result must be pass")
    if not elig.get("command"):
        err("tier-mechanical.eligibility-test-missing: eligibility.command missing")
    if "output_ref" in elig:
        candidate_ref_exists(elig.get("output_ref", ""), "eligibility.output_ref")

    allowed = parse_destinations(elig.get("allowed_destinations", ""))
    if not allowed:
        err("tier-mechanical.eligibility-test-missing: eligibility.allowed_destinations empty")

    ok, reason = declaration_is_mechanical()
    if not ok:
        err(f"tier-mechanical.semantic-diff-ineligible: {reason}")

    for src, dest in landing_rows():
        if dest not in allowed:
            err(f"tier-mechanical.semantic-diff-ineligible: LANDING destination {dest} not in allowed_destinations")
            continue
        diff_ok, diff_reason = mechanical_diff_ok(src, dest)
        if not diff_ok:
            err(f"tier-mechanical.semantic-diff-ineligible: {diff_reason}")

    claim_ids = set()
    for idx, claim in enumerate(doc["claims"], 1):
        cid = claim.get("id", "")
        if not cid:
            err(f"tier-mechanical.claim-map-missing: claim {idx} missing id")
            continue
        if cid in claim_ids:
            err(f"tier-mechanical.claim-map-missing: duplicate claim id {cid}")
        claim_ids.add(cid)
        if not claim.get("statement", ""):
            err(f"tier-mechanical.claim-map-missing: claim {cid} missing statement")
    if not claim_ids:
        err("tier-mechanical.claim-map-missing: no declared claims")

    run_ids = set()
    for idx, run in enumerate(doc["command_runs"], 1):
        rid = run.get("id", "")
        if not rid:
            err(f"tier-mechanical.command-run-missing: command run {idx} missing id")
            continue
        if rid in run_ids:
            err(f"tier-mechanical.command-run-missing: duplicate command run id {rid}")
        run_ids.add(rid)
        if not run.get("command", ""):
            err(f"tier-mechanical.command-run-missing: command run {rid} missing command")
        if run.get("exit_code") != "0":
            err(f"tier-mechanical.command-exit-nonzero: command run {rid} exit_code {run.get('exit_code')!r}")
        candidate_ref_exists(run.get("output_ref", ""), f"command_runs.{rid}.output_ref")
    if not run_ids:
        err("tier-mechanical.command-run-missing: no command runs")

    mapped_claims = set()
    for idx, mapping in enumerate(doc["claim_map"], 1):
        cid = mapping.get("claim", "")
        rid = mapping.get("run", "")
        if not cid or not rid:
            err(f"tier-mechanical.claim-map-missing: claim_map {idx} needs claim and run")
            continue
        if cid not in claim_ids:
            err(f"tier-mechanical.claim-map-missing: claim_map references unknown claim {cid}")
        if rid not in run_ids:
            err(f"tier-mechanical.claim-map-missing: claim_map references unknown run {rid}")
        mapped_claims.add(cid)
    for cid in sorted(claim_ids - mapped_claims):
        err(f"tier-mechanical.claim-map-missing: claim {cid} has no run mapping")

    if errors:
        for msg in errors:
            print(f"review-judgment-check: {msg}", file=sys.stderr)
        print(f"review-judgment-check: rejected ({len(errors)} violation(s))", file=sys.stderr)
        sys.exit(1)

    print(f"review-judgment-check: accepted {candidate_id} (tier-mechanical, {len(claim_ids)} claim(s), recommendation=admit)")
    sys.exit(0)

review = cand / "REVIEW.md"
if not review.is_file():
    err("REVIEW.md missing")
    text = ""
else:
    text = review.read_text(encoding="utf-8")

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

matches = [b for b in blocks if re.search(r"^ReviewJudgment:\s*$", b, re.M)]
mechanical_matches = [b for b in blocks if re.search(r"^ReviewMechanicalChecklist:\s*$", b, re.M)]
if matches and mechanical_matches:
    err("expected exactly one review record block, found both ReviewJudgment and ReviewMechanicalChecklist")
    block = ""
elif len(mechanical_matches) == 1:
    validate_mechanical(mechanical_matches[0])
elif len(mechanical_matches) > 1:
    err(f"expected exactly one fenced ReviewMechanicalChecklist block, found {len(mechanical_matches)}")
    block = ""
elif len(matches) != 1:
    err(f"expected exactly one fenced ReviewJudgment or ReviewMechanicalChecklist block, found {len(matches)} ReviewJudgment and {len(mechanical_matches)} ReviewMechanicalChecklist")
    block = ""
else:
    block = matches[0]

doc = {
    "subject": {},
    "reviewer": {},
    "evidence_audit": {},
    "findings": [],
}
top_seen = set()
section = None
current_finding = None
findings_declared = False

if block:
    for lineno, raw in enumerate(block.splitlines(), 1):
        if not raw.strip() or raw.strip().startswith("#"):
            continue
        if raw == "ReviewJudgment:":
            continue
        if raw.startswith("  ") and not raw.startswith("    "):
            body = raw[2:]
            if body in ("subject:", "reviewer:", "evidence_audit:", "findings:"):
                section = body[:-1]
                if section == "findings":
                    findings_declared = True
                continue
            key, value = scalar(body, lineno)
            if key == "findings" and value == "none":
                findings_declared = True
                section = None
                continue
            if key in ("candidate_id", "reviewed_at", "recommendation"):
                if key in top_seen:
                    err(f"line {lineno}: duplicate top-level key {key}")
                top_seen.add(key)
                doc[key] = value
                section = None
            else:
                err(f"line {lineno}: unexpected top-level key {key}")
        elif raw.startswith("    ") and not raw.startswith("      "):
            body = raw[4:]
            if section in ("subject", "reviewer", "evidence_audit"):
                key, value = scalar(body, lineno)
                if key in doc[section]:
                    err(f"line {lineno}: duplicate {section}.{key}")
                doc[section][key] = value
            elif section == "findings":
                if not body.startswith("- "):
                    err(f"line {lineno}: expected finding list item")
                    continue
                current_finding = {}
                doc["findings"].append(current_finding)
                key, value = scalar(body[2:], lineno)
                if key:
                    current_finding[key] = value
            else:
                err(f"line {lineno}: nested field without active section")
        elif raw.startswith("      "):
            body = raw[6:]
            if section != "findings" or current_finding is None:
                err(f"line {lineno}: finding field without finding item")
                continue
            key, value = scalar(body, lineno)
            if key in current_finding:
                err(f"line {lineno}: duplicate finding.{key}")
            current_finding[key] = value
        else:
            err(f"line {lineno}: unsupported indentation")

candidate_id = cand.name
if doc.get("candidate_id") != candidate_id:
    err(f"candidate_id mismatch: got {doc.get('candidate_id')!r}, expected {candidate_id!r}")

if not re.fullmatch(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z", doc.get("reviewed_at", "")):
    err("reviewed_at must be UTC timestamp YYYY-MM-DDTHH:MM:SSZ")

brief_sha = doc["subject"].get("brief_sha256", "")
brief = cand / "BRIEF.md"
if not re.fullmatch(r"[0-9a-f]{64}", brief_sha):
    err("subject.brief_sha256 must be 64 lowercase hex")
elif brief.is_file() and sha256(brief) != brief_sha:
    err("subject.brief_sha256 does not match BRIEF.md")

prompt_value = doc["subject"].get("review_prompt_sha256", "")
prompt = cand / "REVIEW-PROMPT.md"
if re.fullmatch(r"[0-9a-f]{64}", prompt_value):
    if prompt.is_file() and sha256(prompt) != prompt_value:
        err("subject.review_prompt_sha256 does not match REVIEW-PROMPT.md")
elif not is_unavailable(prompt_value):
    err("subject.review_prompt_sha256 must be 64 lowercase hex or unavailable(reason)")
elif prompt.is_file():
    err("subject.review_prompt_sha256 cannot be unavailable(reason) when REVIEW-PROMPT.md exists")

def landing_tier():
    cats = set()
    for _src, dest in landing_rows():
        if dest.startswith("tools/"):
            cats.add("verifier-set")
        elif dest.startswith("sites/premath/specs/") or dest.startswith("sites/premath/statements/"):
            cats.add("law-spine")
        else:
            cats.add("normal")
    if not cats:
        return "normal"
    if len(cats) > 1:
        return "mixed"
    return next(iter(cats))

expected_tier = landing_tier()
if doc["subject"].get("landing_tier") != expected_tier:
    err(f"subject.landing_tier mismatch: got {doc['subject'].get('landing_tier')!r}, expected {expected_tier!r}")
if doc["subject"].get("landing_tier") not in {"normal", "verifier-set", "law-spine", "mixed"}:
    err("subject.landing_tier out of vocabulary")

independence = doc["reviewer"].get("independence_claim", "")
if independence != "fresh-session" and not is_unknown(independence):
    err("reviewer.independence_claim must be fresh-session or unknown(reason)")
write_scope = doc["reviewer"].get("write_scope_claim", "")
if write_scope != "REVIEW.md-only" and not is_unknown(write_scope):
    err("reviewer.write_scope_claim must be REVIEW.md-only or unknown(reason)")

eval_check = doc["evidence_audit"].get("eval_check", "")
if eval_check not in {"reproduced", "failed", "not-run-with-reason", "not-applicable"}:
    err("evidence_audit.eval_check out of vocabulary")
if (cand / "scores.json").is_file() and eval_check == "not-applicable":
    err("evidence_audit.eval_check cannot be not-applicable when scores.json exists")
witness_ref = doc["evidence_audit"].get("witness_ref", "")
if not witness_ref:
    err("evidence_audit.witness_ref missing")
if eval_check == "reproduced" and "eval-check" not in witness_ref:
    err("evidence_audit.witness_ref must cite eval-check when reproduced")

if not findings_declared:
    err("findings must be declared as findings: none or a findings list")

classes = {
    "evidence", "correctness", "tier-guard", "structural-quality",
    "boundary", "test-gap", "operator-held", "security", "docs",
    "maintainability",
}
severities = {"blocker", "transform", "queue", "note"}
statuses = {"open", "resolved", "superseded", "queued"}
required_finding = {"id", "class", "severity", "status", "subject_ref", "problem", "required_change"}
open_findings = []
open_blocking = []
ids = set()
for idx, finding in enumerate(doc["findings"], 1):
    missing = sorted(required_finding - set(finding))
    if missing:
        err(f"finding {idx} missing required field(s): {', '.join(missing)}")
        continue
    fid = finding["id"]
    if fid in ids:
        err(f"duplicate finding id: {fid}")
    ids.add(fid)
    if not re.fullmatch(r"R[0-9]+-F[0-9]+", fid):
        err(f"finding {fid}: id must match Rn-Fn")
    if finding["class"] not in classes:
        err(f"finding {fid}: class out of vocabulary")
    if finding["severity"] not in severities:
        err(f"finding {fid}: severity out of vocabulary")
    if finding["status"] not in statuses:
        err(f"finding {fid}: status out of vocabulary")
    for key in ("subject_ref", "problem", "required_change"):
        if not finding[key]:
            err(f"finding {fid}: {key} must be non-empty")
    if finding["status"] == "open":
        open_findings.append(finding)
        if finding["severity"] in {"blocker", "transform"}:
            open_blocking.append(finding)

recommendation = doc.get("recommendation", "")
if recommendation not in {"admit", "transform", "deny", "needs-more-evidence"}:
    err("recommendation out of vocabulary")
elif recommendation == "admit":
    if open_blocking:
        err("recommendation admit is invalid with open blocker/transform finding(s)")
    if eval_check == "failed":
        err("recommendation admit is invalid when evidence audit failed")
else:
    if not open_findings and eval_check != "failed":
        err(f"recommendation {recommendation} requires an open finding or failed evidence audit")

if errors:
    for msg in errors:
        print(f"review-judgment-check: {msg}", file=sys.stderr)
    print(f"review-judgment-check: rejected ({len(errors)} violation(s))", file=sys.stderr)
    sys.exit(1)

print(f"review-judgment-check: accepted {candidate_id} ({len(doc['findings'])} finding(s), recommendation={recommendation})")
PY
