#!/usr/bin/env bash
# eval-self.sh — functional evidence for cand-0003-publish-specs.
#
# Builds the AAC spec-publication pack with `paint spec-pack` against a real
# copy of sites/ledger/specs (the paintgun trust root), re-verifies it offline,
# checks completeness, and probes a broken manifest. paint via PAINT_BIN/PATH;
# honest-skip (exit 75, attested) if absent.
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"
CARGO="$CAND_DIR/cargo"
TRACES="$CAND_DIR/traces"
rm -rf "$TRACES"; mkdir -p "$TRACES"
PACKDIR=""

PAINT="${PAINT_BIN:-}"
[[ -z "$PAINT" ]] && PAINT="$(command -v paint || true)"

setup_root() { # MANIFEST -> scratch trust-root with a real specs/ copy
  local s; s="$(mktemp -d)"
  cp -R "$ROOT/sites/ledger/specs" "$s/specs"
  cp "$1" "$s/publication.json"
  printf '%s' "$s"
}

check_pack() {
  local r; r="$(setup_root "$CARGO/publication.json")"
  PACKDIR="$r/dist-spec"
  "$PAINT" spec-pack "$r/publication.json" --out "$PACKDIR" || { echo "spec-pack FAILED"; return 1; }
  [[ -f "$PACKDIR/spec.pack.json" && -f "$PACKDIR/spec.index.json" ]] || { echo "missing spec.pack.json / spec.index.json"; return 1; }
  echo "packed -> $PACKDIR"; ls "$PACKDIR"
}

check_verify() {
  "$PAINT" verify-spec-pack "$PACKDIR/spec.pack.json" --format json > "$TRACES/_verify.json" 2>&1 || true
  python3 - "$TRACES/_verify.json" <<'PY'
import json,sys
d=json.load(open(sys.argv[1]))
print("ok:",d.get("ok"),"checkedDocuments:",d.get("checkedDocuments"),"errors:",d.get("errors"))
sys.exit(0 if d.get("ok") is True and d.get("checkedDocuments")==11 else 1)
PY
}

check_complete() {
  python3 - "$PACKDIR/spec.pack.json" <<'PY'
import json,sys
d=json.load(open(sys.argv[1]))
ids=set()
for doc in d.get("documents",[]):
    ids.add(doc.get("id"))
# fall back to index/series shape if documents is empty
if not ids:
    for s in d.get("index",{}).get("series",[]):
        for doc in s.get("documents",[]): ids.add(doc.get("id"))
want={"index","PACI","FACT","PROOF","REG","NET","NAME","DATA","SESS","OTC","R1"}
missing=want-ids
print("doc ids:",sorted(ids))
assert not missing, f"missing documents: {missing}"
print("all 11 documents present")
PY
}

check_rejection() {  # a manifest pointing at a missing source must fail
  local s; s="$(mktemp -d)"; cp -R "$ROOT/sites/ledger/specs" "$s/specs"
  python3 - "$CARGO/publication.json" "$s/publication.json" <<'PY'
import json,sys
m=json.load(open(sys.argv[1]))
m["series"][0]["documents"][0]["path"]="does-not-exist.md"  # break the index doc
json.dump(m,open(sys.argv[2],"w"))
PY
  if "$PAINT" spec-pack "$s/publication.json" --out "$s/dist" >/dev/null 2>&1; then
    echo "REJECTION FAILED: broken manifest packed"; rm -rf "$s"; return 1
  fi
  echo "broken manifest (missing source) correctly rejected"; rm -rf "$s"
}

run() { local n="$1" fn="$2" rc; "$fn" > "$TRACES/$n.txt" 2>&1; rc=$?; printf 'loop-eval: %-18s %s (exit=%d)\n' "$n" "$([[ $rc -eq 0 ]] && echo pass || echo FAIL)" "$rc"; return $rc; }

if [[ -z "$PAINT" || ! -x "$PAINT" ]]; then
  echo "SKIP: paintgun (paint) not found via PAINT_BIN or PATH" > "$TRACES/00-skip.txt"
  printf 'loop-eval: paint unavailable — attested skip\n'
  { printf '{\n  "schema":"boat.eval-self.v0",\n  "candidate":"cand-0003-publish-specs",\n'
    printf '  "evaluated_at":"%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf '  "task":"spec-pack + verify-spec-pack the AAC RFC suite (11 documents)",\n'
    printf '  "verdict":"skip(paint-unavailable)"\n}\n'; } > "$CAND_DIR/scores.json"
  bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES" || true
  exit 75
fi
echo "paint: $PAINT ($("$PAINT" --version 2>/dev/null))" > "$TRACES/00-paint.txt"

fail=0
run 01-pack       check_pack       || fail=1
run 02-verify     check_verify     || fail=1
run 03-complete   check_complete   || fail=1
run 04-rejection  check_rejection  || fail=1

verdict="pass"; [[ "$fail" -eq 0 ]] || verdict="fail"
{
  printf '{\n  "schema": "boat.eval-self.v0",\n'
  printf '  "candidate": "cand-0003-publish-specs",\n'
  printf '  "evaluated_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '  "task": "spec-pack + verify-spec-pack the AAC RFC suite over sites/ledger/specs (11 documents), completeness + broken-manifest rejection",\n'
  printf '  "checks": {\n'
  printf '    "pack": "%s",\n'       "$(grep -q 'packed ->' "$TRACES/01-pack.txt" && echo pass || echo fail)"
  printf '    "verify": "%s",\n'     "$(grep -q 'checkedDocuments: 11' "$TRACES/02-verify.txt" && echo pass || echo fail)"
  printf '    "complete": "%s",\n'   "$(grep -q 'all 11 documents present' "$TRACES/03-complete.txt" && echo pass || echo fail)"
  printf '    "rejection": "%s"\n'   "$(grep -q 'correctly rejected' "$TRACES/04-rejection.txt" && echo pass || echo fail)"
  printf '  },\n'
  printf '  "verdict": "%s"\n' "$verdict"
  printf '}\n'
} > "$CAND_DIR/scores.json"

printf 'loop-eval: verdict=%s\n' "$verdict"
bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES" \
  || { printf 'loop-eval: WARNING attestation failed\n' >&2; exit 1; }
[[ "$verdict" == "pass" ]] || exit 1
