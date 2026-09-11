/**
 * Register Telegram webhook for production.
 * Usage: npx tsx scripts/set-telegram-webhook.ts
 */
async function main() {
  const token = process.env.TELEGRAM_BOT_TOKEN
  const siteUrl = (process.env.NUXT_PUBLIC_SITE_URL || '').replace(/\/$/, '')
  const secret = process.env.TELEGRAM_WEBHOOK_SECRET || ''

  if (!token) throw new Error('TELEGRAM_BOT_TOKEN is required')
  if (!siteUrl.startsWith('https://') || /localhost|127\.0\.0\.1/i.test(siteUrl)) {
    throw new Error('NUXT_PUBLIC_SITE_URL must be a public https:// URL')
  }
  if (!secret || secret.length < 16 || /change.?me|example/i.test(secret)) {
    throw new Error('TELEGRAM_WEBHOOK_SECRET is required (strong random string, ≥16 chars)')
  }
  if (!/^[A-Za-z0-9_-]+$/.test(secret)) {
    throw new Error(
      'TELEGRAM_WEBHOOK_SECRET may only contain A-Z, a-z, 0-9, _ and - (no +, /, =). Generate with: openssl rand -hex 32'
    )
  }

  const url = `${siteUrl}/api/telegram/webhook`
  const body: Record<string, unknown> = {
    url,
    allowed_updates: ['callback_query'],
    drop_pending_updates: true,
    secret_token: secret
  }

  const res = await fetch(`https://api.telegram.org/bot${token}/setWebhook`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body)
  })
  const data = await res.json()
  console.log(data)
  if (!data.ok) process.exitCode = 1
}

main().catch((e) => {
  console.error(e)
  process.exitCode = 1
})
