import { z } from 'zod'

const bodySchema = z.object({
  email: z.string().email(),
  // Client sends SHA-256 hex (or legacy plaintext min 8 during transition)
  password: z.union([z.string().regex(/^[a-f0-9]{64}$/i), z.string().min(8)])
})

export default defineEventHandler(async (event) => {
  const parsed = bodySchema.safeParse(await readBody(event))
  if (!parsed.success) {
    throw createError({ statusCode: 400, statusMessage: 'Некорректные данные' })
  }

  const email = parsed.data.email.toLowerCase().trim()
  const existing = await prisma.user.findUnique({ where: { email } })
  if (existing) {
    throw createError({ statusCode: 409, statusMessage: 'Email уже зарегистрирован' })
  }

  const role = email === getAdminEmail().toLowerCase() ? 'admin' : 'user'
  const passwordHash = await hashPassword(parsed.data.password)

  const user = await prisma.user.create({
    data: { email, passwordHash, role }
  })

  setUserSession(event, { id: user.id, email: user.email, role: user.role })
  return { id: user.id, email: user.email, role: user.role }
})
