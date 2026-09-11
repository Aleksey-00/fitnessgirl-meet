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
    // Defaults stay empty on purpose: Render injects env at container runtime,
    // while Docker build would otherwise bake blank values into the image.
    databaseUrl: '',
    sessionPassword: 'dev-session-password-min-32-chars!!',
    vkAccessToken: '',
    adminEmail: 'admin@fitnessgirl.meet',
    paymentCard: '',
    paymentPhone: '',
    paymentHolder: '',
    paymentBank: 'Сбербанк',
    subscriptionPriceRub: 990,
    subscriptionDays: 30,
    telegramBotToken: '',
    telegramAdminChatId: '',
    telegramWebhookSecret: '',
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
