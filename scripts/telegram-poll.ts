/**
 * Local fallback: poll Telegram updates when webhook is unavailable.
 * Usage: npm run telegram:poll
 */
import { PrismaClient } from '@prisma/client'

const prisma = new PrismaClient()
const token = process.env.TELEGRAM_BOT_TOKEN || ''
const adminChatId = String(process.env.TELEGRAM_ADMIN_CHAT_ID || '')

if (!token || !adminChatId) {
  console.error('TELEGRAM_BOT_TOKEN and TELEGRAM_ADMIN_CHAT_ID required')
  process.exit(1)
}

async function api(method: string, body?: Record<string, unknown>) {
  const controller = new AbortController()
  const timer = setTimeout(() => controller.abort(), 45_000)
  try {
    const res = await fetch(`https://api.telegram.org/bot${token}/${method}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body || {}),
      signal: controller.signal
    })
    return (await res.json()) as any
  } finally {
    clearTimeout(timer)
  }
}

async function resolve(claimId: string, action: 'approve' | 'reject') {
  const claim = await prisma.paymentClaim.findUnique({
    where: { id: claimId },
    include: { user: { select: { email: true } } }
  })
  if (!claim) return { text: 'Заявка не найдена' }
  if (claim.status !== 'pending') return { text: `Уже: ${claim.status}` }

  if (action === 'reject') {
    const updated = await prisma.paymentClaim.updateMany({
      where: { id: claim.id, status: 'pending' },
      data: { status: 'rejected' }
    })
    if (updated.count === 0) return { text: `Уже обработана` }
    return { text: `❌ Отклонено\nEmail: ${claim.user.email}` }
  }

  const days = Number(process.env.SUBSCRIPTION_DAYS || 30)
  const startsAt = new Date()
  const expiresAt = new Date(startsAt.getTime() + days * 24 * 60 * 60 * 1000)
  const raced = await prisma.$transaction(async (tx) => {
    const locked = await tx.paymentClaim.updateMany({
      where: { id: claim.id, status: 'pending' },
      data: { status: 'approved' }
    })
    if (locked.count === 0) return true
    await tx.subscription.create({
      data: { userId: claim.userId, startsAt, expiresAt, status: 'active' }
    })
    return false
  })
  if (raced) return { text: `Уже обработана` }
  return {
    text: `✅ Подтверждено\nEmail: ${claim.user.email}\nДо: ${expiresAt.toISOString()}`
  }
}

let offset = 0
console.log('Polling Telegram callbacks… Ctrl+C to stop')
console.log(`Admin chat id: ${adminChatId}`)

async function loop() {
  const data = await api('getUpdates', {
    offset,
    timeout: 25,
    allowed_updates: ['callback_query']
  })
  if (!data?.ok) {
    console.error('getUpdates failed:', data?.description || data)
    await new Promise((r) => setTimeout(r, 2000))
    return
  }
  for (const update of data.result || []) {
    offset = update.update_id + 1
    const cb = update.callback_query
    if (!cb) continue
    if (String(cb.message?.chat?.id) !== adminChatId) {
      console.warn('callback from non-admin chat', cb.message?.chat?.id)
      await api('answerCallbackQuery', {
        callback_query_id: cb.id,
        text: 'Нет доступа',
        show_alert: true
      })
      continue
    }
    const m = String(cb.data || '').match(/^(ok|no):(.+)$/)
    if (!m) {
      await api('answerCallbackQuery', {
        callback_query_id: cb.id,
        text: 'Неизвестная команда'
      })
      continue
    }
    const action = m[1] === 'ok' ? 'approve' : 'reject'
    console.log(`handling ${action} for ${m[2]}`)
    const result = await resolve(m[2], action)
    await api('answerCallbackQuery', { callback_query_id: cb.id, text: 'Готово' })
    if (cb.message?.chat?.id && cb.message?.message_id) {
      await api('editMessageText', {
        chat_id: cb.message.chat.id,
        message_id: cb.message.message_id,
        text: result.text
      })
    }
    console.log(result.text.replace(/\n/g, ' | '))
  }
}

async function main() {
  // Drop webhook so polling works locally
  const del = await api('deleteWebhook', { drop_pending_updates: false })
  console.log('deleteWebhook:', del?.ok ? 'ok' : del)
  for (;;) {
    try {
      await loop()
    } catch (e) {
      console.error('poll error:', e instanceof Error ? e.message : e)
      await new Promise((r) => setTimeout(r, 3000))
    }
  }
}

main().finally(() => prisma.$disconnect())
