export default defineEventHandler((event) => {
  const config = useRuntimeConfig(event)
  const siteUrl = String(config.public.siteUrl || 'http://localhost:3000').replace(/\/$/, '')
  const host = siteUrl.replace(/^https?:\/\//, '')

  const body = [
    'User-agent: *',
    'Allow: /',
    'Disallow: /admin',
    'Disallow: /login',
    'Disallow: /register',
    'Disallow: /api/',
    '',
    'User-agent: Googlebot',
    'Allow: /',
    'Disallow: /admin',
    'Disallow: /login',
    'Disallow: /register',
    'Disallow: /api/',
    '',
    'User-agent: Yandex',
    'Allow: /',
    'Disallow: /admin',
    'Disallow: /login',
    'Disallow: /register',
    'Disallow: /api/',
    '',
    `Host: ${host}`,
    `Sitemap: ${siteUrl}/sitemap.xml`,
    ''
  ].join('\n')

  setHeader(event, 'Content-Type', 'text/plain; charset=utf-8')
  setHeader(event, 'Cache-Control', 'public, max-age=3600')
  return body
})
