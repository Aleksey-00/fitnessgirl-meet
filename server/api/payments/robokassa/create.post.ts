import { Prisma } from '@prisma/client'

export default defineEventHandler(async (event) => {
  if (!robokassaEnabled()) {
    throw createError({ statusCode: 503, statusMessage: 'Robokassa не настроена' })
  }

  const user = await requireUser(event)
  const payment = getPaymentRuntime()

  // Abandoned checkouts shouldn't block the user forever — drop old unpaid Robokassa claims first.
  await releaseStaleRobokassaClaims(user.id)

  const pending = await prisma.paymentClaim.findFirst({
    where: { userId: user.id, status: 'pending' }
  })

  if (pending && (pending.provider !== 'robokassa' || pending.paidAt)) {
    // Manual claim (or a Robokassa claim already marked paid) — don't race past it.
    throw createError({ statusCode: 409, statusMessage: 'У вас уже есть заявка на проверке' })
  }

  // Reuse the existing unpaid Robokassa claim (not stale, see above) so the user can simply retry
  // payment for the same InvId instead of getting stuck behind the old one.
  let claim = pending
  if (!claim) {
    try {
      claim = await prisma.paymentClaim.create({
        data: {
          userId: user.id,
          amount: payment.priceRub,
          provider: 'robokassa'
        }
      })
    } catch (e) {
      if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002') {
        throw createError({ statusCode: 409, statusMessage: 'У вас уже есть заявка на проверке' })
      }
      throw e
    }
  }

  const outSum = formatOutSum(claim.amount)
  const description = `Подписка Fitnessgirl Meet на ${payment.days} дней`
  const receiptJson = buildReceiptJson({ name: description, sum: claim.amount })

  const paymentUrl = buildPaymentUrl({
    invId: claim.invId,
    outSum,
    description,
    email: user.email,
    receiptJson
  })

  return { id: claim.id, invId: claim.invId, amount: claim.amount, paymentUrl }
})
