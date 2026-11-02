/**
 * Home Telegram bridge: notify pending claims + poll approve/reject callbacks.
 * Use when the VPS cannot reach api.telegram.org (or Telegram cannot reach the VPS webhook).
 *
 * Prefer: ./scripts/run-home-telegram.sh (or systemd unit fg-telegram-bridge)
 *
 * Approve/reject use raw SQL so an older tools/indexer Prisma client still works
 * after PaymentClaim schema changes (invId, provider, …).
 */
import { PrismaClient } from '@prisma/client'

let prisma = new PrismaClient()
const token = (process.env.TELEGRAM_BOT_TOKEN || '').trim()
const adminChatId = String(process.env.TELEGRAM_ADMIN_CHAT_ID || '').trim()

if (!token || !adminChatId) {
  console.error('TELEGRAM_BOT_TOKEN and TELEGRAM_ADMIN_CHAT_ID required')
  process.exit(1)
}

function isDbError(err: unknown): boolean {
  const msg = String(err instanceof Error ? err.message : err)
  return (
    msg.includes("Can't reach database server") ||
    msg.includes('P1001') ||
    msg.includes('P1017') ||
    msg.includes('ECONNREFUSED') ||
    msg.includes('Connection reset') ||
    msg.includes('Server has closed the connection') ||
    msg.includes('Timed out fetching a new connection')
  )
}

async function resetPrisma() {
  try {
    await prisma.$disconnect()
  } catch {
    /* ignore */
  }
  prisma = new PrismaClient()
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
    return (await res.json()) as {
      ok: boolean
      description?: string
      result?: any
    }
  } finally {
    clearTimeout(timer)
  }
}

function claimText(opts: { claimId: string; email: string; amount: number; note?: string | null }) {
  return [
    '💳 Новая заявка на подписку',
    'Получатель: только Сбербанк',
    `Email: ${opts.email}`,
    `Сумма: ${opts.amount} ₽`,
    `Комментарий: ${opts.note || '—'}`,
    `ID: ${opts.claimId}`
  ].join('\n')
}

type PendingRow = { id: string; amount: number; note: string | null; email: string }
type ClaimRow = {
  id: string
  userId: string
  status: string
  amount: number
  email: string
}

async function notifyPendingClaims() {
  const pending = await prisma.$queryRaw<PendingRow[]>`
    SELECT c.id, c.amount, c.note, u.email
    FROM "PaymentClaim" c
    JOIN "User" u ON u.id = c."userId"
    WHERE c.status = 'pending' AND c."telegramNotifiedAt" IS NULL AND c.provider = 'manual'
    ORDER BY c."createdAt" ASC
    LIMIT 20
  `
  for (const claim of pending) {
    const approve = `ok:${claim.id}`
    const reject = `no:${claim.id}`
    if (approve.length > 64 || reject.length > 64) {
      console.error('callback_data too long', claim.id)
      continue
    }
    const sent = await api('sendMessage', {
      chat_id: adminChatId,
      text: claimText({
        claimId: claim.id,
        email: claim.email,
        amount: claim.amount,
        note: claim.note
      }),
      reply_markup: {
        inline_keyboard: [
          [
            { text: '✅ Подтвердить', callback_data: approve },
            { text: '❌ Отклонить', callback_data: reject }
          ]
        ]
      }
    })
    if (!sent?.ok) {
      console.error('notify failed', claim.id, sent?.description || sent)
      continue
    }
    await prisma.$executeRaw`
      UPDATE "PaymentClaim"
      SET "telegramNotifiedAt" = NOW(), "updatedAt" = NOW()
      WHERE id = ${claim.id}
    `
    console.log(`notified claim ${claim.id} (${claim.email})`)
  }
}

