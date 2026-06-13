#!/usr/bin/env bash
# eval-self.sh — functional evidence for cand-0002-design-tokens.
#
# Builds the AAC design-token pack with `paint` (paintgun) into a scratch dist,
# re-verifies the CTC envelope offline, witnesses both ledger schemes and the
# recorded pigments (incl. the dark oxblood brick), and probes corrupted input.
# paint located via PAINT_BIN/PATH; honest-skip (exit 75, attested) if absent.
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"
CARGO="$CAND_DIR/cargo"
TRACES="$CAND_DIR/traces"
rm -rf "$TRACES"; mkdir -p "$TRACES"

PAINT="${PAINT_BIN:-}"
[[ -z "$PAINT" ]] && PAINT="$(command -v paint || true)"

build_into() { # SRCDIR OUTDIR  -> paint build (resolver needs a dir-qualified path)
  ( cd "$1" && "$PAINT" build ./aac.resolver.json --contracts ./component-contracts.json \
      --target web-css-vars --namespace aac --out "$2" ); }

check_build() {
  DIST="$(mktemp -d)"
  build_into "$CARGO" "$DIST" || { echo "paint build FAILED"; return 1; }
  [[ -f "$DIST/tokens.css" && -f "$DIST/ctc.manifest.json" ]] || { echo "missing tokens.css / ctc.manifest.json"; return 1; }
  echo "built into $DIST"; ls "$DIST"
}

check_verify() {
  "$PAINT" verify "$DIST/ctc.manifest.json" --format json > "$TRACES/_verify.json" 2>&1 || true
  python3 - "$TRACES/_verify.json" <<'PY'
import json,sys
d=json.load(open(sys.argv[1]))
ok=d.get("ok") is True and d.get("verify",{}).get("ok") is True and d.get("semantics",{}).get("ok") is True
print("verify ok:",d.get("ok"),"verify.ok:",d.get("verify",{}).get("ok"),"semantics.ok:",d.get("semantics",{}).get("ok"))
sys.exit(0 if ok else 1)
PY
}

check_schemes() {
  python3 - "$DIST/tokens.css" <<'PY'
import re,sys
css=open(sys.argv[1]).read()
blocks=dict(re.findall(r':root\[data-scheme="(light|dark)"\]\s*\{([^}]*)\}', css, re.S))
assert set(blocks)=={"light","dark"}, f"scheme blocks: {set(blocks)}"
need=["cream","bond","ink","ink2","navy","oxblood","steel","gold","rule",
      "paperonink","verified","status-recorded","status-sealed","status-exception"]
for sch,body in blocks.items():
    for n in need:
        assert f"--aac-color-{n}:" in body, f"{sch}: missing --aac-color-{n}"
    assert not re.search(r'--aac-[\w-]+:\s*;', body), f"{sch}: empty value"
def val(sch,name):
    m=re.search(rf'--aac-color-{name}:\s*([^;]+);', blocks[sch]); return m.group(1).strip()
assert val("light","cream")!=val("dark","cream"), "cream did not flip"
assert val("light","ink")!=val("dark","ink"), "ink did not flip"
print("both schemes complete; pigments present; paper-becomes-ink (cream & ink differ)")
PY
}

check_pigments() {  # content cross-check against the authored source
  python3 - "$CARGO/tokens/scheme/light.tokens.json" "$CARGO/tokens/scheme/dark.tokens.json" <<'PY'
import json,sys
L=json.load(open(sys.argv[1]))["color"]; D=json.load(open(sys.argv[2]))["color"]
def hx(c,k): return c[k]["$value"]["hex"].lower()
canon={"cream":"#f1ead7","ink":"#17140f","navy":"#1c2a4a","oxblood":"#7e2a22"}
for k,v in canon.items():
    assert hx(L,k)==v, f"light {k}={hx(L,k)} != {v}"
assert hx(D,"oxblood")=="#ad4a33", f"dark oxblood={hx(D,'oxblood')} (must be brick #ad4a33, NOT coral)"
assert hx(D,"oxblood")!="#cc7a6d", "dark oxblood is coral — rejected"
print("recorded pigments canonical; dark oxblood is brick #ad4a33")
PY
}

