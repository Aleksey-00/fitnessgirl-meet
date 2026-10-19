export default defineEventHandler(async (event) => {
  const session = readSession(event)
  if (!session) {
    return { user: null, subscribed: false, pendingClaim: null }
  }

  const user = await prisma.user.findUnique({
    where: { id: session.userId },
    select: { id: true, email: true, role: true, gender: true }
  })
  if (!user) {
    return { user: null, subscribed: false, pendingClaim: null }
  }

  const subscribed = await userHasActiveSubscription(user.id)
  const pendingClaimRow = subscribed
    ? null
    : await prisma.paymentClaim.findFirst({
        where: { userId: user.id, status: 'pending' },
        select: { id: true, provider: true, paidAt: true }
      })

  const pendingClaim = pendingClaimRow
    ? {
        id: pendingClaimRow.id,
        provider: pendingClaimRow.provider,
        paidAt: pendingClaimRow.paidAt ? pendingClaimRow.paidAt.toISOString() : null
      }
    : null

  return { user, subscribed, pendingClaim }
})
