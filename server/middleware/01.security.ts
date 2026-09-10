export default defineEventHandler((event) => {
  const path = getRequestURL(event).pathname
  if (!path.startsWith('/api/')) return

  setHeader(event, 'X-Content-Type-Options', 'nosniff')
  setHeader(event, 'Referrer-Policy', 'strict-origin-when-cross-origin')
  setHeader(event, 'X-Frame-Options', 'DENY')
  setHeader(event, 'Permissions-Policy', 'camera=(), microphone=(), geolocation=()')
  if (process.env.NODE_ENV === 'production') {
    setHeader(event, 'Strict-Transport-Security', 'max-age=31536000; includeSubDomains')
  }

  if (path === '/api/auth/login' || path === '/api/auth/register') {
    assertRateLimit(event, 'auth', { limit: 20, windowMs: 15 * 60_000 })
  } else if (path === '/api/opt-out') {
    assertRateLimit(event, 'opt-out', { limit: 10, windowMs: 60 * 60_000 })
  } else if (path === '/api/payments/claim') {
    assertRateLimit(event, 'claim', { limit: 10, windowMs: 60 * 60_000 })
  } else if (path.startsWith('/api/telegram/webhook')) {
    assertRateLimit(event, 'tg-webhook', { limit: 120, windowMs: 60_000 })
  }
})
