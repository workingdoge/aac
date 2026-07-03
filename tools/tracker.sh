#!/usr/bin/env bash
set -euo pipefail

if ! command -v python3 >/dev/null 2>&1; then
  printf 'tracker: verifier_contract_violation: python3 unavailable\n' >&2
  exit 65
fi

exec python3 - "$@" <<'PY'
import argparse
import atexit
import hashlib
import json
import os
import pathlib
import re
import sys
import tempfile
import time
from datetime import datetime, timezone

DEFAULT_ROOT = "/Users/arj/irai/.boat/tracker"
ROOT = pathlib.Path(os.environ.get("BOAT_TRACKER_ROOT", DEFAULT_ROOT))
ISSUES_DIR = ROOT / "issues"
EVENTS = ROOT / "events.jsonl"
ACTORS = ROOT / "actors.tsv"
LOCK = ROOT / ".lock.d"
ZERO = "ZERO"

AGENT_BUNDLE = {"SubjectValid", "CredentialValid", "ScopeValid", "FreshAt"}
OPERATOR_BUNDLE = {
    "IssuerTrusted",
    "SignedBy",
    "SubjectValid",
    "CredentialValid",
    "ScopeValid",
    "FreshAt",
}
KNOWN_CLASSES = OPERATOR_BUNDLE
STATUSES = {"open", "claimed", "closed", "obstructed"}
KINDS = {"task", "decision", "obstruction"}
PRIORITIES = {"P1", "P2", "P3"}
REQUIRED_ISSUE_FIELDS = [
    "id",
    "title",
    "body",
    "scope",
    "kind",
    "priority",
    "provenanceRefs",
    "createdBy",
    "deps",
    "holderToBe",
    "acceptance",
]
REQUIRED_EVENT_FIELDS = [
    "seq",
    "issue_seq",
    "prev_hash",
    "issue_prev_hash",
    "ts",
    "actor",
    "issue",
    "from",
    "to",
    "reason",
    "claimed_classes",
    "hash",
]


class TrackerError(Exception):
    def __init__(self, cls, detail, code=65):
        super().__init__(detail)
        self.cls = cls
        self.detail = detail
        self.code = code


def die(cls, detail, code=65):
    raise TrackerError(cls, detail, code)


def usage(detail):
    die("usage", detail, 64)


def now_token():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def compact_detail(value):
    return str(value).replace("\t", " ").replace("\n", "\\n").replace("\r", "\\r")


def tsv_row(*cols):
    print("\t".join(compact_detail(c) for c in cols))


def ensure_root():
    ISSUES_DIR.mkdir(parents=True, exist_ok=True)
    if not EVENTS.exists():
        atomic_write_text(EVENTS, "")


def fsync_dir(path):
    try:
        fd = os.open(str(path), os.O_RDONLY)
    except OSError:
        return
    try:
        os.fsync(fd)
    finally:
        os.close(fd)


def atomic_write_text(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix=f".{path.name}.", suffix=".tmp", dir=str(path.parent))
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(text)
            f.flush()
            os.fsync(f.fileno())
        os.replace(tmp, path)
        fsync_dir(path.parent)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)


def atomic_write_json(path, obj):
    text = json.dumps(obj, sort_keys=True, indent=2) + "\n"
    atomic_write_text(path, text)


def acquire_lock():
    ROOT.mkdir(parents=True, exist_ok=True)
    delay = 0.025
    while True:
        try:
            os.mkdir(LOCK)
            (LOCK / "pid").write_text(str(os.getpid()) + "\n", encoding="utf-8")
            (LOCK / "created_at_epoch").write_text(str(int(time.time())) + "\n", encoding="utf-8")
            atexit.register(release_lock)
            return
        except FileExistsError:
            time.sleep(delay)
            delay = min(delay * 1.5, 0.25)


def release_lock():
    try:
        if (LOCK / "pid").read_text(encoding="utf-8").strip() == str(os.getpid()):
            for child in LOCK.iterdir():
                child.unlink()
            LOCK.rmdir()
    except FileNotFoundError:
        return
    except OSError:
        return


class write_lock:
    def __enter__(self):
        acquire_lock()
        ensure_root()
        return self

    def __exit__(self, exc_type, exc, tb):
        release_lock()
        return False


