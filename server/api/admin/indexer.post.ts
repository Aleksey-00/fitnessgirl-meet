import {
  indexerAvailable,
  persistVkToken,
  runIndexerStream,
  type IndexerMode
} from '../../utils/indexerRunner'

function extractToken(raw: string) {
  const s = raw.trim()
  const fromQuery = s.match(/access_token=([^&\s]+)/i)
  if (fromQuery?.[1]) return decodeURIComponent(fromQuery[1])
  return s
}

export default defineEventHandler(async (event) => {
  await requireAdmin(event)
  assertRateLimit(event, 'admin-indexer', { limit: 5, windowMs: 60 * 60_000 })

  const body = await readBody<{
    token?: string
    limit?: number
    mode?: IndexerMode
    saveToken?: boolean
  }>(event)

  const token = extractToken(String(body?.token || ''))
  if (!token || token.length < 20) {
    throw createError({ statusCode: 400, statusMessage: 'Вставьте VK_ACCESS_TOKEN' })
  }

  const mode: IndexerMode = body?.mode === 'full' ? 'full' : 'daily'
  const defaultLimit = mode === 'daily' ? 100 : 500
  const maxLimit = mode === 'daily' ? 300 : 2000
  const limit = Math.min(Math.max(Number(body?.limit) || defaultLimit, 1), maxLimit)

  const avail = indexerAvailable()
  if (!avail.ok) {
    throw createError({ statusCode: 503, statusMessage: avail.reason || 'Indexer unavailable' })
  }

  if (body?.saveToken) {
    persistVkToken(token)
  }

  setHeader(event, 'Content-Type', 'text/plain; charset=utf-8')
  setHeader(event, 'Cache-Control', 'no-cache, no-transform')
  setHeader(event, 'X-Accel-Buffering', 'no')

  const stream = new ReadableStream({
    async start(controller) {
      const enc = new TextEncoder()
      const write = (line: string) => {
        controller.enqueue(enc.encode(`${line}\n`))
      }
      write(`# start mode=${mode} limit=${limit} saveToken=${Boolean(body?.saveToken)}`)
      try {
        const code = await runIndexerStream({
          token,
          mode,
          limit,
          onLine: write
        })
        write(`# done exit=${code}`)
      } catch (e: any) {
        write(`# error ${e?.statusMessage || e?.message || String(e)}`)
      } finally {
        controller.close()
      }
    }
  })

  return sendStream(event, stream)
})
