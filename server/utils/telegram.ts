type TelegramInlineKeyboard = {
  inline_keyboard: Array<Array<{ text: string; callback_data: string }>>
}

function botToken() {
  return getTelegramRuntime().botToken
}

function adminChatId() {
  return getTelegramRuntime().adminChatId
}

export function telegramEnabled() {
  return Boolean(botToken() && adminChatId())
}

async function telegramApi(method: string, body: Record<string, unknown>) {
  const token = botToken()
  if (!token) return null
  const res = await fetch(`https://api.telegram.org/bot${token}/${method}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body)
  })
  const data = (await res.json()) as { ok: boolean; description?: string; result?: unknown }
  if (!data.ok) {
    console.error(`Telegram ${method} failed:`, data.description || data)
  }
  return data
}

export function paymentClaimTelegramText(opts: {
  claimId: string
  email: string
  amount: number
  note?: string | null
}) {
  return [
    '💳 Новая заявка на подписку',
    'Получатель: только Сбербанк',
    `Email: ${opts.email}`,
    `Сумма: ${opts.amount} ₽`,
    `Комментарий: ${opts.note || '—'}`,
    `ID: ${opts.claimId}`
  ].join('\n')
}

export function paymentClaimTelegramKeyboard(claimId: string): TelegramInlineKeyboard | null {
  // callback_data max 64 bytes
  const approve = `ok:${claimId}`
  const reject = `no:${claimId}`
  if (approve.length > 64 || reject.length > 64) {
    console.error('Telegram callback_data too long for claim id')
    return null
  }
  return {
    inline_keyboard: [
      [
        { text: '✅ Подтвердить', callback_data: approve },
        { text: '❌ Отклонить', callback_data: reject }
      ]
    ]
  }
}

/** @returns true when Telegram accepted sendMessage */
export async function notifyNewPaymentClaim(opts: {
  claimId: string
  email: string
  amount: number
  note?: string | null
}): Promise<boolean> {
  if (!telegramEnabled()) return false

  const reply_markup = paymentClaimTelegramKeyboard(opts.claimId)
  if (!reply_markup) return false

  const data = await telegramApi('sendMessage', {
    chat_id: adminChatId(),
    text: paymentClaimTelegramText(opts),
    reply_markup
  })
  return Boolean(data?.ok)
}

export async function answerTelegramCallback(opts: {
  callbackQueryId: string
  text: string
  showAlert?: boolean
}) {
  await telegramApi('answerCallbackQuery', {
    callback_query_id: opts.callbackQueryId,
    text: opts.text,
    show_alert: Boolean(opts.showAlert)
  })
}

export async function editTelegramMessage(opts: {
  chatId: number | string
  messageId: number
  text: string
}) {
  await telegramApi('editMessageText', {
    chat_id: opts.chatId,
    message_id: opts.messageId,
    text: opts.text
  })
}

export function isTelegramAdminChat(chatId: number | string) {
  return String(chatId) === adminChatId()
}