async function resolve(claimId: string, action: 'approve' | 'reject') {
  const rows = await prisma.$queryRaw<ClaimRow[]>`
    SELECT c.id, c."userId", c.status, c.amount, u.email
    FROM "PaymentClaim" c
    JOIN "User" u ON u.id = c."userId"
    WHERE c.id = ${claimId}
    LIMIT 1
  `
  const claim = rows[0]
  if (!claim) return { text: 'Заявка не найдена' }
  if (claim.status !== 'pending') return { text: `Уже: ${claim.status}` }

  if (action === 'reject') {
    const rejected = Number(
      await prisma.$executeRaw`
        UPDATE "PaymentClaim"
        SET status = 'rejected', "updatedAt" = NOW()
        WHERE id = ${claim.id} AND status = 'pending'
      `
    )
    if (rejected < 1) return { text: 'Уже обработана' }
    return { text: `❌ Отклонено\nEmail: ${claim.email}` }
  }

  const days = Number(process.env.SUBSCRIPTION_DAYS || 30)
  const startsAt = new Date()
  const expiresAt = new Date(startsAt.getTime() + days * 24 * 60 * 60 * 1000)
  const subId = `c${Date.now().toString(36)}${Math.random().toString(36).slice(2, 10)}`

  const ok = await prisma.$transaction(async (tx) => {
    const locked = Number(
      await tx.$executeRaw`
        UPDATE "PaymentClaim"
        SET status = 'approved', "updatedAt" = NOW()
        WHERE id = ${claim.id} AND status = 'pending'
      `
    )
    if (locked < 1) return false
    await tx.$executeRaw`
      INSERT INTO "Subscription" (id, "userId", "startsAt", "expiresAt", status, "createdAt")
      VALUES (${subId}, ${claim.userId}, ${startsAt}, ${expiresAt}, CAST('active' AS "SubscriptionStatus"), NOW())
    `
    return true
  })

  if (!ok) return { text: 'Уже обработана' }
  return {
    text: `✅ Подтверждено\nEmail: ${claim.email}\nДо: ${expiresAt.toISOString().slice(0, 10)}`
  }
}

function isAdminCallback(cb: any): boolean {
  const chatId = String(cb?.message?.chat?.id ?? '')
  const fromId = String(cb?.from?.id ?? '')
  return chatId === adminChatId || fromId === adminChatId
}

let offset = 0

async function loop() {
  // Notify first so new claims appear within ~getUpdates timeout, not after a long idle poll.
  await notifyPendingClaims()

  const data = await api('getUpdates', {
    offset,
    timeout: 8,
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

    try {
      if (!isAdminCallback(cb)) {
        console.warn('callback from non-admin', {
          chat: cb.message?.chat?.id,
          from: cb.from?.id
        })
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
      await api('answerCallbackQuery', {
        callback_query_id: cb.id,
        text: action === 'approve' ? 'Подтверждено' : 'Отклонено',
        show_alert: false
      })
      if (cb.message?.chat?.id && cb.message?.message_id) {
        const edited = await api('editMessageText', {
          chat_id: cb.message.chat.id,
          message_id: cb.message.message_id,
          text: result.text
        })
        if (!edited?.ok) {
          console.error('editMessageText failed:', edited?.description || edited)
          await api('sendMessage', {
            chat_id: cb.message.chat.id,
            text: result.text
          })
        }
      }
      console.log(result.text.replace(/\n/g, ' | '))
    } catch (e) {
      console.error('callback handler error:', e instanceof Error ? e.message : e)
      try {
        await api('answerCallbackQuery', {
          callback_query_id: cb.id,
          text: 'Ошибка обработки, смотрите лог',
          show_alert: true
        })
      } catch {
        /* ignore */
      }
    }
  }
}

async function main() {
  console.log('Home Telegram bridge starting…')
  console.log(`Admin chat id: ${adminChatId}`)
  await prisma.$executeRawUnsafe(`
    ALTER TABLE "PaymentClaim" ADD COLUMN IF NOT EXISTS "telegramNotifiedAt" TIMESTAMP(3)
  `)
  // Drop stale webhook + queued updates so a previous poller/webhook cannot steal callbacks.
  const del = await api('deleteWebhook', { drop_pending_updates: true })
  console.log('deleteWebhook:', del?.ok ? 'ok' : del)

  let dbFails = 0
  for (;;) {
    try {
      await loop()
      dbFails = 0
    } catch (e) {
      console.error('poll error:', e instanceof Error ? e.message : e)
      if (isDbError(e)) {
        dbFails += 1
        console.warn(`db fail ${dbFails}/5 — reconnecting prisma`)
        await resetPrisma()
        if (dbFails >= 5) {
          console.error('too many DB failures; exiting so systemd restarts the tunnel')
          process.exit(1)
        }
      } else {
        dbFails = 0
      }
      await new Promise((r) => setTimeout(r, 2000))
    }
  }
}

main().finally(() => prisma.$disconnect())
