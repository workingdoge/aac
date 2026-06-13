#!/usr/bin/env python3
"""loop-model: the metacircular compared model of tools/loop.

premath.loop-model.v0 (STONE S8). This evaluator predicts the bash
loop's verdicts from laws-as-data (tools/schemas/loop-laws.json) over a
candidate record, read-only. Its output is a PREDICTION DOCUMENT and
nothing else (LM-1.1, checking mode forever): no boat surface may
consume it as a gate, a verdict, or a capability. Agreement with the
live loop — measured by tools/loop-model-diff.sh over the shared
fixture corpus and the live store — is the GATE-3.5 coherence evidence
named by premath.record-judgments.v0's adjoint section.

Structure (the eval/apply reading the repo is built on): EVAL walks law
forms from loop-laws.json and dispatches on their kind; APPLY is the
primitive table that discharges one law against the candidate context.
Sigma built the record; these laws are the Pi face checked against it;
the laws file is the program, this interpreter carries no class names,
no token paths, no reason strings of its own.

Independence (LM-1.3): the judgment semantics here — the validate law
sequence, the attestation chain walk, the receipt-schema directive
engine, the scores_verdict reader, the auto refusal chain, the reflect
assessment tree — are reimplemented from the laws, sharing no code with
tools/loop. Shared by declaration: RJ-1.6 registries both models parse
as data, and the boat.canonical-json.witness-key.v0 wire profile.

usage: loop-model.py predict CAND_DIR --root ROOT [--laws LAWS_JSON]
"""

import base64
import glob
import hashlib
import json
import os
import re
import sys


def read_text(path):
    with open(path, encoding="utf-8", errors="surrogateescape") as fh:
        return fh.read()


def sha256_hex(data):
    if isinstance(data, str):
        data = data.encode("utf-8", errors="surrogateescape")
    return hashlib.sha256(data).hexdigest()


def sha256_file_hex(path):
    with open(path, "rb") as fh:
        return hashlib.sha256(fh.read()).hexdigest()


# --- wire profile: boat.canonical-json.witness-key.v0 (shared substrate,
# --- LM-1.3 — a wire profile is not a judgment) --------------------------

def witness_id(cls, law_ref, token_path, context):
    key = {"schema": 1, "class": cls, "lawRef": law_ref,
           "tokenPath": token_path, "context": context}
    blob = json.dumps(key, sort_keys=True, separators=(",", ":"),
                      ensure_ascii=False).encode("utf-8")
    digest = hashlib.sha256(blob).digest()
    if hasattr(base64, "b32hexencode"):
        enc = base64.b32hexencode(digest).decode("ascii")
    else:
        std = base64.b32encode(digest).decode("ascii")
        enc = std.translate(str.maketrans(
            "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567",
            "0123456789ABCDEFGHIJKLMNOPQRSTUV"))
    return "w1_" + enc.lower().rstrip("=")


# --- bash-faithful record readers ----------------------------------------
# Each helper states the tools/loop construct whose semantics it carries.

def meta_get(meta_text, key):
    """awk -F': ' '$1 == key { sub($1 ": ", ""); print; exit }'
    First line whose text before the first ': ' equals key; value is the
    REST OF THE LINE after that first 'key: ' (further ': ' kept)."""
    for line in meta_text.split("\n"):
        if line.split(": ")[0] == key:
            return line[len(key) + 2:]
    return ""


def field2_get(text, key):
    """awk -F': ' '$1 == k { print $2; exit }' — the SECOND ': '-field
    only (an embedded ': ' in the value truncates it; the loop's
    DECLARATION reads work this way, unlike meta_get)."""
    for line in text.split("\n"):
        parts = line.split(": ")
        if parts[0] == key:
            return parts[1] if len(parts) > 1 else ""
    return ""


