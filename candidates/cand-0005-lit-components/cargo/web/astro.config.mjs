import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

// American Accounting Company — the spec site. Content syncs from the verified
// paintgun spec-publication pack (scripts/sync-specs.mjs); the look is the AAC
// modernist identity, themed over Starlight from the design/ tokens.
export default defineConfig({
  site: 'https://specs.aac.sh',
  integrations: [
    starlight({
      title: 'American Accounting Company',
      tagline: 'Instruments for network capital.',
      description:
        'Proof-native double-entry accounting — records that balance, trust that endures.',
      logo: { src: './src/assets/logo.svg', replacesTitle: false },
      customCss: ['./src/styles/tokens.css', './src/styles/custom.css'],
      head: [
        {
          tag: 'script',
          content:
            "const s=()=>{document.documentElement.dataset.scheme=document.documentElement.dataset.theme==='dark'?'dark':'light';};s();new MutationObserver(s).observe(document.documentElement,{attributes:true,attributeFilter:['data-theme']});",
        },
        { tag: 'link', attrs: { rel: 'preconnect', href: 'https://fonts.googleapis.com' } },
        { tag: 'link', attrs: { rel: 'preconnect', href: 'https://fonts.gstatic.com', crossorigin: true } },
        {
          tag: 'link',
          attrs: {
            rel: 'stylesheet',
            href: 'https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=IBM+Plex+Mono:wght@400;500;600&display=swap',
          },
        },
      ],
      lastUpdated: true,
      pagination: true,
      tableOfContents: { minHeadingLevel: 2, maxHeadingLevel: 4 },
      sidebar: [
        { label: 'The standard', items: ['index', 'components'] },
        { label: 'RFC suite', autogenerate: { directory: 'specs/rfc' } },
        { label: 'Registers', autogenerate: { directory: 'specs/registers' } },
      ],
    }),
  ],
});
