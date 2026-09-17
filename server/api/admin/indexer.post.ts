import { persistVkToken, envWritable } from '../../utils/indexerRunner'

function extractToken(raw: string) {
  const s = raw.trim()
  const fromQuery = s.match(/access_token=([^&\s#]+)/i)
  if (fromQuery?.[1]) return decodeURIComponent(fromQuery[1])
  return s
}

export default defineEventHandler(async (event) => {
  await requireAdmin(event)
  assertRateLimit(event, 'admin-indexer', { limit: 60, windowMs: 60 * 60_000 })

  const body = await readBody<{ token?: string }>(event)
  const token = extractToken(String(body?.token || ''))
  if (!token || token.length < 20) {
    throw createError({ statusCode: 400, statusMessage: 'Вставьте VK_ACCESS_TOKEN' })
  }

  const avail = envWritable()
  if (!avail.ok) {
    throw createError({ statusCode: 503, statusMessage: avail.reason || '.env unavailable' })
  }

  persistVkToken(token)

  return {
    ok: true,
    tokenLength: token.length,
    hint: 'Токен сохранён в .env. Запустите на домашнем ПК: ./scripts/run-home-indexer.sh'
  }
})
