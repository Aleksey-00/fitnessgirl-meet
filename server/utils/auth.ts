import type { H3Event } from 'h3'
import { createError, getCookie, setCookie, deleteCookie, getRequestHeader } from 'h3'
import { createHash, createHmac, timingSafeEqual } from 'node:crypto'
import bcrypt from 'bcryptjs'
import { prisma } from './prisma'

const COOKIE_NAME = 'fg_session'
const SESSION_DAYS = 30

type SessionPayload = {
  userId: string
  email: string
  role: 'user' | 'admin'
  exp: number
}

function getSecret() {
  const config = useRuntimeConfig()
  return config.sessionPassword || 'dev-session-password-min-32-chars!!'
}

function cookieSecure(event: H3Event) {
  if (process.env.NODE_ENV === 'production') return true
  const proto = getRequestHeader(event, 'x-forwarded-proto')
  return proto === 'https'
}

function cookieOpts(event: H3Event) {
  return {
    httpOnly: true,
    sameSite: 'lax' as const,
    path: '/',
    secure: cookieSecure(event),
    maxAge: 60 * 60 * 24 * SESSION_DAYS
  }
}

function sign(payload: SessionPayload): string {
  const body = Buffer.from(JSON.stringify(payload)).toString('base64url')
  const sig = createHmac('sha256', getSecret()).update(body).digest('base64url')
  return `${body}.${sig}`
}

function verify(token: string): SessionPayload | null {
  const [body, sig] = token.split('.')
  if (!body || !sig) return null
  const expected = createHmac('sha256', getSecret()).update(body).digest('base64url')
  const a = Buffer.from(sig)
  const b = Buffer.from(expected)
  if (a.length !== b.length || !timingSafeEqual(a, b)) return null
  try {
    const payload = JSON.parse(Buffer.from(body, 'base64url').toString('utf8')) as SessionPayload
    if (!payload.exp || Date.now() > payload.exp) return null
    return payload
  } catch {
    return null
  }
}

/** SHA-256 hex — same as browser Web Crypto digest used by the login form. */
export function sha256Hex(value: string) {
  return createHash('sha256').update(value, 'utf8').digest('hex')
}

function normalizePasswordMaterial(passwordOrDigest: string) {
  const raw = passwordOrDigest.trim()
  // Client sends SHA-256 hex so the real password never appears in the request body.
  if (/^[a-f0-9]{64}$/i.test(raw)) return raw.toLowerCase()
  return sha256Hex(raw)
}

export async function hashPassword(passwordOrDigest: string) {
  return bcrypt.hash(normalizePasswordMaterial(passwordOrDigest), 12)
}

export async function verifyPassword(passwordOrDigest: string, hash: string) {
  const digest = normalizePasswordMaterial(passwordOrDigest)
  if (await bcrypt.compare(digest, hash)) return true
  // Legacy accounts: bcrypt(plaintext). Only works when plaintext is still sent.
  if (
    !/^[a-f0-9]{64}$/i.test(passwordOrDigest) &&
    (await bcrypt.compare(passwordOrDigest, hash))
  ) {
    return true
  }
  return false
}

/** After a successful legacy plaintext login, upgrade stored hash to digest-based. */
export async function upgradePasswordHashIfNeeded(
  userId: string,
  passwordOrDigest: string,
  currentHash: string
) {
  const digest = normalizePasswordMaterial(passwordOrDigest)
  if (await bcrypt.compare(digest, currentHash)) return
  if (await bcrypt.compare(passwordOrDigest, currentHash)) {
    await prisma.user.update({
      where: { id: userId },
      data: { passwordHash: await bcrypt.hash(digest, 12) }
    })
  }
}

export function setUserSession(event: H3Event, user: { id: string; email: string; role: 'user' | 'admin' }) {
  const token = sign({
    userId: user.id,
    email: user.email,
    role: user.role,
    exp: Date.now() + 1000 * 60 * 60 * 24 * SESSION_DAYS
  })
  setCookie(event, COOKIE_NAME, token, cookieOpts(event))
}

export function clearUserSession(event: H3Event) {
  deleteCookie(event, COOKIE_NAME, {
    path: '/',
    httpOnly: true,
    sameSite: 'lax',
    secure: cookieSecure(event)
  })
}

export function readSession(event: H3Event): SessionPayload | null {
  const token = getCookie(event, COOKIE_NAME)
  if (!token) return null
  return verify(token)
}

export async function requireUser(event: H3Event) {
  const session = readSession(event)
  if (!session) {
    throw createError({ statusCode: 401, statusMessage: 'Требуется вход' })
  }
  const user = await prisma.user.findUnique({ where: { id: session.userId } })
  if (!user) {
    clearUserSession(event)
    throw createError({ statusCode: 401, statusMessage: 'Сессия недействительна' })
  }
  return user
}

export async function requireAdmin(event: H3Event) {
  const user = await requireUser(event)
  if (user.role !== 'admin') {
    throw createError({ statusCode: 403, statusMessage: 'Нет доступа' })
  }
  return user
}

export async function userHasActiveSubscription(userId: string) {
  const sub = await prisma.subscription.findFirst({
    where: {
      userId,
      status: 'active',
      expiresAt: { gt: new Date() }
    },
    orderBy: { expiresAt: 'desc' }
  })
  return Boolean(sub)
}