def is_instance_token(token):
    if not token:
        return False
    for ch in token:
        o = ord(ch)
        if o < 33 or o > 126 or ch in "/:" or ch.isspace():
            return False
    return True


def scope_token(scope):
    if scope == "workspace":
        return "workspace"
    if scope.startswith("instance:"):
        token = scope.split(":", 1)[1]
        if is_instance_token(token):
            return "instance-" + token
    return None


def parse_issue_id(issue_id):
    if not isinstance(issue_id, str):
        return None
    m = re.fullmatch(r"issue:(workspace|instance-[^:\s/]+):([1-9][0-9]*)", issue_id)
    if not m:
        return None
    token, ordinal = m.group(1), int(m.group(2))
    scope = "workspace" if token == "workspace" else "instance:" + token[len("instance-") :]
    if scope != "workspace" and not is_instance_token(scope.split(":", 1)[1]):
        return None
    return scope, ordinal


def issue_id_for(scope, ordinal):
    token = scope_token(scope)
    if token is None:
        die("vocabulary-atom-failure", f"bad scope: {scope}")
    return f"issue:{token}:{ordinal}"


def issue_path(issue_id):
    return ISSUES_DIR / f"{issue_id}.json"


def nonempty_string(value):
    return isinstance(value, str) and value.strip() != ""


def one_line_nonempty(value):
    return nonempty_string(value) and "\n" not in value and "\r" not in value


def valid_identity_ref(value):
    if not isinstance(value, str) or not value.startswith("identity.presentation:"):
        return False
    tail = value.split(":", 1)[1]
    return bool(tail) and not any(ch.isspace() or ord(ch) < 32 for ch in tail)


def valid_candidate_ref(value):
    return bool(
        isinstance(value, str)
        and re.fullmatch(r"candidate\(number=[1-9][0-9]*, slug=[A-Za-z0-9][A-Za-z0-9._-]*\)", value)
    )


def valid_statement_ref(value):
    return bool(isinstance(value, str) and re.fullmatch(r"statement\([A-Za-z0-9][A-Za-z0-9._-]*\)", value))


def valid_external_ref(value):
    return bool(isinstance(value, str) and re.fullmatch(r"external\([^)\s][^)]*\)", value))


def valid_provenance_ref(value):
    return valid_candidate_ref(value) or valid_statement_ref(value) or valid_external_ref(value)


def valid_reason_ref(value):
    if not nonempty_string(value):
        return False
    return (
        valid_candidate_ref(value)
        or valid_statement_ref(value)
        or valid_external_ref(value)
        or parse_issue_id(value) is not None
        or re.fullmatch(r"evidence:[^\s:][^\s]*", value) is not None
    )


def boundary_violation(issue):
    holder = str(issue.get("holderToBe", "")).strip().lower()
    acceptance = str(issue.get("acceptance", "")).strip().lower()
    body = str(issue.get("body", "")).strip().lower()
    if holder in {"none", "n/a", "not applicable", "no holder"}:
        return True
    if acceptance.startswith("not applicable") and ("evidence" in acceptance or "not work" in acceptance):
        return True
    ledger_markers = [
        "course record of what happened",
        "landing recorded",
        "names no remaining work",
        "audit transcript",
        "close-out ledger",
    ]
    return any(marker in body for marker in ledger_markers)


def validate_issue_obj(issue, seen_pairs=None):
    if not isinstance(issue, dict):
        return False, "issue_formation_malformed", "issue JSON is not an object"
    missing = [field for field in REQUIRED_ISSUE_FIELDS if field not in issue]
    if missing:
        return False, "record-formation-incomplete", "missing required fields: " + ",".join(missing)
    if not one_line_nonempty(issue["title"]):
        return False, "record-formation-incomplete", "title must be non-empty single line"
    for field in ("body", "holderToBe", "acceptance"):
        if not nonempty_string(issue[field]):
            return False, "record-formation-incomplete", f"{field} must be non-empty"
    if issue["kind"] not in KINDS or issue["priority"] not in PRIORITIES:
        return False, "vocabulary-atom-failure", "kind or priority outside issue vocabulary"
    token = scope_token(issue["scope"])
    parsed = parse_issue_id(issue["id"])
    if token is None or parsed is None or parsed[0] != issue["scope"]:
        return False, "issue_formation_malformed", "scope/id formation mismatch"
    if not isinstance(issue["provenanceRefs"], list) or not all(valid_provenance_ref(v) for v in issue["provenanceRefs"]):
        return False, "issue_formation_malformed", "malformed provenanceRefs"
    if not valid_identity_ref(issue["createdBy"]):
        return False, "issue_formation_malformed", "malformed createdBy identity presentation ref"
    if not isinstance(issue["deps"], list) or not all(parse_issue_id(v) is not None for v in issue["deps"]):
        return False, "issue_formation_malformed", "malformed deps"
    if boundary_violation(issue):
        return False, "issue_record_boundary_violation", "issue/evidence boundary violation"
    if seen_pairs is not None:
        pair = parsed
        if pair in seen_pairs:
            return False, "issue_formation_malformed", "reused ordinal within scope"
        seen_pairs.add(pair)
    return True, "-", "ok"