def read_two_fields(line):
    """bash `read -r src dest`: leading IFS stripped, first word to src,
    remainder (internal whitespace kept, trailing IFS stripped) to dest.
    IFS is space/tab only here — \\r is data, not a separator."""
    stripped = line.lstrip(" \t")
    if not stripped:
        return "", ""
    parts = re.split(r'[ \t]+', stripped, maxsplit=1)
    src = parts[0]
    dest = parts[1].strip(" \t") if len(parts) > 1 else ""
    return src, dest


def vocab_lines(path):
    """grep -vE '^#|^[[:space:]]*$' — non-comment, non-blank lines."""
    out = []
    for line in read_text(path).split("\n"):
        if line.startswith("#") or line.strip() == "":
            continue
        out.append(line)
    return out


def law_ref_for(registry_path, cls):
    """emit-refusal.sh lookup: first non-comment TSV row with field1 == class."""
    if os.path.isfile(registry_path):
        for line in read_text(registry_path).split("\n"):
            if line.startswith("#"):
                continue
            fields = line.split("\t")
            if len(fields) >= 2 and fields[0] == cls:
                return fields[1]
    return "unregistered(%s)" % cls


# --- attestation chain (tools/eval/attest.sh verify, reimplemented) -------

ATTEST_MARKER = '  ,"provenance": {'


def hash_traces(traces_dir):
    """find -maxdepth 1 -type f | sort -> 'basename sha\\n' stream -> sha."""
    entries = []
    if os.path.isdir(traces_dir):
        for entry in sorted(os.scandir(traces_dir), key=lambda e: e.path):
            if entry.is_file(follow_symlinks=False):
                entries.append(entry.path)
    stream = "".join("%s %s\n" % (os.path.basename(p), sha256_file_hex(p))
                     for p in entries)
    return sha256_hex(stream)


def attest_get(scores_text, key):
    """sed -n 's/^    \"K\": \"\\([^\"]*\\)\".*/\\1/p' | head -1"""
    pat = re.compile(r'^    "' + re.escape(key) + r'": "([^"]*)"')
    for line in scores_text.split("\n"):
        m = pat.match(line)
        if m:
            return m.group(1)
    return ""


def attest_verify(cand_dir, scores_path, root):
    """Exit-status semantics of attest.sh verify: 0 ok, 3 no block, 1 fail."""
    text = read_text(scores_path)
    if ATTEST_MARKER not in text:
        return 3
    stored = {k: attest_get(text, k) for k in
              ("harness", "harness_sha256", "traces_sha256",
               "body_sha256", "attestation")}
    lines = text.split("\n")
    before = []
    for line in lines:
        if line == ATTEST_MARKER:
            break
        before.append(line)
    body = ("\n".join(before) + "\n}" if before else "}") + "\n"
    body_sha = sha256_hex(body)

    harness_path = ""
    for p in (os.path.join(root, "tools", "eval", stored["harness"]),
              os.path.join(cand_dir, stored["harness"]),
              os.path.join(root, "tools", stored["harness"])):
        if stored["harness"] and os.path.isfile(p):
            harness_path = p
            break

    fail = False
    if not harness_path:
        fail = True
    if body_sha != stored["body_sha256"]:
        fail = True
    if harness_path and sha256_file_hex(harness_path) != stored["harness_sha256"]:
        fail = True
    if hash_traces(os.path.join(cand_dir, "traces")) != stored["traces_sha256"]:
        fail = True
    recomputed = sha256_hex(stored["body_sha256"] + stored["traces_sha256"]
                            + stored["harness_sha256"])
    if recomputed != stored["attestation"]:
        fail = True
    return 1 if fail else 0


# --- receipt-schema engine (tools/receipt-schema-check.sh, reimplemented) --

def receipt_field_value(receipt_text, key):
    """lib.sh field_value: first INDENTED 'key:' line, leading space+key+
    colon+space stripped, rest kept."""
    pat = re.compile(r'^[ \t\r\n\v\f]+' + re.escape(key) + r':[ \t\r\n\v\f]*(.*)$')
    for line in receipt_text.split("\n"):
        m = pat.match(line)
        if m:
            return m.group(1)
    return ""


