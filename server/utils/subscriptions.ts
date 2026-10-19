import { prisma } from './prisma'

/** Unpaid Robokassa claims older than this are considered abandoned and auto-rejected. */
export const ROBOKASSA_CLAIM_STALE_MS = 45 * 60_000

/**
 * Auto-reject this user's stale (unpaid, abandoned) pending Robokassa claims so a dropped
 * checkout doesn't block the user from paying or submitting a manual claim forever.
 * Only touches `provider='robokassa'` claims that never got a ResultURL callback (`paidAt IS NULL`).
 */
export async function releaseStaleRobokassaClaims(userId: string) {
  const stale = await prisma.paymentClaim.findMany({
    where: {
      userId,
      provider: 'robokassa',
      status: 'pending',
      paidAt: null,
      createdAt: { lt: new Date(Date.now() - ROBOKASSA_CLAIM_STALE_MS) }
    },
    select: { id: true, invId: true }
  })
  if (!stale.length) return
  await prisma.paymentClaim.updateMany({
    where: { id: { in: stale.map((c) => c.id) }, status: 'pending', paidAt: null },
    data: { status: 'rejected' }
  })
  console.warn(
    '[robokassa] auto-rejected stale unpaid claims',
    stale.map((c) => ({ id: c.id, invId: c.invId }))
  )
}

/**
 * Honor a verified Robokassa ResultURL for this claim.
 * Authoritative over local cancel/stale reject: a signed paid callback still grants access
 * even if the user cancelled or the claim timed out before the IPN arrived.
 */
export async function fulfillRobokassaPayment(claimId: string, paidAt = new Date()) {
  const claim = await prisma.paymentClaim.findUnique({
    where: { id: claimId },
    include: { user: { select: { email: true } } }
  })
  if (!claim || claim.provider !== 'robokassa') {
    return { ok: false as const, reason: 'not_found' as const }
  }
  if (claim.status === 'approved' && claim.paidAt) {
    return {
      ok: true as const,
      already: true as const,
      email: claim.user.email,
      amount: claim.amount
    }
  }

  const days = getPaymentRuntime().days
  const startsAt = new Date()
  const expiresAt = new Date(startsAt.getTime() + days * 24 * 60 * 60 * 1000)
  const lateAfterReject = claim.status === 'rejected'

  const result = await prisma.$transaction(async (tx) => {
    const locked = await tx.paymentClaim.updateMany({
      where: {
        id: claim.id,
        provider: 'robokassa',
        status: { in: ['pending', 'rejected'] }
      },
      data: { status: 'approved', paidAt }
    })
    if (locked.count === 0) {
      const current = await tx.paymentClaim.findUnique({
        where: { id: claim.id },
        select: { status: true, paidAt: true }
      })
      return { raced: true as const, status: current?.status ?? claim.status }
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
    if (result.status === 'approved') {
      return {
        ok: true as const,
        already: true as const,
        email: claim.user.email,
        amount: claim.amount
      }
    }
    return {
      ok: false as const,
      reason: 'already_processed' as const,
      status: result.status,
      email: claim.user.email
    }
  }

  if (lateAfterReject) {
    console.warn('[robokassa] late ResultURL honored after reject', {
      claimId: claim.id,
      invId: claim.invId,
      email: claim.user.email
    })
  }

  return {
    ok: true as const,
    already: false as const,
    email: claim.user.email,
    amount: claim.amount,
    expiresAt: expiresAt.toISOString()
  }
}

export async function resolvePaymentClaim(
  claimId: string,
  action: 'approve' | 'reject',
  opts?: { paidAt?: Date }
) {
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
      const current = await prisma.paymentClaim.findUnique({
        where: { id: claim.id },
        select: { status: true }
      })
      return {
        ok: false as const,
        reason: 'already_processed' as const,
        status: current?.status ?? claim.status,
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
      data: { status: 'approved', ...(opts?.paidAt ? { paidAt: opts.paidAt } : {}) }
    })
    if (locked.count === 0) {
      const current = await tx.paymentClaim.findUnique({
        where: { id: claim.id },
        select: { status: true }
      })
      return { raced: true as const, status: current?.status ?? claim.status }
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
      status: result.status,
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
