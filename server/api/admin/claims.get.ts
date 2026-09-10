export default defineEventHandler(async (event) => {
  await requireAdmin(event)
  const claims = await prisma.paymentClaim.findMany({
    orderBy: { createdAt: 'desc' },
    take: 100,
    include: {
      user: { select: { id: true, email: true } }
    }
  })
  return claims.map((c) => ({
    id: c.id,
    amount: c.amount,
    note: c.note,
    status: c.status,
    createdAt: c.createdAt.toISOString(),
    user: c.user
  }))
})
