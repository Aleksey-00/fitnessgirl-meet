import { z } from 'zod'

const bodySchema = z.object({
  claimId: z.string().min(1),
  action: z.enum(['approve', 'reject'])
})

export default defineEventHandler(async (event) => {
  await requireAdmin(event)
  const parsed = bodySchema.safeParse(await readBody(event))
  if (!parsed.success) {
    throw createError({ statusCode: 400, statusMessage: 'Некорректные данные' })
  }

  const result = await resolvePaymentClaim(parsed.data.claimId, parsed.data.action)
  if (!result.ok && result.reason === 'not_found') {
    throw createError({ statusCode: 404, statusMessage: 'Заявка не найдена' })
  }
  if (!result.ok && result.reason === 'already_processed') {
    throw createError({ statusCode: 409, statusMessage: 'Заявка уже обработана' })
  }

  if (result.ok && result.action === 'approve') {
    return {
      id: parsed.data.claimId,
      status: result.status,
      expiresAt: result.expiresAt
    }
  }

  return { id: parsed.data.claimId, status: result.ok ? result.status : 'rejected' }
})
