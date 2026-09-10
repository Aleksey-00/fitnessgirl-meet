export function usePageSeo(opts: {
  title: string
  description: string
  path?: string
  image?: string
  noindex?: boolean
  type?: 'website' | 'article'
}) {
  const config = useRuntimeConfig()
  const siteUrl = String(config.public.siteUrl || '').replace(/\/$/, '')
  const path = opts.path || useRoute().path
  const url = `${siteUrl}${path.startsWith('/') ? path : `/${path}`}`
  const image = opts.image || String(config.public.ogImage || '')
  const title = opts.title
  const description = opts.description

  const verificationMeta: Array<{ name: string; content: string }> = []
  if (config.public.googleSiteVerification) {
    verificationMeta.push({
      name: 'google-site-verification',
      content: String(config.public.googleSiteVerification)
    })
  }
  if (config.public.yandexVerification) {
    verificationMeta.push({
      name: 'yandex-verification',
      content: String(config.public.yandexVerification)
    })
  }

  useSeoMeta({
    title,
    description,
    ogTitle: title,
    ogDescription: description,
    ogType: opts.type || 'website',
    ogUrl: url,
    ogImage: image,
    twitterTitle: title,
    twitterDescription: description,
    twitterImage: image,
    robots: opts.noindex ? 'noindex, nofollow' : 'index, follow'
  })

  useHead({
    link: [{ rel: 'canonical', href: url }],
    meta: verificationMeta
  })

  return { url, siteUrl, image }
}

export function useJsonLd(data: Record<string, unknown> | Array<Record<string, unknown>>) {
  useHead({
    script: [
      {
        type: 'application/ld+json',
        children: JSON.stringify(data)
      }
    ]
  })
}
