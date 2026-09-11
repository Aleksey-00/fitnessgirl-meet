import { prisma } from './prisma'

export async function resolvePaymentClaim(claimId: string, action: 'approve' | 'reject') {
  const claim = await prisma.paymentClaim.findUnique({
    where: { id: claimId },
    include: { user: { select: { email: true } } }
  })
  if (!claim) {
    return { ok: false as const, reason: 'not_found' as const }
  }
  if (claim.status !== 'pending') {
    return {
      ok: false as const,
      reason: 'already_processed' as const,
      status: claim.status,
      email: claim.user.email
    }
  }

  if (action === 'reject') {
    const updated = await prisma.paymentClaim.updateMany({
      where: { id: claim.id, status: 'pending' },
      data: { status: 'rejected' }
    })
    if (updated.count === 0) {
      return {
        ok: false as const,
        reason: 'already_processed' as const,
        status: 'approved' as const,
        email: claim.user.email
      }
    }
    return {
      ok: true as const,
      action: 'reject' as const,
      status: 'rejected' as const,
      email: claim.user.email,
      amount: claim.amount
    }
  }

  const days = getPaymentRuntime().days
  const startsAt = new Date()
  const expiresAt = new Date(startsAt.getTime() + days * 24 * 60 * 60 * 1000)

  const result = await prisma.$transaction(async (tx) => {
    const locked = await tx.paymentClaim.updateMany({
      where: { id: claim.id, status: 'pending' },
      data: { status: 'approved' }
    })
    if (locked.count === 0) {
      return { raced: true as const }
    }
    await tx.subscription.create({
      data: {
        userId: claim.userId,
        startsAt,
        expiresAt,
        status: 'active'
      }
    })
    return { raced: false as const }
  })

  if (result.raced) {
    return {
      ok: false as const,
      reason: 'already_processed' as const,
      status: 'approved' as const,
      email: claim.user.email
    }
  }

  return {
    ok: true as const,
    action: 'approve' as const,
    status: 'approved' as const,
    email: claim.user.email,
    amount: claim.amount,
    expiresAt: expiresAt.toISOString()
  }
}
