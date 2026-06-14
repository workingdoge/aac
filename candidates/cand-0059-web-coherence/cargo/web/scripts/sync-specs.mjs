// Generate the site's inputs from the verified paintgun packs:
//   1. design tokens  -> src/styles/tokens.css   (paint build)
//   2. spec pack      -> src/content/docs/specs/* (paint spec-pack -> verify -> emit)
// Content is the verified pack, not hand-copied markdown.
import { execFileSync } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, writeFileSync, copyFileSync, rmSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const webRoot = path.resolve(scriptDir, '..');
const repoRoot = path.resolve(webRoot, '..');
const gen = path.join(webRoot, '.generated');
const stylesDir = path.join(webRoot, 'src/styles');
const docsRoot = path.join(webRoot, 'src/content/docs/specs');

function findPaint() {
  if (process.env.PAINT_BIN && existsSync(process.env.PAINT_BIN)) return process.env.PAINT_BIN;
  try {
    const p = execFileSync('bash', ['-lc', 'command -v paint'], { encoding: 'utf8' }).trim();
    if (p) return p;
  } catch {}
  const fish = '/Users/arj/irai/blackhole/fish-2026-05-16/tools/paintgun/target/release/paint';
  return existsSync(fish) ? fish : null;
}
const paint = findPaint();
if (!paint) throw new Error('paint (paintgun) not found — `nix develop` or set PAINT_BIN');
const run = (args, cwd) => execFileSync(paint, args, { cwd, stdio: ['ignore', 'pipe', 'pipe'], encoding: 'utf8' });

// --- 1. design tokens ---
const tokensOut = path.join(gen, 'tokens');
rmSync(tokensOut, { recursive: true, force: true });
run(['build', './aac.resolver.json', '--contracts', './component-contracts.json', '--target', 'web-css-vars', '--namespace', 'aac', '--out', tokensOut], path.join(repoRoot, 'design'));
run(['verify', path.join(tokensOut, 'ctc.manifest.json'), '--format', 'json'], path.join(repoRoot, 'design'));
mkdirSync(stylesDir, { recursive: true });
copyFileSync(path.join(tokensOut, 'tokens.css'), path.join(stylesDir, 'tokens.css'));
console.log('tokens.css generated from design/ (paint build + verify)');

// --- 2. spec pack ---
const packOut = path.join(gen, 'spec');
rmSync(packOut, { recursive: true, force: true });
run(['spec-pack', path.join(repoRoot, 'sites/ledger/publication.json'), '--out', packOut], repoRoot);
run(['verify-spec-pack', path.join(packOut, 'spec.pack.json'), '--format', 'json'], repoRoot);
const pack = JSON.parse(readFileSync(path.join(packOut, 'spec.pack.json'), 'utf8'));

const slug = (s) => s.toLowerCase().replace(/[^a-z0-9]+/gu, '-').replace(/^-+|-+$/gu, '');
const sourceRoot = path.posix.join('sites/ledger', pack.sourceRoot || 'specs');
const repoBlobRoot = 'https://github.com/workingdoge/aac/blob/main/';
const sourceRoutes = new Map();

const routeForDoc = (doc) => {
  const docSlug = slug(doc.id);
  return docSlug === 'index'
    ? `/specs/${doc.seriesId}/`
    : `/specs/${doc.seriesId}/${docSlug}/`;
};

for (const doc of pack.documents) {
  const rel = path.posix.normalize(doc.sourcePath);
  const route = routeForDoc(doc);
  sourceRoutes.set(rel, route);
  if (path.posix.basename(rel) === 'README.md') {
    const dir = path.posix.dirname(rel);
    sourceRoutes.set(dir, route);
    sourceRoutes.set(`${dir}/`, route);
  }
}

function splitHref(href) {
  const hashAt = href.indexOf('#');
  if (hashAt === -1) return [href, ''];
  return [href.slice(0, hashAt), href.slice(hashAt)];
}

function repoHrefFromSource(sourceRel, target) {
  const sourceDir = path.posix.dirname(sourceRel);
  const resolved = path.posix.normalize(path.posix.join(sourceRoot, sourceDir, target));
  return `${repoBlobRoot}${resolved}`;
}

function rewriteSpecHref(sourceRel, href) {
  if (
    href.startsWith('#') ||
    href.startsWith('/') ||
    /^[a-z][a-z0-9+.-]*:/iu.test(href)
  ) {
    return href;
  }

  const [target, suffix] = splitHref(href);
  if (!target) return href;

  const sourceDir = path.posix.dirname(sourceRel);
  const resolved = path.posix.normalize(path.posix.join(sourceDir, target));
  const candidates = [];
  if (target.endsWith('/')) {
    candidates.push(path.posix.normalize(path.posix.join(resolved, 'README.md')));
    candidates.push(resolved);
    candidates.push(`${resolved}/`);
  } else {
    candidates.push(resolved);
    if (!path.posix.extname(resolved)) {
      candidates.push(path.posix.normalize(path.posix.join(resolved, 'README.md')));
      candidates.push(`${resolved}/`);
    }
  }

  for (const candidate of candidates) {
    const route = sourceRoutes.get(candidate);
    if (route) return `${route}${suffix}`;
  }

  return `${repoHrefFromSource(sourceRel, target)}${suffix}`;
}

function rewriteSpecMarkdownLinks(body, doc) {
  return body.replace(/\]\(([^)\s]+)(\s+"[^"]*")?\)/gu, (_m, href, title = '') => {
    return `](${rewriteSpecHref(doc.sourcePath, href)}${title})`;
  });
}

for (const series of new Set(pack.documents.map((doc) => doc.seriesId))) {
  rmSync(path.join(docsRoot, series), { recursive: true, force: true });
}

for (const doc of pack.documents) {
  const src = readFileSync(path.join(packOut, doc.packPath.file), 'utf8');
  const m = src.match(/^#\s+(.+)\r?\n/u);
  const title = doc.title || (m ? m[1].trim() : doc.id);
  const body = rewriteSpecMarkdownLinks(m ? src.slice(m[0].length).replace(/^\r?\n/u, '') : src, doc);
  const out = path.join(docsRoot, doc.seriesId, `${slug(doc.id)}.md`);
  mkdirSync(path.dirname(out), { recursive: true });
  const note =
    `:::note[Published record — ${doc.status}]\n` +
    `Synced from the verified spec pack. Digest \`${doc.packPath.sha256.slice(0, 23)}…\`.\n:::`;
  const frontmatter = [
    '---',
    `title: ${JSON.stringify(title)}`,
    'editUrl: false',
    'sidebar:',
    `  label: ${JSON.stringify(doc.id)}`,
    ...(typeof doc.order === 'number' ? [`  order: ${doc.order}`] : []),
    '---',
    '',
    note,
    '',
    body,
    '',
  ].join('\n');
  writeFileSync(out, frontmatter, 'utf8');
}
console.log(`Synced ${pack.documents.length} documents into src/content/docs/specs.`);
