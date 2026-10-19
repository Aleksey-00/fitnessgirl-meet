import { createHash } from 'node:crypto'

const PAY_URL = 'https://auth.robokassa.ru/Merchant/Index.aspx'

export type RobokassaHashAlg = 'md5' | 'sha256' | 'sha512'

export function getRobokassaRuntime() {
  const config = useRuntimeConfig()
  const hashAlg = (
    envStr('ROBOKASSA_HASH_ALG', 'NUXT_ROBOKASSA_HASH_ALG') ||
    String(config.robokassaHashAlg || '').trim() ||
    'md5'
  ).toLowerCase() as RobokassaHashAlg

  return {
    merchantLogin:
      envStr('ROBOKASSA_MERCHANT_LOGIN', 'NUXT_ROBOKASSA_MERCHANT_LOGIN') ||
      String(config.robokassaMerchantLogin || '').trim(),
    password1:
      envStr('ROBOKASSA_PASSWORD1', 'NUXT_ROBOKASSA_PASSWORD1') ||
      String(config.robokassaPassword1 || '').trim(),
    password2:
      envStr('ROBOKASSA_PASSWORD2', 'NUXT_ROBOKASSA_PASSWORD2') ||
      String(config.robokassaPassword2 || '').trim(),
    isTest: /^(1|true)$/i.test(
      envStr('ROBOKASSA_IS_TEST', 'NUXT_ROBOKASSA_IS_TEST') || String(config.robokassaIsTest || '')
    ),
    hashAlg
  }
}

export function robokassaEnabled() {
  const { merchantLogin, password1, password2 } = getRobokassaRuntime()
  return Boolean(merchantLogin && password1 && password2)
}

/** "450.00" — Robokassa requires a dot and 2 decimals in OutSum. */
export function formatOutSum(amountRub: number): string {
  return amountRub.toFixed(2)
}

/** Self-employed (самозанятый) fiscalization receipt for the Init signature + Receipt param. */
export function buildReceiptJson(opts: { name: string; sum: number; quantity?: number }): string {
  return JSON.stringify({
    items: [
      {
        name: opts.name,
        quantity: opts.quantity ?? 1,
        sum: Number(opts.sum.toFixed(2)),
        tax: 'none',
        payment_method: 'full_payment',
        payment_object: 'service'
      }
    ]
  })
}

function hash(value: string, alg: RobokassaHashAlg) {
  return createHash(alg).update(value, 'utf8').digest('hex')
}

/** Init signature: md5(MerchantLogin:OutSum:InvId:Receipt:Password1) — Receipt segment omitted when absent. */
export function buildPaymentSignature(opts: {
  outSum: string
  invId: number
  receiptEncoded?: string
  alg?: RobokassaHashAlg
}) {
  const { merchantLogin, password1, hashAlg } = getRobokassaRuntime()
  const parts = [merchantLogin, opts.outSum, String(opts.invId)]
  if (opts.receiptEncoded) parts.push(opts.receiptEncoded)
  parts.push(password1)
  return hash(parts.join(':'), opts.alg || hashAlg)
}

/** ResultURL signature: md5(OutSum:InvId:Password2) + sorted Shp_* segments when present. */
export function buildResultSignature(opts: {
  outSum: string
  invId: number
  shpParams?: Record<string, string>
  alg?: RobokassaHashAlg
}) {
  const { password2, hashAlg } = getRobokassaRuntime()
  const parts = [opts.outSum, String(opts.invId), password2]
  if (opts.shpParams) {
    for (const key of Object.keys(opts.shpParams).sort((a, b) => a.localeCompare(b))) {
      parts.push(`${key}=${opts.shpParams[key]}`)
    }
  }
  return hash(parts.join(':'), opts.alg || hashAlg)
}

export function verifyResultSignature(opts: {
  outSum: string
  invId: number
  signature: string
  shpParams?: Record<string, string>
}) {
  if (!opts.signature) return false
  const expected = buildResultSignature(opts)
  return expected.toLowerCase() === opts.signature.trim().toLowerCase()
}

/** Absolute Robokassa pay URL (GET query) — Receipt must stay URL-encoded exactly as signed. */
export function buildPaymentUrl(opts: {
  invId: number
  outSum: string
  description: string
  email?: string
  receiptJson?: string
}) {
  const { merchantLogin, isTest } = getRobokassaRuntime()
  const receiptEncoded = opts.receiptJson ? encodeURIComponent(opts.receiptJson) : undefined
  const signature = buildPaymentSignature({ outSum: opts.outSum, invId: opts.invId, receiptEncoded })

  const params: [string, string][] = [
    ['MerchantLogin', merchantLogin],
    ['OutSum', opts.outSum],
    ['InvId', String(opts.invId)],
    ['Description', opts.description],
    ['SignatureValue', signature],
    ['Culture', 'ru'],
    ['Encoding', 'utf-8']
  ]
  if (opts.email) params.push(['Email', opts.email])
  if (isTest) params.push(['IsTest', '1'])

  const query = params.map(([k, v]) => `${k}=${encodeURIComponent(v)}`).join('&')
  const receiptPart = receiptEncoded ? `&Receipt=${receiptEncoded}` : ''
  return `${PAY_URL}?${query}${receiptPart}`
}