def load_json(path):
    try:
        with path.open("r", encoding="utf-8") as f:
            return json.load(f)
    except FileNotFoundError:
        die("issue_formation_malformed", f"missing issue file: {path.name}")
    except json.JSONDecodeError as e:
        die("issue_formation_malformed", f"malformed JSON in {path.name}: {e}")


def load_issue(issue_id):
    issue = load_json(issue_path(issue_id))
    ok, cls, detail = validate_issue_obj(issue)
    if not ok:
        die(cls, detail)
    if issue.get("id") != issue_id:
        die("issue_formation_malformed", f"issue file id mismatch: {issue_id}")
    return issue


def iter_issue_paths():
    if not ISSUES_DIR.exists():
        return []
    return sorted(ISSUES_DIR.glob("*.json"))


def load_issues():
    issues = {}
    seen = set()
    for path in iter_issue_paths():
        try:
            issue = load_json(path)
        except TrackerError:
            raise
        ok, cls, detail = validate_issue_obj(issue, seen)
        if not ok:
            die(cls, f"{path.name}: {detail}")
        expected = f"{issue['id']}.json"
        if path.name != expected:
            die("issue_formation_malformed", f"{path.name}: filename must be {expected}")
        issues[issue["id"]] = issue
    return issues


def canonical_event(event):
    body = dict(event)
    body.pop("hash", None)
    return json.dumps(body, sort_keys=True, separators=(",", ":"))


def event_hash(event):
    return hashlib.sha256(canonical_event(event).encode("utf-8")).hexdigest()


def raw_event_lines():
    if not EVENTS.exists():
        return []
    data = EVENTS.read_bytes()
    if data and not data.endswith(b"\n"):
        die("issue_event_chain_invalid", "unterminated final event row")
    text = data.decode("utf-8")
    return [line for line in text.splitlines() if line.strip()]


def parse_event_line(line, index):
    try:
        event = json.loads(line)
    except json.JSONDecodeError as e:
        die("issue_event_chain_invalid", f"event {index}: malformed JSON: {e}")
    if not isinstance(event, dict):
        die("issue_event_chain_invalid", f"event {index}: row is not an object")
    missing = [field for field in REQUIRED_EVENT_FIELDS if field not in event]
    if missing:
        die("record-formation-incomplete", f"event {index}: missing fields: {','.join(missing)}")
    return event


