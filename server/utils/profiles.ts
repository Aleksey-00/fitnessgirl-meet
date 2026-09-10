import { prisma } from './prisma'

export function serializeProfile(profile: {
  id: string
  vkId: bigint
  displayName: string
  age: number | null
  city: string
  photoUrl: string | null
  score: number
  signals: unknown
  fetchedAt: Date
}) {
  const signals = (profile.signals || {}) as Record<string, unknown>
  const tags: string[] = []
  if (signals.sport) tags.push('спорт')
  if (signals.activelyLooking) tags.push('в поиске')

  return {
    id: profile.id,
    vkId: profile.vkId.toString(),
    displayName: profile.displayName,
    age: profile.age,
    city: profile.city,
    photoUrl: profile.photoUrl,
    score: profile.score,
    tags,
    vkUrl: `https://vk.com/id${profile.vkId.toString()}`,
    fetchedAt: profile.fetchedAt.toISOString()
  }
}

export type ProfileCursor = {
  score: number
  id: string
}

export function encodeCursor(c: ProfileCursor): string {
  return Buffer.from(JSON.stringify(c), 'utf8').toString('base64url')
}

export function decodeCursor(raw?: string | null): ProfileCursor | null {
  if (!raw) return null
  try {
    const parsed = JSON.parse(Buffer.from(raw, 'base64url').toString('utf8')) as ProfileCursor
    if (typeof parsed.score !== 'number' || typeof parsed.id !== 'string') return null
    return parsed
  } catch {
    return null
  }
}

export async function listVisibleProfilesPage(opts: {
  limit: number
  cursor?: ProfileCursor | null
}) {
  const limit = Math.min(Math.max(opts.limit, 1), 48)
  const cursor = opts.cursor

  // Catalog: only checked adult female faces that are actively looking
  const ageSafe = {
    isHidden: false,
    age: { gte: 18, lte: 35 },
    photoAgeStatus: 'ok',
    signals: {
      path: ['activelyLooking'],
      equals: true
    }
  } as const

  const where = cursor
    ? {
        ...ageSafe,
        AND: [
          {
            OR: [
              { score: { lt: cursor.score } },
              { score: cursor.score, id: { lt: cursor.id } }
            ]
          }
        ]
      }
    : ageSafe

  const rows = await prisma.profile.findMany({
    where,
    orderBy: [{ score: 'desc' }, { id: 'desc' }],
    take: limit + 1
  })

  const hasMore = rows.length > limit
  const page = hasMore ? rows.slice(0, limit) : rows
  const last = page[page.length - 1]
  const nextCursor =
    hasMore && last
      ? encodeCursor({ score: last.score, id: last.id })
      : null

  const total = await prisma.profile.count({ where: ageSafe })

  return { profiles: page, hasMore, nextCursor, total }
}
