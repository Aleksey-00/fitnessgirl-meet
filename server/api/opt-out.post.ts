import { z } from 'zod'

const bodySchema = z.object({
  vk: z.string().min(1),
  contact: z.string().optional()
})

function extractVkId(input: string): bigint | null {
  const trimmed = input.trim()
  if (/^\d+$/.test(trimmed)) return BigInt(trimmed)
  const idMatch = trimmed.match(/(?:vk\.(?:com|ru)\/id|vk\.(?:com|ru)\/)(\d+)/i)
  if (idMatch?.[1]) return BigInt(idMatch[1])
  return null
}

export default defineEventHandler(async (event) => {
  const parsed = bodySchema.safeParse(await readBody(event))
  if (!parsed.success) {
    throw createError({ statusCode: 400, statusMessage: 'Укажите VK id или ссылку' })
  }

  const vkId = extractVkId(parsed.data.vk)
  const request = await prisma.optOutRequest.create({
    data: {
      vkId: vkId ?? undefined,
      url: parsed.data.vk,
      contact: parsed.data.contact || null,
      processedAt: vkId ? new Date() : null
    }
  })

  if (vkId) {
    await prisma.profile.updateMany({
      where: { vkId },
      data: { isHidden: true }
    })
  }

  return {
    ok: true,
    id: request.id,
    hidden: Boolean(vkId),
    message: vkId
      ? 'Профиль скрыт из каталога.'
      : 'Заявка принята. Укажите числовой id для мгновенного скрытия или дождитесь обработки.'
  }
})
