#!/usr/bin/env bash
set -u

# witness-id: deterministic witness identifiers (premath.core.witness-id.v0).
#
#   ID = "w1_" + base32hex-lower-nopad( SHA256( canonical-JSON of
#        {schema: 1, class, lawRef, tokenPath, context} ) )
#
# Canonical JSON profile: boat.canonical-json.witness-key.v0 — sorted
# keys, no whitespace separators, UTF-8, integers only. This is the
# minimal-JCS profile realized by tools/toy/witness_id.py (vendored,
# cand-0033); it is NOT full RFC 8785 and does not claim to be: floats
# are rejected rather than canonicalized.
#
# Fail-closed (BIDIR-10.1 posture): unknown fields, missing class or
# lawRef, floats anywhere in context, and malformed JSON are rejections
# (exit 65) — in particular a "message" field is REJECTED, realizing
# the statement's rule that human messages never affect the ID.
#
# usage:
#   printf '{"class":"C","lawRef":"L","tokenPath":null,"context":{}}' \
#     | witness-id.sh            -> w1_... on stdout
#   witness-id.sh --self-test    -> run the boat-local conformance
#                                   vectors (tools/eval/witness-id-vectors.json,
#                                   extracted from the cand-0033 toy fixtures,
#                                   whose IDs the archive Rust kernel
#                                   independently reproduced)

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PYTHON="${BOAT_WITNESS_ID_PYTHON:-$(command -v python3 || true)}"
MODULE_DIR="$ROOT/tools/toy"
VECTORS="${WITNESS_ID_VECTORS:-$ROOT/tools/eval/witness-id-vectors.json}"

if [[ -z "$PYTHON" || ! -x "$PYTHON" ]]; then
  printf 'witness-id: no executable python3 (set BOAT_WITNESS_ID_PYTHON)\n' >&2
  exit 127
fi
if [[ ! -f "$MODULE_DIR/witness_id.py" ]]; then
  printf 'witness-id: vendored module missing: %s/witness_id.py\n' "$MODULE_DIR" >&2
  exit 66
fi

mode="compute"
if [[ "$#" -gt 1 ]]; then
  printf 'usage: witness-id.sh [--self-test]   (compute mode reads the key JSON on stdin)\n' >&2
  exit 64
elif [[ "$#" -eq 1 ]]; then
  case "$1" in
    --self-test) mode="self-test" ;;
    *)
      printf 'usage: witness-id.sh [--self-test]   (compute mode reads the key JSON on stdin)\n' >&2
      exit 64
      ;;
  esac
fi

if [[ "$mode" == "self-test" && ! -f "$VECTORS" ]]; then
  printf 'witness-id: conformance vectors missing: %s\n' "$VECTORS" >&2
  exit 66
fi

key_json=""
if [[ "$mode" == "compute" ]]; then
  key_json="$(cat)"
fi

exec "$PYTHON" - "$mode" "$MODULE_DIR" "$VECTORS" "$key_json" <<'PYEOF'
import json
import sys

mode, module_dir, vectors_path, key_json = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
sys.path.insert(0, module_dir)
from witness_id import witness_id  # noqa: E402

ALLOWED = {"class", "lawRef", "tokenPath", "context"}
REQUIRED = {"class", "lawRef"}


def reject(msg):
    print(f"witness-id: invalid input: {msg}", file=sys.stderr)
    sys.exit(65)


def assert_no_floats(value, path):
    if isinstance(value, float):
        reject(f"float at {path} (boat.canonical-json.witness-key.v0 admits integers only)")
    if isinstance(value, dict):
        for k, v in value.items():
            assert_no_floats(v, f"{path}.{k}")
    if isinstance(value, list):
        for i, v in enumerate(value):
            assert_no_floats(v, f"{path}[{i}]")


def compute(key):
    if not isinstance(key, dict):
        reject("key must be a JSON object")
    unknown = set(key) - ALLOWED
    if unknown:
        reject(f"unknown field(s) {sorted(unknown)} — the canonical key admits only {sorted(ALLOWED)}")
    missing = REQUIRED - set(key)
    if missing:
        reject(f"missing required field(s) {sorted(missing)}")
    if not isinstance(key["class"], str) or not isinstance(key["lawRef"], str):
        reject("class and lawRef must be strings")
    token_path = key.get("tokenPath")
    if token_path is not None and not isinstance(token_path, str):
        reject("tokenPath must be a string or null")
    context = key.get("context")
    if context is not None and not isinstance(context, dict):
        reject("context must be an object or null")
    assert_no_floats(context, "context")
    return witness_id(cls=key["class"], law_ref=key["lawRef"],
                      token_path=token_path, context=context)


if mode == "compute":
    try:
        key = json.loads(key_json)
    except json.JSONDecodeError as e:
        reject(f"malformed JSON on stdin ({e})")
    print(compute(key))
    sys.exit(0)

# self-test: boat-local cross-implementation conformance vectors
with open(vectors_path, encoding="utf-8") as fh:
    vectors = json.load(fh)
ok = bad = 0
for v in vectors:
    expected = v["witnessId"]
    got = compute({k: v.get(k) for k in ("class", "lawRef", "tokenPath", "context")})
    if got == expected:
        ok += 1
    else:
        bad += 1
        print(f"[FAIL] {v.get('source', '?')}: expected {expected} got {got}")
print(f"[witness-id vectors] ok={ok} bad={bad}")
sys.exit(1 if bad else 0)
PYEOF
