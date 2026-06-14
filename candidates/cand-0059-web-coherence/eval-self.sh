#!/usr/bin/env bash
# eval-self.sh -- functional evidence for cand-0059-web-coherence.
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"
CARGO="$CAND_DIR/cargo"
TRACES="$CAND_DIR/traces"
WORK="$(mktemp -d /private/tmp/aac-web-coherence.XXXXXX)"
rm -rf "$TRACES"; mkdir -p "$TRACES"

NODE_BIN="${NODE_BIN:-/Users/arj/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node}"
if [[ ! -x "$NODE_BIN" ]]; then
  NODE_BIN="$(command -v node || true)"
fi
WEB_NODE_MODULES="$ROOT/web/node_modules"
if [[ ! -d "$WEB_NODE_MODULES/astro" && -d "/Users/arj/irai/aac/web/node_modules/astro" ]]; then
  WEB_NODE_MODULES="/Users/arj/irai/aac/web/node_modules"
fi

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

apply_landing() {
  while IFS=$'\t' read -r src dst _; do
    [[ -n "$src" ]] || continue
    [[ "$src" == \#* ]] && continue
    mkdir -p "$(dirname "$WORK/$dst")"
    cp "$CAND_DIR/$src" "$WORK/$dst"
  done < "$CAND_DIR/LANDING"
}

prepare_overlay() {
  mkdir -p "$WORK/web"
  cp "$ROOT/web/package.json" "$WORK/web/package.json"
  [[ -f "$ROOT/web/bun.lock" ]] && cp "$ROOT/web/bun.lock" "$WORK/web/bun.lock"
  cp -R "$ROOT/web/scripts" "$WORK/web/scripts"
  cp -R "$ROOT/web/src" "$WORK/web/src"
  cp -R "$ROOT/web/public" "$WORK/web/public"
  cp -R "$ROOT/sites" "$WORK/sites"
  ln -s "$ROOT/design" "$WORK/design"
  if [[ -d "$WEB_NODE_MODULES" ]]; then
    cp -cR "$WEB_NODE_MODULES" "$WORK/web/node_modules" 2>/dev/null \
      || cp -R "$WEB_NODE_MODULES" "$WORK/web/node_modules"
  fi
  apply_landing
}

paint_bin() {
  if [[ -n "${PAINT_BIN:-}" && -x "${PAINT_BIN:-}" ]]; then
    printf '%s\n' "$PAINT_BIN"; return 0
  fi
  if command -v paint >/dev/null 2>&1; then
    command -v paint; return 0
  fi
  if [[ -x /Users/arj/irai/blackhole/fish-2026-05-16/tools/paintgun/target/release/paint ]]; then
    printf '%s\n' /Users/arj/irai/blackhole/fish-2026-05-16/tools/paintgun/target/release/paint
    return 0
  fi
  find /nix/store -maxdepth 4 -path '*/bin/paint' -type f 2>/dev/null | sort | head -1
}

check_publication() {
  "$NODE_BIN" - "$CARGO/sites/ledger/publication.json" <<'NODE'
const fs = require('fs');
const publication = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const series = new Map(publication.series.map((s) => [s.id, s]));
for (const id of ['rfc', 'applications', 'profiles', 'registers']) {
  if (!series.has(id)) throw new Error(`missing series ${id}`);
}
const apps = new Set(series.get('applications').documents.map((d) => d.id));
for (const id of ['index', 'BCC-1', 'EVENT-COMPLETE-1', 'VNET-1', 'FUNDRAISE-CLEARING-1']) {
  if (!apps.has(id)) throw new Error(`missing application ${id}`);
}
const profiles = new Set(series.get('profiles').documents.map((d) => d.id));
for (const id of ['index', 'SPARSE-CELLS-1', 'VNET-BN254-G1-1', 'PEDERSEN-VECTOR-1']) {
  if (!profiles.has(id)) throw new Error(`missing profile ${id}`);
}
NODE
  echo "publication manifest exposes applications and profiles"
}

check_curated_docs() {
  local bad=0
  grep -q "Start here" "$CARGO/web/astro.config.mjs" || { echo "sidebar missing Start here"; bad=1; }
  grep -q "Application targets" "$CARGO/web/astro.config.mjs" || { echo "sidebar missing Application targets"; bad=1; }
  grep -q "Profiles" "$CARGO/web/astro.config.mjs" || { echo "sidebar missing Profiles"; bad=1; }
  grep -q "Open the fundraise demo" "$CARGO/web/src/content/docs/index.mdx" || { echo "home missing demo action"; bad=1; }
  grep -q "link: /specs/rfc/" "$CARGO/web/src/content/docs/index.mdx" || { echo "home missing fixed RFC route"; bad=1; }
  ! grep -q "/specs/rfc/index/" "$CARGO/web/src/content/docs/index.mdx" || { echo "home still links stale RFC index route"; bad=1; }
  ! grep -q "/design/0001-bvr-clearing-kernel/" "$CARGO/web/src/content/docs/components.mdx" || { echo "components still links unpublished design note"; bad=1; }
  grep -q "/specs/applications/vnet-1/" "$CARGO/web/src/content/docs/components.mdx" || { echo "components missing VNET link"; bad=1; }
  grep -q "/specs/profiles/sparse-cells-1/" "$CARGO/web/src/content/docs/components.mdx" || { echo "components missing SPARSE-CELLS link"; bad=1; }
  grep -q "/specs/applications/fundraise-clearing-1/" "$CARGO/web/src/content/docs/fundraise.mdx" || { echo "fundraise missing target map"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "curated docs and sidebar use current stack routes"
}

check_build_and_links() {
  [[ -x "$NODE_BIN" ]] || { echo "node unavailable"; return 1; }
  [[ -d "$WEB_NODE_MODULES/astro" ]] || { echo "web node_modules unavailable"; return 1; }
  local PAINT
  PAINT="$(paint_bin)"
  [[ -n "$PAINT" && -x "$PAINT" ]] || { echo "paint unavailable"; return 1; }

  prepare_overlay
  (
    cd "$WORK/web" &&
      PAINT_BIN="$PAINT" "$NODE_BIN" scripts/sync-specs.mjs &&
      ASTRO_TELEMETRY_DISABLED=1 "$NODE_BIN" ./node_modules/astro/astro.js build
  ) > "$TRACES/build.txt" 2>&1 || { echo "astro build FAILED"; tail -40 "$TRACES/build.txt"; return 1; }

  for f in \
    "$WORK/web/dist/specs/applications/index.html" \
    "$WORK/web/dist/specs/applications/bcc-1/index.html" \
    "$WORK/web/dist/specs/applications/vnet-1/index.html" \
    "$WORK/web/dist/specs/applications/fundraise-clearing-1/index.html" \
    "$WORK/web/dist/specs/profiles/index.html" \
    "$WORK/web/dist/specs/profiles/sparse-cells-1/index.html" \
    "$WORK/web/dist/specs/profiles/pedersen-vector-1/index.html"; do
    [[ -f "$f" ]] || { echo "missing built route: ${f#$WORK/web/dist/}"; return 1; }
  done

  "$NODE_BIN" - "$WORK/web/dist" <<'NODE' > "$TRACES/link-crawl.json"
const fs = require('fs');
const path = require('path');
const root = process.argv[2];
const files = [];
function walk(dir) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(p);
    else if (entry.name.endsWith('.html')) files.push(p);
  }
}
walk(root);
const missing = [];
let links = 0;
for (const file of files) {
  const html = fs.readFileSync(file, 'utf8');
  for (const match of html.matchAll(/\s(?:href|src)=['"]([^'"]+)['"]/g)) {
    const raw = match[1];
    if (raw.startsWith('#') || raw.startsWith('http:') || raw.startsWith('https:') || raw.startsWith('mailto:') || raw.startsWith('data:')) continue;
    links += 1;
    const clean = raw.split('#')[0].split('?')[0];
    if (!clean) continue;
    let target = clean.startsWith('/')
      ? path.join(root, clean)
      : path.join(path.dirname(file), clean);
    if (clean.endsWith('/')) target = path.join(target, 'index.html');
    if (!path.extname(target)) target = path.join(target, 'index.html');
    if (!fs.existsSync(target)) missing.push({ file: path.relative(root, file), href: raw, target: path.relative(root, target) });
  }
}
console.log(JSON.stringify({ htmlFiles: files.length, links, missing }, null, 2));
if (missing.length) process.exit(1);
NODE
  [[ "$?" -eq 0 ]] || { echo "internal link crawl found missing targets"; cat "$TRACES/link-crawl.json"; return 1; }
  grep -q "page(s) built" "$TRACES/build.txt" || { echo "build completion line missing"; return 1; }
  echo "astro build OK; applications/profiles routes built; internal link crawl clean"
}

check_generated_rewrites() {
  [[ -f "$WORK/web/src/content/docs/specs/rfc/index.md" ]] || { echo "overlay not prepared"; return 1; }
  local bad=0
  grep -q "/specs/profiles/" "$WORK/web/src/content/docs/specs/rfc/index.md" || { echo "RFC index profile directory was not rewritten"; bad=1; }
  grep -q "/specs/profiles/sparse-cells-1/" "$WORK/web/src/content/docs/specs/rfc/index.md" || { echo "RFC index SPARSE-CELLS link was not rewritten"; bad=1; }
  grep -q "/specs/applications/bcc-1/" "$WORK/web/src/content/docs/specs/applications/index.md" || { echo "applications index BCC link was not rewritten"; bad=1; }
  grep -q "/specs/profiles/vnet-bn254-g1-1/" "$WORK/web/src/content/docs/specs/applications/vnet-1.md" || { echo "VNET profile link was not rewritten"; bad=1; }
  grep -q "https://github.com/workingdoge/aac/blob/main/sites/ledger/specs/applications/vectors/VNET-LINK-REF-1.json" "$WORK/web/src/content/docs/specs/applications/vnet-1.md" || { echo "VNET fixture link was not externalized"; bad=1; }
  [[ "$bad" -eq 0 ]] && echo "generated spec markdown rewrites local pages and externalizes fixtures"
}

run() {
  local n="$1" fn="$2" rc
  "$fn" > "$TRACES/$n.txt" 2>&1
  rc=$?
  printf 'loop-eval: %-18s %s (exit=%d)\n' "$n" "$([[ $rc -eq 0 ]] && echo pass || echo FAIL)" "$rc"
  return $rc
}

fail=0
run 01-publication check_publication || fail=1
run 02-curated-docs check_curated_docs || fail=1
run 03-build-links check_build_and_links || fail=1
run 04-rewrites check_generated_rewrites || fail=1

cat > "$CAND_DIR/scores.json" <<JSON
{
  "schema": "boat.eval-self.v0",
  "candidate": "cand-0059-web-coherence",
  "evaluated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "task": "Repair web site coherence by publishing missing application/profile docs, fixing stale links, and reorganizing navigation.",
  "checks": {
    "publication": "$([[ $fail -eq 0 ]] && echo pass || echo fail)",
    "curated_docs": "$([[ $fail -eq 0 ]] && echo pass || echo fail)",
    "build_links": "$([[ $fail -eq 0 ]] && echo pass || echo fail)",
    "rewrites": "$([[ $fail -eq 0 ]] && echo pass || echo fail)"
  },
  "verdict": "$([[ $fail -eq 0 ]] && echo pass || echo fail)"
}
JSON

bash "$ROOT/tools/eval/attest.sh" write "$CAND_DIR/scores.json" "$CAND_DIR/eval-self.sh" "$TRACES"
exit "$fail"
