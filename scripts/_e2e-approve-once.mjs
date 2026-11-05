import { PrismaClient } from '@prisma/client'

const prisma = new PrismaClient()
const claimId = process.env.CLAIM_ID
const days = Number(process.env.SUBSCRIPTION_DAYS || 30)

const rows = await prisma.$queryRaw`
  SELECT c.id, c."userId", c.status, u.email
  FROM "PaymentClaim" c
  JOIN "User" u ON u.id = c."userId"
  WHERE c.id = ${claimId}
  LIMIT 1`
const claim = rows[0]
if (!claim || claim.status !== 'pending') {
  console.error('bad claim', claim)
  process.exit(1)
}
const startsAt = new Date()
const expiresAt = new Date(startsAt.getTime() + days * 86400000)
const subId = 'c' + Date.now().toString(36) + Math.random().toString(36).slice(2, 10)
await prisma.$transaction(async (tx) => {
  const locked = Number(
    await tx.$executeRaw`
      UPDATE "PaymentClaim"
      SET status = 'approved', "updatedAt" = NOW()
      WHERE id = ${claim.id} AND status = 'pending'`
  )
  if (locked < 1) throw new Error('race')
  await tx.$executeRaw`
    INSERT INTO "Subscription" (id, "userId", "startsAt", "expiresAt", status, "createdAt")
    VALUES (${subId}, ${claim.userId}, ${startsAt}, ${expiresAt}, CAST('active' AS "SubscriptionStatus"), NOW())`
})
console.log('APPROVED', claim.email, expiresAt.toISOString().slice(0, 10))
await prisma.$disconnect()
