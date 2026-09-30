export default defineEventHandler(async (event) => {
  const config = useRuntimeConfig()
  const previewCount = Number(config.public.freePreviewCount) || 3
  const query = getQuery(event)

  const limitRaw = Number(query.limit ?? 24)
  const limit = Number.isFinite(limitRaw) ? limitRaw : 24
  const cursor = decodeCursor(typeof query.cursor === 'string' ? query.cursor : null)

  const session = readSession(event)
  let subscribed = false
  let viewerGender: string | null = null
  if (session) {
    subscribed = await userHasActiveSubscription(session.userId)
    const user = await prisma.user.findUnique({
      where: { id: session.userId },
      select: { gender: true }
    })
    viewerGender = user?.gender ?? null
  }

  // Optional override (?gender=female|male). Default = opposite of viewer (guests → women).
  const requested = parseCatalogGender(typeof query.gender === 'string' ? query.gender : null)
  const catalogGender: CatalogGender = requested || catalogGenderForViewer(viewerGender)

  // Guests / free users: only first preview page, no infinite scroll past paywall
  if (!subscribed) {
    const { profiles, total } = await listVisibleProfilesPage({
      limit: previewCount,
      cursor: null,
      catalogGender
    })
    return {
      subscribed: false,
      catalogGender,
      profiles: profiles.map((p) => ({
        ...serializeProfile(p),
        vkUrl: null as string | null,
        locked: false
      })),
      hasMore: false,
      nextCursor: null,
      lockedCount: Math.max(0, total - previewCount),
      total
    }
  }

  const { profiles, hasMore, nextCursor, total } = await listVisibleProfilesPage({
    limit,
    cursor,
    catalogGender
  })

  return {
    subscribed: true,
    catalogGender,
    profiles: profiles.map(serializeProfile),
    hasMore,
    nextCursor,
    lockedCount: 0,
    total
  }
})
