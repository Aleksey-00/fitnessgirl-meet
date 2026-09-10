type Bucket = { count: number; resetAt: number }

const buckets = new Map<string, Bucket>()

function clientIp(event: { node?: { req?: { headers?: Record<string, string | string[] | undefined>; socket?: { remoteAddress?: string } } }; headers?: Headers }) {
  const h = event.node?.req?.headers || {}
  const xf = h['x-forwarded-for']
  if (typeof xf === 'string' && xf.length) return xf.split(',')[0]!.trim()
  if (Array.isArray(xf) && xf[0]) return String(xf[0]).split(',')[0]!.trim()
  return event.node?.req?.socket?.remoteAddress || 'unknown'
}

/**
 * Simple in-memory sliding window limiter (per process).
 * Good enough for a single-node VPS; use Redis behind a load balancer later.
 */
export function assertRateLimit(
  event: Parameters<typeof clientIp>[0],
  key: string,
  opts: { limit: number; windowMs: number }
) {
  const id = `${key}:${clientIp(event)}`
  const now = Date.now()
  const bucket = buckets.get(id)
  if (!bucket || now >= bucket.resetAt) {
    buckets.set(id, { count: 1, resetAt: now + opts.windowMs })
    return
  }
  bucket.count += 1
  if (bucket.count > opts.limit) {
    throw createError({
      statusCode: 429,
      statusMessage: 'Слишком много запросов. Подождите немного.'
    })
  }
}

// Opportunistic cleanup
setInterval(() => {
  const now = Date.now()
  for (const [k, v] of buckets) {
    if (now >= v.resetAt) buckets.delete(k)
  }
}, 60_000).unref?.()
