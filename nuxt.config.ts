// https://nuxt.com/docs/api/configuration/nuxt-config
export default defineNuxtConfig({
  compatibilityDate: '2025-07-15',
  devtools: { enabled: process.env.NODE_ENV !== 'production' },
  css: ['~/assets/css/main.css'],
  app: {
    head: {
      htmlAttrs: { lang: 'ru' },
      charset: 'utf-8',
      viewport: 'width=device-width, initial-scale=1',
      titleTemplate: '%s · Fitnessgirl Meet',
      meta: [
        { name: 'theme-color', content: '#0c1412' },
        { name: 'format-detection', content: 'telephone=no' },
        { property: 'og:site_name', content: 'Fitnessgirl Meet' },
        { property: 'og:locale', content: 'ru_RU' },
        { name: 'twitter:card', content: 'summary_large_image' }
      ],
      link: [
        { rel: 'icon', type: 'image/svg+xml', href: '/favicon.svg' },
        { rel: 'preconnect', href: 'https://fonts.googleapis.com' },
        { rel: 'preconnect', href: 'https://fonts.gstatic.com', crossorigin: '' },
        {
          rel: 'stylesheet',
          href: 'https://fonts.googleapis.com/css2?family=Manrope:wght@400;600;700&family=Syne:wght@700;800&display=swap'
        }
      ]
    }
  },
  runtimeConfig: {
    databaseUrl: process.env.DATABASE_URL || '',
    sessionPassword: process.env.NUXT_SESSION_PASSWORD || 'dev-session-password-min-32-chars!!',
    vkAccessToken: process.env.VK_ACCESS_TOKEN || '',
    adminEmail: process.env.ADMIN_EMAIL || 'admin@fitnessgirl.meet',
    paymentCard: process.env.PAYMENT_CARD || '',
    paymentPhone: process.env.PAYMENT_PHONE || '',
    paymentHolder: process.env.PAYMENT_HOLDER || '',
    paymentBank: process.env.PAYMENT_BANK || 'Сбербанк',
    subscriptionPriceRub: Number(process.env.SUBSCRIPTION_PRICE_RUB || 990),
    subscriptionDays: Number(process.env.SUBSCRIPTION_DAYS || 30),
    telegramBotToken: process.env.TELEGRAM_BOT_TOKEN || '',
    telegramAdminChatId: process.env.TELEGRAM_ADMIN_CHAT_ID || '',
    telegramWebhookSecret: process.env.TELEGRAM_WEBHOOK_SECRET || '',
    public: {
      appName: 'Fitnessgirl Meet',
      freePreviewCount: 3,
      siteUrl: process.env.NUXT_PUBLIC_SITE_URL || 'http://localhost:3000',
      ogImage:
        process.env.NUXT_PUBLIC_OG_IMAGE ||
        'https://images.unsplash.com/photo-1518611012118-696072aa579a?auto=format&fit=crop&w=1200&h=630&q=80',
      googleSiteVerification: process.env.NUXT_PUBLIC_GOOGLE_SITE_VERIFICATION || '',
      yandexVerification: process.env.NUXT_PUBLIC_YANDEX_VERIFICATION || ''
    }
  },
  nitro: {
    // Keep heavy ML deps out of the Nuxt/Nitro runtime — used only by scripts/tools image.
    externals: {
      inline: [],
      external: ['@tensorflow/tfjs-node', '@vladmandic/face-api', 'sharp']
    },
    routeRules: {
      '/**': {
        headers: {
          'X-Content-Type-Options': 'nosniff',
          'X-Frame-Options': 'DENY',
          'Referrer-Policy': 'strict-origin-when-cross-origin'
        }
      }
    }
  }
})
