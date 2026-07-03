const WWW_HOST = 'www.aac.sh';
const SPECS_HOST = 'specs.aac.sh';
const DEMO_HOST = 'demo.aac.sh';

const ASSET_PREFIXES = ['/_astro/', '/pagefind/'];
const ASSET_PATHS = new Set(['/favicon.svg', '/logo.svg']);
const SITEMAP_PATHS = new Set(['/sitemap-index.xml', '/sitemap-0.xml']);

function isAssetPath(pathname) {
  return ASSET_PATHS.has(pathname) || ASSET_PREFIXES.some((prefix) => pathname.startsWith(prefix));
}

function isDemoPath(pathname) {
  return pathname === '/fundraise' || pathname.startsWith('/fundraise/');
}

function isSpecPath(pathname) {
  return (
    pathname === '/specs' ||
    pathname.startsWith('/specs/') ||
    pathname === '/circuit' ||
    pathname.startsWith('/circuit/') ||
    pathname === '/registry' ||
    pathname.startsWith('/registry/') ||
    pathname === '/components' ||
    pathname.startsWith('/components/')
  );
}

function redirectTo(url, host, pathname = url.pathname) {
  const target = new URL(url);
  target.hostname = host;
  target.pathname = pathname;
  return Response.redirect(target.toString(), 308);
}

function assetRequest(request, pathname) {
  const url = new URL(request.url);
  url.pathname = pathname;
  return new Request(url.toString(), request);
}

function sameHostAssetRequest(request) {
  const url = new URL(request.url);
  return new Request(url.toString(), request);
}

async function serve(request, env, host, canonicalPathname) {
  const response = await env.ASSETS.fetch(request);
  return rewriteCanonical(response, host, canonicalPathname);
}

async function servePath(request, env, pathname, host, canonicalPathname = pathname) {
  const response = await env.ASSETS.fetch(assetRequest(request, pathname));
  return rewriteCanonical(response, host, canonicalPathname);
}

function rewriteCanonical(response, host, canonicalPathname) {
  const contentType = response.headers.get('content-type') || '';
  if (!contentType.includes('text/html') || typeof HTMLRewriter === 'undefined') {
    return response;
  }

  const canonical = new UrlAttributeRewriter(host, canonicalPathname);
  return new HTMLRewriter()
    .on('link[rel="canonical"]', canonical)
    .on('meta[property="og:url"]', canonical)
    .transform(response);
}

class UrlAttributeRewriter {
  constructor(host, canonicalPathname) {
    this.host = host;
    this.canonicalPathname = canonicalPathname;
  }

  element(element) {
    const attr = element.getAttribute('href') === null ? 'content' : 'href';
    const value = element.getAttribute(attr);
    if (!value) return;

    try {
      const url = new URL(value);
      if (![WWW_HOST, SPECS_HOST, DEMO_HOST].includes(url.hostname)) return;
      url.hostname = this.host;
      if (this.canonicalPathname) url.pathname = this.canonicalPathname;
      element.setAttribute(attr, url.toString());
    } catch {
      // Non-URL attributes are not canonical targets.
    }
  }
}

async function handleWww(request, env, url) {
  if (SITEMAP_PATHS.has(url.pathname)) return sitemapResponse(request, env, WWW_HOST);
  if (isAssetPath(url.pathname)) return env.ASSETS.fetch(sameHostAssetRequest(request));
  if (isDemoPath(url.pathname)) return redirectTo(url, DEMO_HOST, '/');
  if (url.pathname !== '/') return redirectTo(url, SPECS_HOST);
  return serve(request, env, WWW_HOST);
}

async function handleSpecs(request, env, url) {
  if (SITEMAP_PATHS.has(url.pathname)) return sitemapResponse(request, env, SPECS_HOST);
  if (isAssetPath(url.pathname)) return env.ASSETS.fetch(sameHostAssetRequest(request));
  if (isDemoPath(url.pathname)) return redirectTo(url, DEMO_HOST, '/');
  if (url.pathname === '/') return redirectTo(url, SPECS_HOST, '/specs/rfc/');
  return serve(request, env, SPECS_HOST);
}

async function handleDemo(request, env, url) {
  if (SITEMAP_PATHS.has(url.pathname)) return sitemapResponse(request, env, DEMO_HOST);
  if (isAssetPath(url.pathname)) return env.ASSETS.fetch(sameHostAssetRequest(request));
  if (url.pathname === '/') return servePath(request, env, '/fundraise/', DEMO_HOST, '/');
  if (isDemoPath(url.pathname)) return redirectTo(url, DEMO_HOST, '/');
  if (isSpecPath(url.pathname)) return redirectTo(url, SPECS_HOST);
  return redirectTo(url, DEMO_HOST, '/');
}

async function sitemapResponse(request, env, host) {
  const url = new URL(request.url);
  if (url.pathname === '/sitemap-index.xml') {
    return xml(
      `<?xml version="1.0" encoding="UTF-8"?>` +
        `<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">` +
        `<sitemap><loc>https://${host}/sitemap-0.xml</loc></sitemap>` +
        `</sitemapindex>`,
    );
  }

  const paths = await staticSitemapPaths(request, env);
  const publicPaths = pathsForHost(paths, host);
  const urls = publicPaths.map((pathname) => `<url><loc>https://${host}${pathname}</loc></url>`).join('');
  return xml(`<?xml version="1.0" encoding="UTF-8"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">${urls}</urlset>`);
}

async function staticSitemapPaths(request, env) {
  const response = await env.ASSETS.fetch(assetRequest(request, '/sitemap-0.xml'));
  const text = await response.text();
  const matches = text.matchAll(/<loc>https:\/\/(?:www|specs|demo)\.aac\.sh([^<]*)<\/loc>/g);
  return Array.from(matches, (match) => match[1] || '/');
}

function pathsForHost(paths, host) {
  if (host === WWW_HOST) return ['/'];
  if (host === DEMO_HOST) return ['/'];
  return paths.filter((pathname) => pathname !== '/' && !isDemoPath(pathname));
}

function xml(body) {
  return new Response(body, {
    headers: {
      'content-type': 'application/xml; charset=utf-8',
      'cache-control': 'public, max-age=0, must-revalidate',
    },
  });
}

export default {
  fetch(request, env) {
    const url = new URL(request.url);
    const host = url.hostname.toLowerCase();

    if (host === WWW_HOST) return handleWww(request, env, url);
    if (host === SPECS_HOST) return handleSpecs(request, env, url);
    if (host === DEMO_HOST) return handleDemo(request, env, url);
    return serve(request, env, WWW_HOST);
  },
};