def load_events_verify_chain():
    lines = raw_event_lines()
    events = []
    prev = ZERO
    issue_counts = {}
    issue_prev = {}
    for index, line in enumerate(lines):
        event = parse_event_line(line, index)
        if event["seq"] != index:
            die("issue_event_chain_invalid", f"event {index}: seq={event['seq']} expected {index}")
        if event["prev_hash"] != prev:
            die("issue_event_chain_invalid", f"event {index}: prev_hash mismatch")
        recomputed = event_hash(event)
        if event["hash"] != recomputed:
            die("issue_event_chain_invalid", f"event {index}: hash mismatch")
        issue_id = event["issue"]
        if parse_issue_id(issue_id) is None:
            die("issue_event_chain_invalid", f"event {index}: malformed issue id")
        expected_issue_seq = issue_counts.get(issue_id, 0)
        if event["issue_seq"] != expected_issue_seq:
            die("issue_event_chain_invalid", f"event {index}: issue_seq mismatch")
        expected_issue_prev = issue_prev.get(issue_id, ZERO)
        if event["issue_prev_hash"] != expected_issue_prev:
            die("issue_event_chain_invalid", f"event {index}: issue_prev_hash mismatch")
        if not one_line_nonempty(event["ts"]):
            die("record-formation-incomplete", f"event {index}: ts missing")
        if not valid_identity_ref(event["actor"]):
            die("issue_event_chain_invalid", f"event {index}: malformed actor")
        if event["from"] != "unborn" and event["from"] not in STATUSES:
            die("vocabulary-atom-failure", f"event {index}: bad from state")
        if event["to"] not in STATUSES:
            die("vocabulary-atom-failure", f"event {index}: bad to state")
        if not valid_reason_ref(event["reason"]):
            die("issue_event_chain_invalid", f"event {index}: malformed reason")
        if not valid_class_list(event["claimed_classes"]):
            die("issue_transition_unauthorized", f"event {index}: malformed witness classes")
        events.append(event)
        prev = event["hash"]
        issue_counts[issue_id] = expected_issue_seq + 1
        issue_prev[issue_id] = event["hash"]
    return lines, events


def append_event(issue_id, from_state, to_state, actor, reason, classes):
    lines, events = load_events_verify_chain()
    issue_events = [e for e in events if e["issue"] == issue_id]
    event = {
        "seq": len(events),
        "issue_seq": len(issue_events),
        "prev_hash": events[-1]["hash"] if events else ZERO,
        "issue_prev_hash": issue_events[-1]["hash"] if issue_events else ZERO,
        "ts": now_token(),
        "actor": actor,
        "issue": issue_id,
        "from": from_state,
        "to": to_state,
        "reason": reason,
        "claimed_classes": sorted(classes),
    }
    event["hash"] = event_hash(event)
    encoded = json.dumps(event, sort_keys=True, separators=(",", ":")) + "\n"
    existing = "".join(line + "\n" for line in lines)
    atomic_write_text(EVENTS, existing + encoded)


def valid_class_list(value):
    return isinstance(value, list) and all(isinstance(v, str) and v in KNOWN_CLASSES for v in value)


def has_agent(classes):
    return AGENT_BUNDLE.issubset(classes)


def has_operator(classes):
    return OPERATOR_BUNDLE.issubset(classes)


def actor_classes(actor):
    if not valid_identity_ref(actor):
        die("issue_transition_unauthorized", f"actor is not an identity presentation ref: {actor}")
    if not ACTORS.exists():
        die("issue_transition_unauthorized", f"actor role file missing: {ACTORS}")
    matches = []
    with ACTORS.open("r", encoding="utf-8") as f:
        for line_no, line in enumerate(f, 1):
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if "\t" in line:
                name, csv = line.split("\t", 1)
            elif "," in line:
                name, csv = line.split(",", 1)
            else:
                die("issue_transition_unauthorized", f"actors.tsv line {line_no}: expected actor<TAB>classes")
            classes = [part.strip() for part in csv.split(",") if part.strip()]
            if name == actor:
                matches.append(set(classes))
    if len(matches) != 1:
        die("issue_transition_unauthorized", f"actor not declared exactly once: {actor}")
    classes = matches[0]
    if not classes or not classes.issubset(KNOWN_CLASSES):
        die("issue_transition_unauthorized", f"actor has malformed witness classes: {actor}")
    return classes


def allowed_transition(issue, from_state, to_state, actor, classes, holder):
    edge = (from_state, to_state)
    if edge == ("unborn", "open"):
        return has_operator(classes)
    if edge == ("open", "claimed"):
        return has_agent(classes) or has_operator(classes)
    if edge == ("claimed", "open"):
        return has_operator(classes) or (actor == holder and has_agent(classes))
    if edge == ("claimed", "closed"):
        if issue["kind"] == "decision":
            return has_operator(classes)
        return has_operator(classes) or (actor == holder and has_agent(classes))
    if edge == ("claimed", "obstructed"):
        return has_operator(classes) or (actor == holder and has_agent(classes))
    if edge == ("obstructed", "open"):
        return has_agent(classes) or has_operator(classes)
    if edge == ("closed", "open"):
        return has_operator(classes)
    return None


