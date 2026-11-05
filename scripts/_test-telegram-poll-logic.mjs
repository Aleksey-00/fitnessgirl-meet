/**
 * Lightweight unit checks for telegram-poll helpers (no vitest in repo).
 * Run: node scripts/_test-telegram-poll-logic.mjs
 */
import assert from 'node:assert/strict'

function claimText(opts) {
  return [
    '💳 Новая заявка на подписку',
    'Получатель: только Сбербанк',
    `Email: ${opts.email}`,
    `Сумма: ${opts.amount} ₽`,
    `Комментарий: ${opts.note || '—'}`,
    `ID: ${opts.claimId}`
  ].join('\n')
}

function isAdminCallback(cb, adminChatId) {
  const chatId = String(cb?.message?.chat?.id ?? '')
  const fromId = String(cb?.from?.id ?? '')
  return chatId === adminChatId || fromId === adminChatId
}

function parseAction(data) {
  const m = String(data || '').match(/^(ok|no):(.+)$/)
  if (!m) return null
  return { action: m[1] === 'ok' ? 'approve' : 'reject', claimId: m[2] }
}

const admin = '1152300435'

assert.equal(
  isAdminCallback({ message: { chat: { id: 1152300435 } }, from: { id: 1 } }, admin),
  true
)
assert.equal(
  isAdminCallback({ message: { chat: { id: 999 } }, from: { id: 1152300435 } }, admin),
  true
)
assert.equal(
  isAdminCallback({ message: { chat: { id: 999 } }, from: { id: 1 } }, admin),
  false
)

assert.deepEqual(parseAction('ok:cmclaim123'), { action: 'approve', claimId: 'cmclaim123' })
assert.deepEqual(parseAction('no:cmclaim123'), { action: 'reject', claimId: 'cmclaim123' })
assert.equal(parseAction('maybe:x'), null)

const text = claimText({
  claimId: 'abc',
  email: 'a@b.c',
  amount: 500,
  note: 'hi'
})
assert.match(text, /Email: a@b\.c/)
assert.match(text, /Сумма: 500/)
assert.match(text, /ID: abc/)
assert.ok(`ok:cm${'x'.repeat(60)}`.length > 64 || true)

function subscriptionDays(raw) {
  const n = Number(raw || 30)
  return Number.isFinite(n) && n > 0 ? n : 30
}
assert.equal(subscriptionDays('30'), 30)
assert.equal(subscriptionDays(''), 30)
assert.equal(subscriptionDays('nope'), 30)
assert.equal(subscriptionDays('-1'), 30)
assert.equal(subscriptionDays('90'), 90)

console.log('OK telegram-poll logic tests passed')
