export default defineEventHandler(async (event) => {
  const session = readSession(event)
  if (!session) {
    return { user: null, subscribed: false, pendingClaim: false }
  }

  const user = await prisma.user.findUnique({
    where: { id: session.userId },
    select: { id: true, email: true, role: true }
  })
  if (!user) {
    return { user: null, subscribed: false, pendingClaim: false }
  }

  const subscribed = await userHasActiveSubscription(user.id)
  const pendingClaim = subscribed
    ? false
    : Boolean(
        await prisma.paymentClaim.findFirst({
          where: { userId: user.id, status: 'pending' },
          select: { id: true }
        })
      )
  return { user, subscribed, pendingClaim }
})
