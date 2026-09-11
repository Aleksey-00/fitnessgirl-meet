export default defineEventHandler(async (event) => {
  const secret = getTelegramRuntime().webhookSecret
  if (process.env.NODE_ENV === 'production' && !secret) {
    throw createError({ statusCode: 503, statusMessage: 'Webhook secret not configured' })
  }
  if (secret) {
    const header = getHeader(event, 'x-telegram-bot-api-secret-token')
    if (header !== secret) {
      throw createError({ statusCode: 401, statusMessage: 'Unauthorized' })
    }
  }

  const update = await readBody(event)
  const cb = update?.callback_query
  if (!cb) {
    return { ok: true }
  }

  const chatId = cb.message?.chat?.id
  const messageId = cb.message?.message_id
  const data = String(cb.data || '')
  const callbackId = String(cb.id || '')

  if (!isTelegramAdminChat(chatId)) {
    await answerTelegramCallback({
      callbackQueryId: callbackId,
      text: 'Нет доступа',
      showAlert: true
    })
    return { ok: true }
  }

  const match = data.match(/^(ok|no):(.+)$/)
  if (!match) {
    await answerTelegramCallback({
      callbackQueryId: callbackId,
      text: 'Неизвестная команда'
    })
    return { ok: true }
  }

  const action = match[1] === 'ok' ? 'approve' : 'reject'
  const claimId = match[2]
  const result = await resolvePaymentClaim(claimId, action)

  if (!result.ok && result.reason === 'not_found') {
    await answerTelegramCallback({
      callbackQueryId: callbackId,
      text: 'Заявка не найдена',
      showAlert: true
    })
    return { ok: true }
  }

  if (!result.ok && result.reason === 'already_processed') {
    await answerTelegramCallback({
      callbackQueryId: callbackId,
      text: `Уже обработана: ${result.status}`
    })
    if (chatId && messageId) {
      await editTelegramMessage({
        chatId,
        messageId,
        text: `ℹ️ Заявка уже была обработана (${result.status})\nEmail: ${result.email}`
      })
    }
    return { ok: true }
  }

  if (result.ok && result.action === 'approve') {
    await answerTelegramCallback({
      callbackQueryId: callbackId,
      text: 'Подписка активирована'
    })
    if (chatId && messageId) {
      await editTelegramMessage({
        chatId,
        messageId,
        text: [
          '✅ Подписка подтверждена',
          `Email: ${result.email}`,
          `Сумма: ${result.amount} ₽`,
          `До: ${result.expiresAt}`
        ].join('\n')
      })
    }
    return { ok: true }
  }

  if (result.ok && result.action === 'reject') {
    await answerTelegramCallback({
      callbackQueryId: callbackId,
      text: 'Заявка отклонена'
    })
    if (chatId && messageId) {
      await editTelegramMessage({
        chatId,
        messageId,
        text: [`❌ Заявка отклонена`, `Email: ${result.email}`, `Сумма: ${result.amount} ₽`].join(
          '\n'
        )
      })
    }
  }

  return { ok: true }
})
