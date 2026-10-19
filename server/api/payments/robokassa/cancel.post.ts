export default defineEventHandler(async (event) => {
  const user = await requireUser(event)

  // Self-service cancel: only the caller's own unpaid pending Robokassa claim.
  // A late ResultURL can still re-approve this claim via fulfillRobokassaPayment.
  const pending = await prisma.paymentClaim.findMany({
    where: {
      userId: user.id,
      provider: 'robokassa',
      status: 'pending',
      paidAt: null
    },
    select: { id: true, invId: true }
  })
  if (!pending.length) {
    throw createError({ statusCode: 404, statusMessage: 'Нет активной заявки Robokassa для отмены' })
  }

  await prisma.paymentClaim.updateMany({
    where: { id: { in: pending.map((c) => c.id) }, status: 'pending', paidAt: null },
    data: { status: 'rejected' }
  })
  console.warn(
    '[robokassa] user cancelled unpaid claim(s)',
    pending.map((c) => ({ id: c.id, invId: c.invId, userId: user.id }))
  )

  return { ok: true }
})