def receipt_schema_rc(receipt_paths, schema_dir):
    """receipt-schema-check.sh without --schema: auto-detect by header
    directive, then run the directive battery; rc 0 iff zero failures."""
    failures = 0
    schemas = sorted(glob.glob(os.path.join(schema_dir, "*.schema")))
    headers = {}
    for schema in schemas:
        for line in read_text(schema).split("\n"):
            toks = line.split()
            if toks and toks[0] == "header" and len(toks) > 1:
                headers[schema] = toks[1]
                break

    for receipt in receipt_paths:
        if not os.path.isfile(receipt):
            failures += 1
            continue
        rtext = read_text(receipt)
        detected = ""
        for schema in schemas:
            hdr = headers.get(schema, "")
            if hdr and re.search(r'^' + re.escape(hdr) + r':', rtext, re.M):
                detected = schema
                break
        if not detected:
            failures += 1
            continue
        for raw in read_text(detected).split("\n"):
            line = raw.split("#")[0]
            if line.strip() == "":
                continue
            stripped = line.lstrip(" \t")
            parts = re.split(r'[ \t]+', stripped, maxsplit=2)
            directive = parts[0]
            key = parts[1] if len(parts) > 1 else ""
            values = parts[2].strip(" \t") if len(parts) > 2 else ""
            if directive == "header":
                if not re.search(r'^' + re.escape(key) + r':', rtext, re.M):
                    failures += 1
            elif directive == "require":
                if receipt_field_value(rtext, key) == "":
                    failures += 1
            elif directive == "literal":
                if receipt_field_value(rtext, key) != values:
                    failures += 1
            elif directive == "enum":
                value = receipt_field_value(rtext, key)
                if not any(value == v for v in values.split()):
                    failures += 1
            elif directive == "enum_prefix":
                value = receipt_field_value(rtext, key)
                if not any(value.startswith(v) for v in values.split()):
                    failures += 1
            else:
                failures += 1
    return 0 if failures == 0 else 1


# --- scores_verdict (tools/loop scores_verdict, reimplemented) -------------

def scores_verdict(path):
    def no_dupes(pairs):
        d = {}
        for k, v in pairs:
            if k in d:
                raise ValueError("duplicate key")
            d[k] = v
        return d
    try:
        with open(path) as fh:
            d = json.load(fh, object_pairs_hook=no_dupes)
    except Exception:
        return "MALFORMED-JSON"
    v = d.get("verdict") if isinstance(d, dict) else None
    if not isinstance(v, str):
        return ""
    if v == "pass":
        return "pass"
    return json.dumps(v)


# --- the evaluator: EVAL dispatches law forms, APPLY discharges them -------

class Ctx:
    """The candidate context the laws are checked against (read-only)."""

    def __init__(self, cand_dir, root, laws):
        self.cand = cand_dir
        self.root = root
        self.laws = laws
        self.cand_id = os.path.basename(os.path.normpath(cand_dir))
        self.failures = []  # vfail accumulation, in law order

    def path(self, rel):
        return os.path.join(self.cand, rel)

    def registry(self, name):
        return os.path.join(self.root, self.laws["registries"][name])

    def meta_text(self):
        p = self.path("META")
        return read_text(p) if os.path.isfile(p) else ""

    def vfail(self, spec, **fmt):
        cls = spec["class"]
        token = spec["token"].format(**fmt)
        reason = spec["reason"].format(**fmt)
        law_ref = law_ref_for(self.registry("failure_classes"), cls)
        self.failures.append({
            "failed_judgment": self.laws["validate"]["failed_judgment"],
            "obstruction_class": cls,
            "lawRef": law_ref,
            "tokenPath": token,
            "reason": reason,
            "witnessId": witness_id(cls, law_ref, token,
                                    {"candidate": self.cand_id}),
        })


def m_eval(law, ctx):
    """EVAL: dispatch a law form to its APPLY primitive."""
    APPLY[law["kind"]](law, ctx)


def apply_file_exists(law, ctx):
    if not os.path.isfile(ctx.path(law["path"])):
        ctx.vfail(law)