def fold_issue(issue, events):
    state = "unborn"
    holder = None
    for event in events:
        if event["from"] != state:
            die("issue_event_chain_invalid", f"{issue['id']}: from={event['from']} expected {state}")
        classes = set(event["claimed_classes"])
        admitted = allowed_transition(issue, event["from"], event["to"], event["actor"], classes, holder)
        if admitted is None:
            die("issue_transition_illegal", f"{issue['id']}: illegal edge {event['from']}->{event['to']}")
        if not admitted:
            die("issue_transition_unauthorized", f"{issue['id']}: unauthorized edge {event['from']}->{event['to']}")
        if event["from"] == "open" and event["to"] == "claimed":
            holder = event["actor"]
        elif event["from"] == "claimed" and event["to"] in {"open", "closed"}:
            holder = None
        elif event["from"] == "obstructed" and event["to"] == "open":
            holder = None
        elif event["from"] == "closed" and event["to"] == "open":
            holder = None
        state = event["to"]
    if state == "unborn":
        die("issue_event_chain_invalid", f"{issue['id']}: missing genesis event")
    return state, holder


def derived_state(issue, all_events):
    return fold_issue(issue, [e for e in all_events if e["issue"] == issue["id"]])


def next_ordinal(scope):
    max_ordinal = 0
    for path in iter_issue_paths():
        try:
            issue = json.loads(path.read_text(encoding="utf-8"))
        except Exception as e:
            die("issue_formation_malformed", f"cannot allocate with malformed issue file {path.name}: {e}")
        parsed = parse_issue_id(issue.get("id"))
        if parsed is None:
            die("issue_formation_malformed", f"cannot allocate with malformed issue id in {path.name}")
        if parsed[0] == scope:
            max_ordinal = max(max_ordinal, parsed[1])
    return max_ordinal + 1


def selected_issue_view(issue, state):
    return {
        "id": issue["id"],
        "scope": issue["scope"],
        "title": issue["title"],
        "body": issue["body"],
        "kind": issue["kind"],
        "priority": issue["priority"],
        "provenanceRefs": issue["provenanceRefs"],
        "createdBy": issue["createdBy"],
        "deps": issue["deps"],
        "holderToBe": issue["holderToBe"],
        "acceptance": issue["acceptance"],
        "comments": issue.get("comments", []),
        "derivedStatus": state,
    }


def add_common_event_args(parser):
    parser.add_argument("issue")
    parser.add_argument("--actor", required=True)
    parser.add_argument("--reason", required=True)


def parse_create(args):
    parser = argparse.ArgumentParser(prog="tracker.sh create")
    parser.add_argument("--scope", required=True)
    parser.add_argument("--title", required=True)
    parser.add_argument("--body", required=True)
    parser.add_argument("--kind", required=True)
    parser.add_argument("--priority", required=True)
    parser.add_argument("--holder-to-be", required=True)
    parser.add_argument("--acceptance", required=True)
    parser.add_argument("--created-by")
    parser.add_argument("--provenance", action="append", default=[])
    parser.add_argument("--dep", action="append", default=[])
    parser.add_argument("--actor", required=True)
    parser.add_argument("--reason", required=True)
    return parser.parse_args(args)


def parse_transition(name, args):
    parser = argparse.ArgumentParser(prog=f"tracker.sh {name}")
    add_common_event_args(parser)
    return parser.parse_args(args)


def parse_comment(args):
    parser = argparse.ArgumentParser(prog="tracker.sh comment")
    parser.add_argument("issue")
    parser.add_argument("--actor", required=True)
    parser.add_argument("--body", required=True)
    parser.add_argument("--reason", required=True)
    return parser.parse_args(args)


def parse_dep_add(args):
    parser = argparse.ArgumentParser(prog="tracker.sh dep add")
    parser.add_argument("issue")
    parser.add_argument("dep")
    parser.add_argument("--actor", required=True)
    parser.add_argument("--reason", required=True)
    return parser.parse_args(args)


