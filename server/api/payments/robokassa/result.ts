import type { H3Event } from 'h3'

function pick(params: Record<string, unknown>, name: string): string {
  const key = Object.keys(params).find((k) => k.toLowerCase() === name.toLowerCase())
  return key ? String(params[key]) : ''
}

function shpParamsOf(params: Record<string, unknown>): Record<string, string> | undefined {
  const shp: Record<string, string> = {}
  for (const key of Object.keys(params)) {
    if (/^shp_/i.test(key)) shp[key] = String(params[key])
  }
  return Object.keys(shp).length ? shp : undefined
}

async function readParams(event: H3Event) {
  const query = getQuery(event) as Record<string, unknown>
  if (getMethod(event) === 'GET') return query
  try {
    const body = await readBody(event)
    if (body && typeof body === 'object') return { ...query, ...body }
  } catch {
    /* ignore — fall back to query */
  }
  return query
}

function plainText(event: H3Event, status: number, body: string) {
  setResponseStatus(event, status)
  setHeader(event, 'Content-Type', 'text/plain; charset=utf-8')
  return body
}

export default defineEventHandler(async (event) => {
  const params = await readParams(event)

  const outSum = pick(params, 'OutSum')
  const invId = Number(pick(params, 'InvId'))
  const signature = pick(params, 'SignatureValue')

  if (!outSum || !invId || !signature) {
    return plainText(event, 400, 'bad request')
  }

  const valid = verifyResultSignature({
    outSum,
    invId,
    signature,
    shpParams: shpParamsOf(params)
  })
  if (!valid) {
    return plainText(event, 400, 'bad sign')
  }

  const claim = await prisma.paymentClaim.findUnique({ where: { invId } })
  if (!claim || claim.provider !== 'robokassa') {
    return plainText(event, 400, 'claim not found')
  }

  const outSumNum = Number(outSum.replace(',', '.'))
  if (!Number.isFinite(outSumNum) || Math.abs(outSumNum - claim.amount) > 0.05) {
    return plainText(event, 400, 'amount mismatch')
  }

  // Signed ResultURL is authoritative: even a locally cancelled/stale-rejected claim
  // must still grant access if Robokassa confirms the payment (late IPN race).
  const result = await fulfillRobokassaPayment(claim.id, new Date())
  if (!result.ok && result.reason === 'not_found') {
    return plainText(event, 400, 'claim not found')
  }
  if (!result.ok) {
    // Unexpected non-approved terminal state after a valid signature — ask Robokassa to retry.
    console.error('[robokassa] ResultURL could not fulfill claim', {
      invId,
      claimId: claim.id,
      reason: result.reason,
      status: 'status' in result ? result.status : undefined
    })
    return plainText(event, 500, 'fulfill failed')
  }

  return plainText(event, 200, `OK${invId}`)
})
