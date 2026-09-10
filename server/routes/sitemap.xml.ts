export default defineEventHandler(async (event) => {
  const config = useRuntimeConfig(event)
  const siteUrl = String(config.public.siteUrl || 'http://localhost:3000').replace(/\/$/, '')
  const now = new Date().toISOString()

  const staticPaths = [
    { loc: '/', priority: '1.0', changefreq: 'daily' },
    { loc: '/catalog', priority: '0.9', changefreq: 'hourly' },
    { loc: '/subscribe', priority: '0.8', changefreq: 'weekly' },
    { loc: '/disclaimer', priority: '0.4', changefreq: 'monthly' },
    { loc: '/opt-out', priority: '0.3', changefreq: 'monthly' }
  ]

  const urls = staticPaths
    .map(
      (p) => `  <url>
    <loc>${siteUrl}${p.loc}</loc>
    <lastmod>${now}</lastmod>
    <changefreq>${p.changefreq}</changefreq>
    <priority>${p.priority}</priority>
  </url>`
    )
    .join('\n')

  const xml = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${urls}
</urlset>
`

  setHeader(event, 'Content-Type', 'application/xml; charset=utf-8')
  setHeader(event, 'Cache-Control', 'public, max-age=1800')
  return xml
})