def cmd_create(args):
    ns = parse_create(args)
    with write_lock():
        classes = actor_classes(ns.actor)
        if not has_operator(classes):
            die("issue_transition_unauthorized", "create genesis requires operator bundle")
        if not valid_reason_ref(ns.reason):
            die("issue_event_chain_invalid", "malformed reason")
        ordinal = next_ordinal(ns.scope)
        issue_id = issue_id_for(ns.scope, ordinal)
        issue = {
            "id": issue_id,
            "scope": ns.scope,
            "title": ns.title,
            "body": ns.body,
            "kind": ns.kind,
            "priority": ns.priority,
            "provenanceRefs": ns.provenance,
            "createdBy": ns.created_by or ns.actor,
            "deps": ns.dep,
            "holderToBe": ns.holder_to_be,
            "acceptance": ns.acceptance,
            "comments": [],
            "depAdds": [],
        }
        ok, cls, detail = validate_issue_obj(issue)
        if not ok:
            die(cls, detail)
        path = issue_path(issue_id)
        if path.exists():
            die("issue_formation_malformed", f"issue already exists: {issue_id}")
        try:
            atomic_write_json(path, issue)
            append_event(issue_id, "unborn", "open", ns.actor, ns.reason, classes)
        except Exception:
            try:
                path.unlink()
            except OSError:
                pass
            raise
    print(issue_id)


def cmd_transition(name, target, args):
    ns = parse_transition(name, args)
    with write_lock():
        issue = load_issue(ns.issue)
        if not valid_reason_ref(ns.reason):
            die("issue_event_chain_invalid", "malformed reason")
        classes = actor_classes(ns.actor)
        _, events = load_events_verify_chain()
        state, holder = derived_state(issue, events)
        admitted = allowed_transition(issue, state, target, ns.actor, classes, holder)
        if admitted is None:
            die("issue_transition_illegal", f"illegal edge {state}->{target}")
        if not admitted:
            die("issue_transition_unauthorized", f"unauthorized edge {state}->{target}")
        append_event(issue["id"], state, target, ns.actor, ns.reason, classes)
    tsv_row(issue["id"], state, target)


def cmd_comment(args):
    ns = parse_comment(args)
    if not nonempty_string(ns.body):
        die("record-formation-incomplete", "comment body must be non-empty")
    if not valid_identity_ref(ns.actor):
        die("issue_formation_malformed", "comment actor must be identity presentation ref")
    if not valid_reason_ref(ns.reason):
        die("issue_event_chain_invalid", "malformed comment reason")
    with write_lock():
        issue = load_issue(ns.issue)
        comments = issue.setdefault("comments", [])
        if not isinstance(comments, list):
            die("issue_formation_malformed", "comments must be a list")
        comments.append({"ts": now_token(), "actor": ns.actor, "body": ns.body, "reason": ns.reason})
        atomic_write_json(issue_path(issue["id"]), issue)
    tsv_row(issue["id"], "commented")


def cmd_dep_add(args):
    ns = parse_dep_add(args)
    if parse_issue_id(ns.dep) is None:
        die("issue_formation_malformed", "malformed dependency issue id")
    if not valid_identity_ref(ns.actor):
        die("issue_formation_malformed", "dep actor must be identity presentation ref")
    if not valid_reason_ref(ns.reason):
        die("issue_event_chain_invalid", "malformed dep reason")
    with write_lock():
        issue = load_issue(ns.issue)
        if ns.dep not in issue["deps"]:
            issue["deps"].append(ns.dep)
        issue.setdefault("depAdds", []).append({"ts": now_token(), "actor": ns.actor, "dep": ns.dep, "reason": ns.reason})
        ok, cls, detail = validate_issue_obj(issue)
        if not ok:
            die(cls, detail)
        atomic_write_json(issue_path(issue["id"]), issue)
    tsv_row(issue["id"], "dep_added", ns.dep)


def cmd_show(args):
    parser = argparse.ArgumentParser(prog="tracker.sh show")
    parser.add_argument("issue")
    ns = parser.parse_args(args)
    issue = load_issue(ns.issue)
    _, events = load_events_verify_chain()
    state, _ = derived_state(issue, events)
    print(json.dumps(selected_issue_view(issue, state), sort_keys=True, indent=2))


def cmd_list(args):
    parser = argparse.ArgumentParser(prog="tracker.sh list")
    parser.parse_args(args)
    issues = load_issues()
    _, events = load_events_verify_chain()
    tsv_row("id", "scope", "kind", "priority", "derived_status", "title")
    for issue_id in sorted(issues):
        state, _ = derived_state(issues[issue_id], events)
        tsv_row(issue_id, issues[issue_id]["scope"], issues[issue_id]["kind"], issues[issue_id]["priority"], state, issues[issue_id]["title"])


