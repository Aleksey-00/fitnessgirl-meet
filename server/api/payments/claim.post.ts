import { Prisma } from '@prisma/client'
import { z } from 'zod'

const bodySchema = z.object({
  note: z.string().max(200).optional()
})

export default defineEventHandler(async (event) => {
  const user = await requireUser(event)
  const payment = getPaymentRuntime()
  const parsed = bodySchema.safeParse((await readBody(event)) || {})
  if (!parsed.success) {
    throw createError({ statusCode: 400, statusMessage: 'Некорректные данные' })
  }

  // Abandoned Robokassa checkouts shouldn't block a manual claim forever.
  await releaseStaleRobokassaClaims(user.id)

  const pending = await prisma.paymentClaim.findFirst({
    where: { userId: user.id, status: 'pending' }
  })
  if (pending) {
    throw createError({ statusCode: 409, statusMessage: 'У вас уже есть заявка на проверке' })
  }

  let claim
  try {
    claim = await prisma.paymentClaim.create({
      data: {
        userId: user.id,
        amount: payment.priceRub,
        note: parsed.data.note || null
      }
    })
  } catch (e) {
    if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002') {
      throw createError({ statusCode: 409, statusMessage: 'У вас уже есть заявка на проверке' })
    }
    throw e
  }

  try {
    const sent = await notifyNewPaymentClaim({
      claimId: claim.id,
      email: user.email,
      amount: claim.amount,
      note: claim.note
    })
    if (sent) {
      await prisma.paymentClaim.update({
        where: { id: claim.id },
        data: { telegramNotifiedAt: new Date() }
      })
    }
  } catch (e) {
    // VPS often cannot reach api.telegram.org — home bridge will notify instead.
    console.error('Telegram notify failed', e)
  }

  return { id: claim.id, status: claim.status, amount: claim.amount }
})
