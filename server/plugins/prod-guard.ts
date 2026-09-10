export default defineNitroPlugin(() => {
  if (process.env.NODE_ENV !== 'production') return

  const session = String(process.env.NUXT_SESSION_PASSWORD || '').trim()
  const siteUrl = String(process.env.NUXT_PUBLIC_SITE_URL || '').trim()
  const webhookSecret = String(process.env.TELEGRAM_WEBHOOK_SECRET || '').trim()
  const bot = String(process.env.TELEGRAM_BOT_TOKEN || '').trim()
  const chat = String(process.env.TELEGRAM_ADMIN_CHAT_ID || '').trim()

  const errors: string[] = []

  const weakSession =
    !session ||
    session.length < 32 ||
    /change.?me|dev-session|dev-local|replace-with|generate_me|example/i.test(session)
  if (weakSession) {
    errors.push('NUXT_SESSION_PASSWORD must be a strong secret (≥32 chars) in production')
  }
  if (!siteUrl.startsWith('https://') || /localhost|127\.0\.0\.1/i.test(siteUrl)) {
    errors.push('NUXT_PUBLIC_SITE_URL must be a public https:// URL in production')
  }
  if (bot || chat) {
    if (!bot || !chat) {
      errors.push('TELEGRAM_BOT_TOKEN and TELEGRAM_ADMIN_CHAT_ID must both be set')
    }
    if (!webhookSecret || webhookSecret.length < 16 || /change.?me|example/i.test(webhookSecret)) {
      errors.push('TELEGRAM_WEBHOOK_SECRET is required in production when Telegram is enabled')
    }
  }
  if (!process.env.DATABASE_URL) {
    errors.push('DATABASE_URL is required')
  }
  const pgPass = String(process.env.POSTGRES_PASSWORD || '').trim()
  if (pgPass && (/change.?me|fitnessgirl$/i.test(pgPass) || pgPass.length < 12)) {
    errors.push('POSTGRES_PASSWORD must be a strong unique password (≥12 chars)')
  }
  if (!String(process.env.PAYMENT_CARD || '').trim() && !String(process.env.PAYMENT_PHONE || '').trim()) {
    errors.push('Set PAYMENT_CARD and/or PAYMENT_PHONE for /subscribe')
  }

  if (errors.length) {
    console.error('[prod] Refusing to start:\n- ' + errors.join('\n- '))
    throw new Error('Production configuration invalid')
  }
})