def apply_meta_required_keys(law, ctx):
    meta = ctx.meta_text()
    for key in ctx.laws["validate"]["meta_required_keys"]:
        if meta_get(meta, key) == "":
            ctx.vfail(law, key=key)


def apply_meta_equals_dirname(law, ctx):
    if meta_get(ctx.meta_text(), law["key"]) != ctx.cand_id:
        ctx.vfail(law)


def apply_vocab_member(law, ctx):
    value = meta_get(ctx.meta_text(), law["key"])
    vocab_path = ctx.registry(law["vocab"])
    if law.get("skip_if_value_empty") and value == "":
        return
    if law.get("skip_if_vocab_absent") and not os.path.isfile(vocab_path):
        return
    if value not in vocab_lines(vocab_path):
        ctx.vfail(law, value=value)


def apply_landing_lines(law, ctx):
    landing = ctx.path(law["file"])
    if not os.path.isfile(landing):
        return
    by_check = {sub["check"]: sub for sub in law["line_laws"]}
    for line in landing_loop_lines(read_text(landing)):
        src, dest = read_two_fields(line)
        if src == "" or src.startswith("#"):
            continue
        if not os.path.isfile(ctx.path(src)):
            ctx.vfail(by_check["src-exists"], src=src, dest=dest)
        if dest == "":
            ctx.vfail(by_check["dest-nonempty"], src=src, dest=dest)
        if dest.startswith("/") or ".." in dest:
            ctx.vfail(by_check["dest-rooted"], src=src, dest=dest)


def landing_loop_lines(text):
    """`while read ...; done < FILE`: a final line without a trailing
    newline is NOT processed (read populates but returns nonzero, so the
    loop body never runs for it). Either way: drop the last split part."""
    if text == "":
        return []
    return text.split("\n")[:-1]


def apply_declaration(law, ctx):
    decl = ctx.path(law["file"])
    if not os.path.isfile(decl):
        ctx.vfail(law["missing"])
        return
    text = read_text(decl)
    if law["todo_marker"] in text:
        ctx.vfail(law["todo"])
    for key in law["keys"]:
        if not re.search(r'^' + re.escape(key) + r': ', text, re.M):
            ctx.vfail(law["key_missing"], key=key)
    for key in law["keys"]:
        if field2_get(text, key) == "":
            ctx.vfail(law["key_empty"], key=key)
    layer = field2_get(text, "layer")
    if layer not in law["layer_vocab"]:
        ctx.vfail(law["layer_bad"], value=layer)
    preserves = field2_get(text, "preserves")
    if re.match(law["preserves_unknown_pattern"], preserves):
        pass
    elif preserves != "" and preserves != law["preserves_none"]:
        for tok in preserves.replace(",", " ").split():
            if tok not in law["preserves_registry"]:
                ctx.vfail(law["preserves_bad"], tok=tok)


def apply_scores_block(law, ctx):
    scores = ctx.path(law["file"])
    if not os.path.isfile(scores):
        return
    text = read_text(scores)
    for sub in law["block_laws"]:
        if sub["check"] == "has-substring":
            if sub["needle"] not in text:
                ctx.vfail(sub)
        elif sub["check"] == "attest-verify-if-provenance":
            if sub["guard_substring"] in text:
                if attest_verify(ctx.cand, scores, ctx.root) != 0:
                    ctx.vfail(sub)


def apply_drafts_receipts(law, ctx):
    receipts = sorted(glob.glob(ctx.path(law["glob"])))
    if not receipts:
        return
    if receipt_schema_rc(receipts, ctx.registry("receipt_schema_dir")) != 0:
        ctx.vfail(law)


APPLY = {
    "file-exists": apply_file_exists,
    "meta-required-keys": apply_meta_required_keys,
    "meta-equals-dirname": apply_meta_equals_dirname,
    "vocab-member": apply_vocab_member,
    "landing-lines": apply_landing_lines,
    "declaration": apply_declaration,
    "scores-block": apply_scores_block,
    "drafts-receipts": apply_drafts_receipts,
}


