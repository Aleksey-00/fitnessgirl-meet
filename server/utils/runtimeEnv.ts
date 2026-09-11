/** Read env at request time (Render injects vars at runtime, not Docker build). */
export function envStr(...keys: string[]) {
  for (const key of keys) {
    const value = String(process.env[key] || '').trim()
    if (value) return value
  }
  return ''
}

export function envNum(fallback: number, ...keys: string[]) {
  for (const key of keys) {
    const raw = String(process.env[key] || '').trim()
    if (!raw) continue
    const n = Number(raw)
    if (Number.isFinite(n)) return n
  }
  return fallback
}

export function getPaymentRuntime() {
  const config = useRuntimeConfig()
  return {
    priceRub:
      envNum(0, 'SUBSCRIPTION_PRICE_RUB', 'NUXT_SUBSCRIPTION_PRICE_RUB') ||
      Number(config.subscriptionPriceRub) ||
      990,
    days:
      envNum(0, 'SUBSCRIPTION_DAYS', 'NUXT_SUBSCRIPTION_DAYS') ||
      Number(config.subscriptionDays) ||
      30,
    bank:
      envStr('PAYMENT_BANK', 'NUXT_PAYMENT_BANK') ||
      String(config.paymentBank || '').trim() ||
      'Сбербанк',
    card: envStr('PAYMENT_CARD', 'NUXT_PAYMENT_CARD') || String(config.paymentCard || '').trim(),
    phone: envStr('PAYMENT_PHONE', 'NUXT_PAYMENT_PHONE') || String(config.paymentPhone || '').trim(),
    holder: envStr('PAYMENT_HOLDER', 'NUXT_PAYMENT_HOLDER') || String(config.paymentHolder || '').trim()
  }
}

export function getAdminEmail() {
  const config = useRuntimeConfig()
  return (
    envStr('ADMIN_EMAIL', 'NUXT_ADMIN_EMAIL') ||
    String(config.adminEmail || '').trim() ||
    'admin@fitnessgirl.meet'
  )
}

export function getTelegramRuntime() {
  const config = useRuntimeConfig()
  return {
    botToken:
      envStr('TELEGRAM_BOT_TOKEN', 'NUXT_TELEGRAM_BOT_TOKEN') ||
      String(config.telegramBotToken || '').trim(),
    adminChatId:
      envStr('TELEGRAM_ADMIN_CHAT_ID', 'NUXT_TELEGRAM_ADMIN_CHAT_ID') ||
      String(config.telegramAdminChatId || '').trim(),
    webhookSecret:
      envStr('TELEGRAM_WEBHOOK_SECRET', 'NUXT_TELEGRAM_WEBHOOK_SECRET') ||
      String(config.telegramWebhookSecret || '').trim()
  }
}