check_rejection() {  # corrupted token source must fail the build
  local scratch out; scratch="$(mktemp -d)"; cp -R "$CARGO/." "$scratch/"
  head -c 80 "$CARGO/tokens/scheme/light.tokens.json" > "$scratch/tokens/scheme/light.tokens.json"
  out="$(mktemp -d)"
  if build_into "$scratch" "$out" >/dev/null 2>&1; then echo "REJECTION FAILED: corrupted source built"; rm -rf "$scratch" "$out"; return 1; fi
  echo "corrupted token source correctly rejected"; rm -rf "$scratch" "$out"
}

run() { local n="$1" fn="$2" rc; "$fn" > "$TRACES/$n.txt" 2>&1; rc=$?; printf 'loop-eval: %-18s %s (exit=%d)\n' "$n" "$([[ $rc -eq 0 ]] && echo pass || echo FAIL)" "$rc"; return $rc; }

# ---- honest skip if paint is unavailable ----
if [[ -z "$PAINT" || ! -x "$PAINT" ]]; then
  echo "SKIP: paintgun (paint) not found via PAINT_BIN or PATH" > "$TRACES/00-skip.txt"
  printf 'loop-eval: paint unavailable — attested skip\n'
  { printf '{\n  "schema":"boat.eval-self.v0",\n  "candidate":"cand-0002-design-tokens",\n'
    printf '  "evaluated_at":"%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf '  "task":"build+verify the AAC design-token pack (both ledger schemes, recorded pigments, corrupted-input probe)",\n'
    printf '  "verdict":"skip(paint-unavailable)"\n}\n'; } > "$CAND_DIR/scores.json"
  bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES" || true
  exit 75
fi
echo "paint: $PAINT ($("$PAINT" --version 2>/dev/null))" > "$TRACES/00-paint.txt"

fail=0
run 01-build      check_build     || fail=1
run 02-verify     check_verify    || fail=1
run 03-schemes    check_schemes   || fail=1
run 04-pigments   check_pigments  || fail=1
run 05-rejection  check_rejection || fail=1

verdict="pass"; [[ "$fail" -eq 0 ]] || verdict="fail"
{
  printf '{\n  "schema": "boat.eval-self.v0",\n'
  printf '  "candidate": "cand-0002-design-tokens",\n'
  printf '  "evaluated_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '  "task": "build+verify the AAC design-token pack with paint (both ledger schemes, recorded pigments incl. brick oxblood, corrupted-input rejection)",\n'
  printf '  "checks": {\n'
  printf '    "build": "%s",\n'     "$(grep -q 'built into' "$TRACES/01-build.txt" && echo pass || echo fail)"
  printf '    "verify": "%s",\n'    "$(grep -q 'semantics.ok: True' "$TRACES/02-verify.txt" && echo pass || echo fail)"
  printf '    "schemes": "%s",\n'   "$(grep -q 'both schemes complete' "$TRACES/03-schemes.txt" && echo pass || echo fail)"
  printf '    "pigments": "%s",\n'  "$(grep -q 'brick #ad4a33' "$TRACES/04-pigments.txt" && echo pass || echo fail)"
  printf '    "rejection": "%s"\n'  "$(grep -q 'correctly rejected' "$TRACES/05-rejection.txt" && echo pass || echo fail)"
  printf '  },\n'
  printf '  "verdict": "%s"\n' "$verdict"
  printf '}\n'
} > "$CAND_DIR/scores.json"

printf 'loop-eval: verdict=%s\n' "$verdict"
bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES" \
  || { printf 'loop-eval: WARNING attestation failed\n' >&2; exit 1; }
[[ "$verdict" == "pass" ]] || exit 1