# --- surface predictions ----------------------------------------------------

def meta_with_status(meta_text, status):
    """meta_set_status's awk rewrite, for the post-mutation witness hash."""
    out = []
    for line in meta_text.split("\n"):
        if line.split(": ")[0] == "status":
            out.append("status: " + status)
        else:
            out.append(line)
    text = "\n".join(out)
    if not text.endswith("\n"):
        text += "\n"
    return text


def predict_validate(ctx):
    vlaws = ctx.laws["validate"]
    for law in vlaws["laws"]:
        m_eval(law, ctx)

    doc = {"schema": vlaws["doc_schema"], "candidate": ctx.cand_id}
    cur_status = meta_get(ctx.meta_text(), "status")
    if ctx.failures:
        doc["result"] = "rejected"
        doc["failures"] = ctx.failures
        rc = 1
        post_status = cur_status
    else:
        rc = 0
        transition = vlaws["status_transition"]
        post_status = (transition["to"] if cur_status == transition["from"]
                       else cur_status)
        doc["result"] = "admitted"
        doc["judgment"] = vlaws["admitted_judgment"]
        doc["normal_form_ref"] = None
        refs = {}
        for name in vlaws["witness_ref_files"]:
            p = ctx.path(name)
            if os.path.isfile(p):
                if name == "META" and post_status != cur_status:
                    refs[name] = sha256_hex(
                        meta_with_status(ctx.meta_text(), post_status)
                        .encode("utf-8", errors="surrogateescape"))
                else:
                    refs[name] = sha256_file_hex(p)
        doc["witness_refs"] = refs
    text = json.dumps(doc, indent=2, sort_keys=True) + "\n"
    return {"doc": text, "rc": rc, "post_status": post_status}


def predict_scores_verdict(ctx):
    scores = ctx.path("scores.json")
    if not os.path.isfile(scores):
        return ctx.laws["scores_verdict"]["absent_surface_token"]
    return scores_verdict(scores)


def landing_pairs_for_land(ctx):
    """The land arm's pair construction: LANDING map (normalized,
    first invalid dest dies) or the default *.sh -> tools/ rule.
    Returns (pairs, invalid_seen)."""
    landing = ctx.path("LANDING")
    pairs = []
    if os.path.isfile(landing):
        for line in landing_loop_lines(read_text(landing)):
            src, dest = read_two_fields(line)
            if src == "" or src.startswith("#"):
                continue
            if dest.startswith("./"):
                dest = dest[2:]
            if dest == "" or dest.startswith("/") or ".." in dest:
                return pairs, True
            pairs.append((src, dest))
    else:
        for f in sorted(glob.glob(ctx.path("*.sh"))):
            base = os.path.basename(f)
            if base == "eval-self.sh":
                continue
            pairs.append((base, "tools/" + base))
    return pairs, False


def predict_auto(ctx, validate_rc):
    laws = ctx.laws["auto"]
    scores = ctx.path("scores.json")

    def outcome(gate_name):
        for entry in laws["chain"]:
            if entry.get("gate") == gate_name:
                return {"outcome": entry["refusal"]}
        raise KeyError(gate_name)

    if not os.path.isfile(scores):
        return outcome("scores-exists")
    verdict = scores_verdict(scores)
    if verdict == "MALFORMED-JSON":
        return outcome("verdict-not-malformed")
    if verdict != "pass":
        return outcome("verdict-pass")
    if '"provenance"' not in read_text(scores):
        return outcome("provenance-present")
    if attest_verify(ctx.cand, scores, ctx.root) != 0:
        return outcome("attest-verify")
    if validate_rc != 0:
        return outcome("validate-admitted")
    if os.path.isfile(ctx.path("LANDED")):
        return outcome("not-already-landed")
    pairs, invalid = landing_pairs_for_land(ctx)
    if invalid:
        return outcome("landing-dests-valid")
    if not pairs:
        return outcome("landing-nonempty")
    tier_sensitive = any(
        dest.startswith(tuple(laws["tier_patterns"])) for _, dest in pairs)
    if tier_sensitive and not os.path.isfile(ctx.path("REVIEW.md")):
        return outcome("tier-review")
    return {"outcome": laws["chain"][-1]["terminal"]}


