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

  const pending = await prisma.paymentClaim.findFirst({
    where: { userId: user.id, status: 'pending' }
  })
  if (pending) {
    throw createError({ statusCode: 409, statusMessage: 'У вас уже есть заявка на проверке' })
  }

  const claim = await prisma.paymentClaim.create({
    data: {
      userId: user.id,
      amount: payment.priceRub,
      note: parsed.data.note || null
    }
  })

  try {
    await notifyNewPaymentClaim({
      claimId: claim.id,
      email: user.email,
      amount: claim.amount,
      note: claim.note
    })
  } catch (e) {
    console.error('Telegram notify failed', e)
  }

  return { id: claim.id, status: claim.status, amount: claim.amount }
})
