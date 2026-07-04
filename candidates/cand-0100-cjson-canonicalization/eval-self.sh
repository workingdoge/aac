#!/usr/bin/env bash
# eval-self.sh -- functional evidence for cand-0100-cjson-canonicalization.
#
# Stages the candidate cargo, then verifies cjson/1 determinism, escape
# spelling vectors, the UTF-8-byte key order distinction from JCS, integer
# minimal-decimal vectors, TypeDecl parsing and typeId vectors, R1 digest
# recomputation, no remaining R1 _tbd_ markers, additive-only 2/FACT prose
# changes, and queue formation. Every top-level probe is intentionally run via
# run_failing_probe: successful evidence returns a non-zero probe code after
# proving the positive case and a mutant failure.
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"

# tools/eval/attest.sh uses GNU `head -n -1`. On BSD/macOS, provide the exact
# behavior to the child bash process without modifying the verifier-set tool.
head() {
  if [[ "${1:-}" == "-n" && "${2:-}" == "-1" && $# -eq 3 ]]; then
    awk 'NR > 1 { print prev } { prev = $0 }' "$3"
  else
    command head "$@"
  fi
}
export -f head
export PYTHONDONTWRITEBYTECODE=1

# shellcheck source=../../tools/eval/eval-lib.sh
. "$ROOT/tools/eval/eval-lib.sh"
eval_init "$CAND_DIR" "$ROOT" || exit 1

WORK="$(mktemp -d /private/tmp/aac-cand-0100.XXXXXX)"
STAGED="$WORK/root"
stage_root "$STAGED" || exit 1
export STAGED ROOT WORK

python_probe() {
  PYTHONPATH="$STAGED/sites/ledger/specs/2/reference${PYTHONPATH:+:$PYTHONPATH}" python3 - "$@"
}

encoder_determinism_probe() {
  python_probe <<'PY'
import cjson1_encode as c
import sys


def fail(message):
    print(message)
    sys.exit(0)


def must_reject(text):
    try:
        c.loads_json(text)
    except c.CjsonError:
        return
    fail(f"input unexpectedly accepted: {text}")


left = c.loads_json('{"😀":2,"b":1,"a":[3,{"z":0}],"":1}')
right = c.loads_json('{"":1,"a":[3,{"z":0}],"b":1,"😀":2}')
left_enc = c.encode_text(left)
right_enc = c.encode_text(right)
if left_enc != right_enc:
    fail("same object with different source order encoded differently")
if left_enc != '{"a":[3,{"z":0}],"b":1,"":1,"😀":2}':
    fail(f"unexpected canonical encoding: {left_enc}")
for bad in ['{"x":1,"x":2}', '1.0', '1e6', '-0', '01']:
    must_reject(bad)
try:
    c.encode(c.loads_json('"\\ud800"'))
except c.CjsonError:
    pass
else:
    fail('surrogate string unexpectedly encoded')
print("encoder is deterministic across source member order and rejects duplicate keys, floats/exponents, -0/leading-zero forms, and surrogate strings")
sys.exit(41)
PY
}

escape_vectors_probe() {
  python_probe <<'PY'
import copy
import json
import os
import sys

import cjson1_encode as c


def fail(message):
    print(message)
    sys.exit(0)


path = os.path.join(os.environ["STAGED"], "sites/ledger/specs/2/vectors/cjson1-escape.json")
with open(path, encoding="utf-8") as fh:
    vectors = json.load(fh)


def check(doc):
    cases = doc.get("cases", [])
    if len(cases) != 34:
        return False, f"expected 34 escape cases, found {len(cases)}"
    control_count = sum(1 for case in cases if case["codepoint"].startswith("U+00") and int(case["codepoint"][2:], 16) < 0x20)
    short_controls = sum(1 for case in cases if case.get("class") == "json-short-control")
    unicode_controls = sum(1 for case in cases if case.get("class") == "unicode-control")
    if control_count != 32 or short_controls != 5 or unicode_controls != 27:
        return False, "control character class coverage is incomplete"
    for case in cases:
        code = int(case["codepoint"][2:], 16)
        encoded = c.encode_text(chr(code))
        if encoded != case["expectedEncoding"]:
            return False, f"{case['codepoint']} expectedEncoding mismatch: {encoded} != {case['expectedEncoding']}"
        if c.encode(chr(code)).hex() != case["expectedHex"]:
            return False, f"{case['codepoint']} expectedHex mismatch"
    return True, "ok"


ok, message = check(vectors)
if not ok:
    fail(message)

mutant = copy.deepcopy(vectors)
for case in mutant["cases"]:
    if case["codepoint"] == "U+001F":
        bad = '"\\u001F"'
        case["expectedEncoding"] = bad
        case["expectedHex"] = bad.encode("utf-8").hex()
        break
ok, _ = check(mutant)
if ok:
    fail("uppercase-hex escape mutant unexpectedly passed")

print("escape vectors cover every control character plus quote/backslash; uppercase-hex mutant is rejected")
sys.exit(42)
PY
}

key_order_probe() {
  python_probe <<'PY'
import copy
import json
import os
import sys

import cjson1_encode as c


def fail(message):
    print(message)
    sys.exit(0)


path = os.path.join(os.environ["STAGED"], "sites/ledger/specs/2/vectors/cjson1-key-order.json")
with open(path, encoding="utf-8") as fh:
    vectors = json.load(fh)


def check(doc):
    case = doc["case"]
    encoded = c.encode_text(case["value"])
    if encoded != case["expectedEncoding"]:
        return False, f"key-order encoding mismatch: {encoded} != {case['expectedEncoding']}"
    if c.encode(case["value"]).hex() != case["expectedHex"]:
        return False, "key-order hex mismatch"
    if case["utf8ByteOrder"] != ["U+E000", "U+1F600"]:
        return False, "UTF-8-byte order witness missing"
    if case["jcsUtf16OrderWouldBe"] != ["U+1F600", "U+E000"]:
        return False, "JCS/UTF-16 contrast witness missing"
    return True, "ok"


ok, message = check(vectors)
if not ok:
    fail(message)

mutant = copy.deepcopy(vectors)
bad = '{"😀":2,"":1}'
mutant["case"]["expectedEncoding"] = bad
mutant["case"]["expectedHex"] = bad.encode("utf-8").hex()
ok, _ = check(mutant)
if ok:
    fail("JCS-key-order mutant unexpectedly passed")

print("astral-plane key vector follows UTF-8 byte order and rejects the JCS/UTF-16 order mutant")
sys.exit(43)
PY
}

integer_vectors_probe() {
  python_probe <<'PY'
import copy
import json
import os
import sys

import cjson1_encode as c


def fail(message):
    print(message)
    sys.exit(0)


path = os.path.join(os.environ["STAGED"], "sites/ledger/specs/2/vectors/cjson1-integers.json")
with open(path, encoding="utf-8") as fh:
    vectors = json.load(fh)


def check(doc):
    saw_big = False
    for case in doc["cases"]:
        value = case["value"]
        encoded = c.encode_text(value)
        if abs(value) > 10**50:
            saw_big = True
        if "e" in encoded.lower():
            return False, f"integer used exponent form: {encoded}"
        if encoded != case["expectedEncoding"]:
            return False, f"integer encoding mismatch: {encoded} != {case['expectedEncoding']}"
        if c.encode(value).hex() != case["expectedHex"]:
            return False, "integer hex mismatch"
    if not saw_big:
        return False, "big integer witness missing"
    for text in doc["rejectJsonInputs"]:
        try:
            c.loads_json(text)
        except c.CjsonError:
            continue
        return False, f"non-minimal/exponent input unexpectedly accepted: {text}"
    return True, "ok"


ok, message = check(vectors)
if not ok:
    fail(message)

mutant = copy.deepcopy(vectors)
for case in mutant["cases"]:
    if abs(case["value"]) > 10**50:
        bad = f"{case['value']:.1e}"
        case["expectedEncoding"] = bad
        case["expectedHex"] = bad.encode("utf-8").hex()
        break
ok, _ = check(mutant)
if ok:
    fail("big-integer exponent-form mutant unexpectedly passed")

print("integer vectors prove arbitrary-precision decimal output and reject exponent/non-minimal input forms")
sys.exit(44)
PY
}

typedecl_vectors_probe() {
  python_probe <<'PY'
import json
import os
import sys

import cjson1_encode as c


def fail(message):
    print(message)
    sys.exit(0)


staged = os.environ["STAGED"]
path = os.path.join(staged, "sites/ledger/specs/2/vectors/typedecl-typeids.json")
with open(path, encoding="utf-8") as fh:
    vectors = json.load(fh)
expected_handles = ["cjson/1", "sha256/1", "d2f-31be/1", "uh-bn254/1", "name-ens/1", "data-walrus/1"]
handles = [case["handle"] for case in vectors["cases"]]
if handles != expected_handles:
    fail(f"unexpected TypeDecl handle order: {handles}")

for case in vectors["cases"]:
    doc_path = os.path.join(staged, case["document"])
    value = c.load_json(doc_path)
    if set(["kind", "version", "schema"]) - set(value):
        fail(f"TypeDecl missing required keys: {case['document']}")
    if not isinstance(value["kind"], str) or not isinstance(value["version"], int) or not isinstance(value["schema"], (dict, list, str, int, bool, type(None))):
        fail(f"TypeDecl required key has wrong type: {case['document']}")
    if value.get("name") != case["handle"]:
        fail(f"TypeDecl name does not match vector handle: {case['document']}")
    canonical = c.encode_text(value)
    if canonical != case["canonicalEncoding"]:
        fail(f"canonical TypeDecl encoding mismatch for {case['handle']}")
    if canonical.encode("utf-8").hex() != case["canonicalHex"]:
        fail(f"canonical TypeDecl hex mismatch for {case['handle']}")
    if "sha256:" + c.sha256_hex(value) != case["typeId"]:
        fail(f"typeId mismatch for {case['handle']}")

try:
    c.loads_json('{"kind":"encoding","kind":"hash","version":1,"schema":{}}')
except c.CjsonError:
    pass
else:
    fail("duplicate-key TypeDecl mutant unexpectedly parsed")

print("all TypeDecl docs parse under cjson/1 and reproduce the TypeDecl->typeId vectors; duplicate-key mutant is rejected")
sys.exit(45)
PY
}

r1_digest_probe() {
  python_probe <<'PY'
import json
import os
import re
import sys

import cjson1_encode as c


def fail(message):
    print(message)
    sys.exit(0)


staged = os.environ["STAGED"]
r1_path = os.path.join(staged, "sites/ledger/specs/registers/R1.md")
vec_path = os.path.join(staged, "sites/ledger/specs/2/vectors/typedecl-typeids.json")
with open(r1_path, encoding="utf-8") as fh:
    r1 = fh.read()
with open(vec_path, encoding="utf-8") as fh:
    vectors = json.load(fh)


def parse_r1(text):
    rows = {}
    for handle, digest in re.findall(r"\| `([^`]+)` \| `sha256:([0-9a-f]{64})` \|", text):
        rows[handle] = "sha256:" + digest
    return rows


def check(text):
    rows = parse_r1(text)
    if len(rows) != 6:
        return False, f"expected six computed R1 digests, found {len(rows)}"
    for case in vectors["cases"]:
        doc = c.load_json(os.path.join(staged, case["document"]))
        expected = "sha256:" + c.sha256_hex(doc)
        if rows.get(case["handle"]) != expected:
            return False, f"R1 digest mismatch for {case['handle']}"
    if "`uh-wrap-groth16/1` | _reserved; not assigned in this register_" not in text:
        return False, "reserved wrapper row was not preserved as unassigned"
    return True, "ok"


ok, message = check(r1)
if not ok:
    fail(message)

first = vectors["cases"][0]["typeId"]
replacement = first[:-1] + ("0" if first[-1] != "0" else "1")
mutant = r1.replace(first, replacement, 1)
ok, _ = check(mutant)
if ok:
    fail("corrupt R1 digest mutant unexpectedly recomputed")

print("every computed R1 digest recomputes from its TypeDecl document and corrupt-digest mutant is rejected")
sys.exit(46)
PY
}

r1_no_tbd_probe() {
  python_probe <<'PY'
import os
import sys


def fail(message):
    print(message)
    sys.exit(0)


path = os.path.join(os.environ["STAGED"], "sites/ledger/specs/registers/R1.md")
text = open(path, encoding="utf-8").read()


def check(body):
    return "_tbd" not in body.lower()


if not check(text):
    fail("R1 still contains a _tbd marker")
if check(text + "\n_tbd_\n"):
    fail("no-_tbd checker mutant unexpectedly passed")
print("R1 has no remaining _tbd marker; injected _tbd mutant is rejected")
sys.exit(47)
PY
}

spec_additive_probe() {
  python_probe <<'PY'
import os
import sys


def fail(message):
    print(message)
    sys.exit(0)


root = os.environ["ROOT"]
staged = os.environ["STAGED"]
base_path = os.path.join(root, "sites/ledger/specs/2/README.md")
staged_path = os.path.join(staged, "sites/ledger/specs/2/README.md")
base = open(base_path, "rb").read()
current = open(staged_path, "rb").read()


def is_subsequence_lines(before, after):
    before_lines = before.splitlines(keepends=True)
    after_lines = after.splitlines(keepends=True)
    pos = 0
    for line in after_lines:
        if pos < len(before_lines) and line == before_lines[pos]:
            pos += 1
    return pos == len(before_lines)


required_preserved = [
    b"- Integers in minimal decimal, optional leading `-`; encoders MUST NOT\n  emit `-0`, leading zeros, or exponent forms.\n",
    b"- Strings as JSON strings with mandatory escaping of `\"` `\\` and\n  control characters, and no other escaping; no unpaired surrogates.\n",
    b"- Objects: `{` pairs `}`, pairs sorted by the UTF-8 bytes of their keys,\n  ascending, duplicate keys forbidden; each pair `enc(key) : enc(value)`;\n  no whitespace.\n",
]
required_added = [
    b"All other control\n  characters MUST be escaped as `\\u00xx` with lowercase hex digits. No\n  other characters are escaped.\n",
    b"cjson/1 is distinct from RFC 8785/JCS: it sorts object keys by UTF-8\nbytes and uses arbitrary-precision minimal decimal integers with no\nexponent forms.\n",
    b"Canonical TypeDecl documents for 2/FACT live under\n`sites/ledger/specs/2/type-declarations/` and are identified by\n`enc(TypeDecl)`, not by source-file whitespace or member order.\n",
]


def check(before, after):
    if not is_subsequence_lines(before, after):
        return False, "staged 2/FACT README is not additive over the baseline"
    for needle in required_preserved:
        if needle not in after:
            return False, f"previously pinned text was not byte-preserved: {needle!r}"
    for needle in required_added:
        if needle not in after:
            return False, f"required additive clarification missing: {needle!r}"
    return True, "ok"


ok, message = check(base, current)
if not ok:
    fail(message)
mutant = current.replace(b"pairs sorted by the UTF-8 bytes of their keys", b"pairs sorted by Unicode scalar values", 1)
ok, _ = check(base, mutant)
if ok:
    fail("spec additive byte-preservation mutant unexpectedly passed")
print("2/FACT README diff is additive, preserves prior key-order/integer/string pins byte-for-byte, and rejects a pin-mutating mutant")
sys.exit(48)
PY
}

queue_formation_probe() {
  local q="$STAGED/candidates/QUEUE.md" mutant="$WORK/QUEUE-duplicate-open.md"
  BOAT_ROOT="$STAGED" QUEUE_MD="$q" bash "$STAGED/tools/queue-lint.sh" > "$TRACES/t09-queue-lint.out" 2>&1 \
    || { echo "staged queue does not lint"; cat "$TRACES/t09-queue-lint.out"; return 0; }
  if grep_prose '[open] (codex, 2026-07-03) **R1 typeId table blocked by underdetermined canonical bytes.' "$q" >/dev/null; then
    echo "cand-0099 obstruction still appears as open"
    return 0
  fi
  grep_prose '[resolved cand-0100-cjson-canonicalization, 2026-07-03] **R1 typeId table blocked by underdetermined canonical bytes.' "$q" >/dev/null \
    || { echo "resolved cand-0100 queue entry missing"; return 0; }
  cp "$q" "$mutant"
  printf '\n## Open\n' >> "$mutant"
  if BOAT_ROOT="$STAGED" QUEUE_MD="$mutant" bash "$STAGED/tools/queue-lint.sh" > "$TRACES/t09-queue-duplicate-open.out" 2>&1; then
    echo "duplicate-open queue mutant unexpectedly passed"
    return 0
  fi
  echo "queue-merge result lints, cand-0099 obstruction is resolved by cand-0100, and duplicate-header mutant is rejected"
  return 49
}

run_failing_probe \
  t01-encoder-determinism \
  "cjson/1 reference encoder is deterministic and rejects out-of-grammar JSON inputs" \
  "encoder determinism probe unexpectedly passed" \
  encoder_determinism_probe

run_failing_probe \
  t02-escape-vectors \
  "escape vectors cover every control character and reject an uppercase-hex mutant" \
  "escape vector probe unexpectedly passed" \
  escape_vectors_probe

run_failing_probe \
  t03-key-order-jcs-mutant \
  "astral-plane key vector locks UTF-8-byte ordering and rejects a JCS-order mutant" \
  "key-order probe unexpectedly passed" \
  key_order_probe

run_failing_probe \
  t04-integer-vectors \
  "big integer vectors use minimal decimal with no exponent forms and reject non-minimal inputs" \
  "integer vector probe unexpectedly passed" \
  integer_vectors_probe

run_failing_probe \
  t05-typedecl-vectors \
  "TypeDecl documents parse and reproduce TypeDecl->typeId vectors" \
  "TypeDecl vector probe unexpectedly passed" \
  typedecl_vectors_probe

run_failing_probe \
  t06-r1-digests \
  "R1 digests recompute from TypeDecl documents and corrupt mutant is rejected" \
  "R1 digest probe unexpectedly passed" \
  r1_digest_probe

run_failing_probe \
  t07-r1-no-tbd \
  "R1 has no _tbd marker and rejects an injected _tbd mutant" \
  "R1 _tbd probe unexpectedly passed" \
  r1_no_tbd_probe

run_failing_probe \
  t08-additive-spec-diff \
  "2/FACT README change is additive and preserves prior cjson/1 pins byte-for-byte" \
  "additive spec diff probe unexpectedly passed" \
  spec_additive_probe

run_failing_probe \
  t09-queue-formation \
  "queue-merge result resolves the cand-0099 obstruction and rejects duplicate-header mutant" \
  "queue formation probe unexpectedly passed" \
  queue_formation_probe

attest_tail "Complete cjson/1 canonical bytes, TypeDecl documents, R1 typeIds, vectors, and cand-0099 queue resolution."