def cmd_ready(args):
    parser = argparse.ArgumentParser(prog="tracker.sh ready")
    parser.parse_args(args)
    issues = load_issues()
    _, events = load_events_verify_chain()
    statuses = {}
    for issue_id, issue in issues.items():
        statuses[issue_id] = derived_state(issue, events)[0]
    tsv_row("id", "priority", "title")
    for issue_id in sorted(issues):
        issue = issues[issue_id]
        if statuses[issue_id] != "open":
            continue
        blocked = False
        for dep in issue["deps"]:
            if statuses.get(dep) != "closed":
                blocked = True
                break
        if not blocked:
            tsv_row(issue_id, issue["priority"], issue["title"])


def verify_chain_report():
    try:
        _, events = load_events_verify_chain()
    except TrackerError as e:
        tsv_row("events", "chain", "fail", e.cls, e.detail)
        return None, 1
    tsv_row("events", "chain", "pass", "-", f"rows={len(events)}")
    return events, 0


def cmd_verify(args):
    parser = argparse.ArgumentParser(prog="tracker.sh verify")
    parser.parse_args(args)
    failures = 0
    tsv_row("subject", "check", "result", "class", "detail")
    issues = {}
    seen = set()
    for path in iter_issue_paths():
        subject = path.stem
        try:
            issue = load_json(path)
            if isinstance(issue, dict) and isinstance(issue.get("id"), str):
                subject = issue["id"]
            ok, cls, detail = validate_issue_obj(issue, seen)
            if ok and path.name != f"{issue['id']}.json":
                ok, cls, detail = False, "issue_formation_malformed", f"filename must be {issue['id']}.json"
            if ok:
                issues[issue["id"]] = issue
                tsv_row(subject, "formation", "pass", "-", "ok")
            else:
                failures += 1
                tsv_row(subject, "formation", "fail", cls, detail)
        except TrackerError as e:
            failures += 1
            tsv_row(subject, "formation", "fail", e.cls, e.detail)

    events, chain_failures = verify_chain_report()
    failures += chain_failures
    if events is not None:
        for issue_id in sorted(issues):
            try:
                state, _ = derived_state(issues[issue_id], events)
                tsv_row(issue_id, "transition", "pass", "-", f"derived_status={state}")
            except TrackerError as e:
                failures += 1
                tsv_row(issue_id, "transition", "fail", e.cls, e.detail)
    return 0 if failures == 0 else 65


def main(argv):
    if not argv:
        usage("tracker.sh create|show|list|claim|release|close|reopen|obstruct|unblock|comment|dep add|ready|verify")
    cmd, rest = argv[0], argv[1:]
    if cmd == "create":
        cmd_create(rest)
    elif cmd == "show":
        cmd_show(rest)
    elif cmd == "list":
        cmd_list(rest)
    elif cmd == "claim":
        cmd_transition(cmd, "claimed", rest)
    elif cmd == "release":
        cmd_transition(cmd, "open", rest)
    elif cmd == "close":
        cmd_transition(cmd, "closed", rest)
    elif cmd == "reopen":
        cmd_transition(cmd, "open", rest)
    elif cmd == "obstruct":
        cmd_transition(cmd, "obstructed", rest)
    elif cmd == "unblock":
        cmd_transition(cmd, "open", rest)
    elif cmd == "comment":
        cmd_comment(rest)
    elif cmd == "dep":
        if not rest or rest[0] != "add":
            usage("tracker.sh dep add ISSUE DEP --actor ACTOR --reason REF")
        cmd_dep_add(rest[1:])
    elif cmd == "ready":
        cmd_ready(rest)
    elif cmd == "verify":
        return cmd_verify(rest)
    else:
        usage(f"unknown command: {cmd}")
    return 0


try:
    sys.exit(main(sys.argv[1:]))
except TrackerError as e:
    print(f"tracker: {e.cls}: {e.detail}", file=sys.stderr)
    sys.exit(e.code)
except KeyboardInterrupt:
    print("tracker: interrupted", file=sys.stderr)
    sys.exit(130)
PY
