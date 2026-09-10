type TelegramInlineKeyboard = {
  inline_keyboard: Array<Array<{ text: string; callback_data: string }>>
}

function botToken() {
  return String(useRuntimeConfig().telegramBotToken || '').trim()
}

function adminChatId() {
  return String(useRuntimeConfig().telegramAdminChatId || '').trim()
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

export async function notifyNewPaymentClaim(opts: {
  claimId: string
  email: string
  amount: number
  note?: string | null
}) {
  if (!telegramEnabled()) return

  const text = [
    '💳 Новая заявка на подписку',
    'Получатель: только Сбербанк',
    `Email: ${opts.email}`,
    `Сумма: ${opts.amount} ₽`,
    `Комментарий: ${opts.note || '—'}`,
    `ID: ${opts.claimId}`
  ].join('\n')

  // callback_data max 64 bytes
  const approve = `ok:${opts.claimId}`
  const reject = `no:${opts.claimId}`
  if (approve.length > 64 || reject.length > 64) {
    console.error('Telegram callback_data too long for claim id')
    return
  }

  const reply_markup: TelegramInlineKeyboard = {
    inline_keyboard: [
      [
        { text: '✅ Подтвердить', callback_data: approve },
        { text: '❌ Отклонить', callback_data: reject }
      ]
    ]
  }

  await telegramApi('sendMessage', {
    chat_id: adminChatId(),
    text,
    reply_markup
  })
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
