import { z } from 'zod'

const bodySchema = z.object({
  email: z.string().email(),
  // Preferred: SHA-256 hex from the browser (real password not in the body).
  password: z.union([z.string().regex(/^[a-f0-9]{64}$/i), z.string().min(1)]),
  // Optional one-shot bridge for accounts created before digest auth.
  passwordLegacy: z.string().min(1).optional()
})

export default defineEventHandler(async (event) => {
  const parsed = bodySchema.safeParse(await readBody(event))
  if (!parsed.success) {
    throw createError({ statusCode: 400, statusMessage: 'Некорректные данные' })
  }

  const email = parsed.data.email.toLowerCase().trim()
  const digestOrPassword = parsed.data.password
  const legacy = parsed.data.passwordLegacy

  const user = await prisma.user.findUnique({ where: { email } })
  if (!user) {
    throw createError({ statusCode: 401, statusMessage: 'Неверный email или пароль' })
  }

  let matched = await verifyPassword(digestOrPassword, user.passwordHash)
  const allowLegacy =
    process.env.NODE_ENV !== 'production' || process.env.ALLOW_LEGACY_LOGIN === '1'
  if (!matched && legacy && allowLegacy) {
    matched = await verifyPassword(legacy, user.passwordHash)
  }
  if (!matched) {
    throw createError({ statusCode: 401, statusMessage: 'Неверный email или пароль' })
  }

  // Normalize storage to bcrypt(sha256) so later logins need only the digest.
  const digest = /^[a-f0-9]{64}$/i.test(digestOrPassword)
    ? digestOrPassword.toLowerCase()
    : sha256Hex(legacy || digestOrPassword)
  if (!(await verifyPassword(digest, user.passwordHash))) {
    await prisma.user.update({
      where: { id: user.id },
      data: { passwordHash: await hashPassword(digest) }
    })
  }

  if (email === getAdminEmail().toLowerCase() && user.role !== 'admin') {
    await prisma.user.update({ where: { id: user.id }, data: { role: 'admin' } })
    user.role = 'admin'
  }

  setUserSession(event, { id: user.id, email: user.email, role: user.role })
  return { id: user.id, email: user.email, role: user.role }
})