def predict_reflect(ctx):
    laws = ctx.laws["reflect"]
    rows = {row["when"]: row for row in laws["table"]}

    def verdict_doc(when):
        row = rows[when]
        return {"assessment": row["assessment"], "basis": row["basis"]}

    scores = ctx.path("scores.json")
    status = meta_get(ctx.meta_text(), "status")
    if not os.path.isfile(scores):
        result = verdict_doc("no-scores")
    else:
        text = read_text(scores)
        if '"provenance"' in text:
            prov = ("verified" if attest_verify(ctx.cand, scores, ctx.root) == 0
                    else "INVALID")
        else:
            prov = "unattested"
        verdict = scores_verdict(scores)
        if prov == "INVALID":
            result = verdict_doc("provenance-invalid")
        elif prov == "unattested":
            result = verdict_doc("unattested")
        elif verdict == "MALFORMED-JSON":
            result = verdict_doc("verdict-malformed")
        elif verdict == "pass":
            result = verdict_doc("verdict-pass")
        elif verdict != "":
            result = verdict_doc("verdict-other")
        elif '"verdict"' in text:
            result = verdict_doc("verdict-mentioned-not-top-level")
        else:
            recalls = []
            for line in text.split("\n"):
                if laws["recall_exclude_substring"] in line:
                    continue
                for m in re.finditer(laws["recall_pattern"], line):
                    num = re.search(r'[0-9.]+$', m.group(0))
                    if num:
                        recalls.append(num.group(0))
            if recalls and all(re.match(laws["recall_one_pattern"], r)
                               for r in recalls):
                result = verdict_doc("recalls-all-one")
            else:
                result = verdict_doc("recalls-fallthrough")
    if status == "rolled-back":
        result = verdict_doc("rolled-back-override")
    return result


def main(argv):
    if len(argv) < 2 or argv[0] != "predict":
        print("usage: loop-model.py predict CAND_DIR --root ROOT "
              "[--laws LAWS_JSON]", file=sys.stderr)
        return 64
    cand_dir = argv[1]
    root = ""
    laws_path = ""
    i = 2
    while i < len(argv):
        if argv[i] == "--root" and i + 1 < len(argv):
            root = argv[i + 1]
            i += 2
        elif argv[i] == "--laws" and i + 1 < len(argv):
            laws_path = argv[i + 1]
            i += 2
        else:
            print("loop-model: unknown argument: %s" % argv[i], file=sys.stderr)
            return 64
    if not root:
        root = os.path.normpath(
            os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
    if not laws_path:
        laws_path = os.path.join(root, "tools", "schemas", "loop-laws.json")
    if not os.path.isdir(cand_dir):
        print("loop-model: no such candidate dir: %s" % cand_dir,
              file=sys.stderr)
        return 66
    if not os.path.isfile(laws_path):
        print("loop-model: laws-as-data missing: %s" % laws_path,
              file=sys.stderr)
        return 66
    if not os.path.isfile(os.path.join(cand_dir, "META")):
        print("loop-model: candidate has no META (the loop refuses these "
              "before any surface; nothing to predict)", file=sys.stderr)
        return 66

    with open(laws_path, encoding="utf-8") as fh:
        laws = json.load(fh)

    ctx = Ctx(cand_dir, root, laws)
    validate = predict_validate(ctx)
    prediction = {
        "schema": "boat.loop-model.prediction.v0",
        "checking_mode":
            "LM-1.1: prediction only — never authority, never a gate",
        "candidate": ctx.cand_id,
        "surfaces": {
            "validate": validate,
            "scores_verdict": predict_scores_verdict(ctx),
            "auto": predict_auto(ctx, validate["rc"]),
            "reflect": predict_reflect(ctx),
        },
    }
    json.dump(prediction, sys.stdout, indent=2, sort_keys=True)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
