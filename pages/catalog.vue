<script setup lang="ts">
import { seoTopics } from '../data/seo-topics'

type Profile = {
  id: string
  displayName: string
  age: number | null
  city: string
  photoUrl: string | null
  tags: string[]
  vkUrl: string | null
}

type ProfilesResponse = {
  subscribed: boolean
  profiles: Profile[]
  hasMore: boolean
  nextCursor: string | null
  lockedCount?: number
  total?: number
}

const {
  data: firstPage,
  error: firstError,
  pending: booting
} = await useAsyncData(
  'catalog-first-page',
  () => {
    const requestFetch = useRequestFetch()
    return requestFetch<ProfilesResponse>('/api/profiles', { query: { limit: 24 } })
  },
  { server: true, lazy: false }
)

const profiles = ref<Profile[]>([...(firstPage.value?.profiles || [])])
const subscribed = ref(Boolean(firstPage.value?.subscribed))
const hasMore = ref(Boolean(firstPage.value?.hasMore))
const nextCursor = ref<string | null>(firstPage.value?.nextCursor ?? null)
const lockedCount = ref(firstPage.value?.lockedCount || 0)
const total = ref(firstPage.value?.total || 0)
const loadingMore = ref(false)
const loadError = ref('')
const bootError = computed(() => {
  if (!firstError.value) return ''
  return (firstError.value as any)?.data?.statusMessage || 'Не удалось загрузить каталог'
})

const sentinel = ref<HTMLElement | null>(null)
const hydrated = ref(false)

async function loadMore() {
  if (!hydrated.value) return
  if (loadingMore.value || !hasMore.value || !nextCursor.value || !subscribed.value) return
  loadingMore.value = true
  loadError.value = ''
  try {
    const requestFetch = useRequestFetch()
    const res = await requestFetch<ProfilesResponse>('/api/profiles', {
      query: { limit: 24, cursor: nextCursor.value }
    })
    subscribed.value = res.subscribed
    hasMore.value = res.hasMore
    nextCursor.value = res.nextCursor
    lockedCount.value = res.lockedCount || 0
    total.value = res.total || 0
    const seen = new Set(profiles.value.map((p) => p.id))
    profiles.value.push(...res.profiles.filter((p) => !seen.has(p.id)))
  } catch (e: any) {
    loadError.value = e?.data?.statusMessage || 'Не удалось загрузить каталог'
  } finally {
    loadingMore.value = false
  }
}

let observer: IntersectionObserver | null = null

onMounted(() => {
  hydrated.value = true
  observer = new IntersectionObserver(
    (entries) => {
      if (entries.some((e) => e.isIntersecting)) {
        loadMore()
      }
    },
    { rootMargin: '400px 0px' }
  )
  if (sentinel.value) observer.observe(sentinel.value)
})

watch(sentinel, (el, _, onCleanup) => {
  if (!observer) return
  if (el) observer.observe(el)
  onCleanup(() => {
    if (el) observer?.unobserve(el)
  })
})

onBeforeUnmount(() => {
  observer?.disconnect()
  observer = null
})

const catalogFaqs = [
  {
    question: 'Где смотреть анкеты спортивных девушек в Москве?',
    answer:
      'В каталоге Fitnessgirl Meet: лента анкет по Москве с фото и переходом в оригинальный профиль VK.'
  },
  {
    question: 'Есть ли анкеты фитоняшек и девушек из фитнеса?',
    answer:
      'Да. В отбор попадают профили с признаками фитнеса, спорта и активного поиска — в том числе то, что в поиске называют фитоняшками.'
  },
  {
    question: 'Это сайт знакомств со спортивными девушками?',
    answer:
      'По сути да: каталог для знакомств. Переписка идёт в VK после перехода по ссылке, а не во внутреннем чате.'
  },
  {
    question: 'Где познакомиться со спортивной девушкой в Москве онлайн?',
    answer:
      'Откройте каталог, выберите анкету по фото и описанию, перейдите в VK и напишите короткое сообщение.'
  },
  {
    question: 'Анкеты только из центра Москвы?',
    answer:
      'Нет. В базе девушки из разных округов Москвы (в том числе САО, ЦАО, ЮАО и других), если в профиле указан город Москва.'
  },
  {
    question: 'Нужна ли подписка, чтобы видеть анкеты?',
    answer:
      'Часть каталога доступна в превью. Полная лента и ссылки на VK открываются после подписки.'
  }
]

usePageSeo({
  title: 'Анкеты спортивных девушек в Москве',
  description:
    'Каталог анкет спортивных девушек, фитоняшек и девушек из фитнеса в Москве. Фото, город, переход в профиль VK для знакомств.',
  path: '/catalog'
})

useJsonLd([
  {
    '@context': 'https://schema.org',
    '@type': 'CollectionPage',
    name: 'Анкеты спортивных девушек в Москве — Fitnessgirl Meet',
    description:
      'Каталог анкет для знакомств со спортивными девушками, фитоняшками и спортсменками в Москве.',
    isPartOf: {
      '@type': 'WebSite',
      name: 'Fitnessgirl Meet'
    }
  },
  {
    '@context': 'https://schema.org',
    '@type': 'FAQPage',
    mainEntity: catalogFaqs.map((f) => ({
      '@type': 'Question',
      name: f.question,
      acceptedAnswer: {
        '@type': 'Answer',
        text: f.answer
      }
    }))
  }
])
</script>

<template>
  <section class="section">
    <div class="container">
      <h1>Анкеты спортивных девушек в Москве</h1>
      <p class="lead">
        Фитоняшки, девушки из фитнеса и спортсменки: отбор по публичным полям VK — фото, возраст,
        город Москва, признаки спорта и активного поиска.
        <template v-if="total"> Всего в базе: {{ total }}.</template>
      </p>

      <p v-if="bootError" class="form error">{{ bootError }}</p>

      <div v-else-if="booting && !profiles.length" class="lead">Загрузка…</div>

      <div v-else class="grid">
        <article
          v-for="(p, i) in profiles"
          :key="p.id"
          class="profile-card"
          :style="{ animationDelay: `${Math.min(i, 24) * 30}ms` }"
        >
          <div class="profile-card__media">
            <img v-if="p.photoUrl" :src="p.photoUrl" :alt="p.displayName" loading="lazy" />
          </div>
          <div class="profile-card__body">
            <h2 class="profile-card__name">{{ p.displayName }}</h2>
            <p class="profile-card__meta">
              <template v-if="p.age">{{ p.age }} · </template>{{ p.city }}
            </p>
            <div v-if="p.tags?.length" class="tags">
              <span v-for="t in p.tags" :key="t" class="tag">{{ t }}</span>
            </div>
            <a
              v-if="p.vkUrl"
              class="btn btn-primary"
              :href="p.vkUrl"
              target="_blank"
              rel="noopener noreferrer"
            >
              Открыть в VK
            </a>
            <NuxtLink v-else class="btn btn-ghost" to="/subscribe">Открыть по подписке</NuxtLink>
          </div>
        </article>
      </div>

      <div v-if="!subscribed && lockedCount > 0" class="paywall">
        <strong>Ещё {{ lockedCount }} анкет скрыто.</strong>
        Полная бесконечная лента и ссылки на VK — после подписки.
        <div class="paywall__cta">
          <NuxtLink class="btn btn-primary" to="/subscribe">Оформить доступ</NuxtLink>
        </div>
      </div>

      <div v-if="subscribed" class="feed-status">
        <p v-if="loadingMore">Подгружаем ещё…</p>
        <p v-else-if="loadError" class="form error">{{ loadError }}</p>
        <p v-else-if="!hasMore && profiles.length">Это все анкеты на сейчас.</p>
        <div ref="sentinel" class="feed-sentinel" aria-hidden="true" />
      </div>

      <p v-if="!bootError && !booting && !profiles.length" class="lead empty-hint">
        Пока пусто. Запустите индексатор:
        <code>npm run index:daily</code>
      </p>

      <section class="seo-hub" aria-labelledby="catalog-seo-title">
        <h2 id="catalog-seo-title">Знакомства со спортивными девушками в Москве</h2>
        <p>
          Каталог Fitnessgirl Meet — это лента анкет спортивных девушек, фитоняшек и девушек из
          фитнеса в Москве. Мы опираемся на публичные профили VK: фото, возраст, город и признаки
          интереса к спорту или ЗОЖ. Дальше вы сами переходите в профиль и пишете в VK.
        </p>
        <p>
          Здесь удобно искать не только «анкеты спортивных девушек в Москве», но и смежные запросы:
          знакомства со спортсменками, стройными девушками, девушками с ухоженной спортивной фигурой.
          В подборке встречаются анкеты из разных округов Москвы — без отдельного фильтра по САО или
          ЦАО, зато с живыми карточками и фото.
        </p>
        <p>
          Если нужен сайт знакомств со спортивными девушками в Москве без свайпов и внутреннего чата —
          начните с этой ленты, оформите доступ к полному каталогу и выбирайте, кому написать.
        </p>

        <h3 class="seo-hub__sub">Темы каталога</h3>
        <ul class="seo-hub__links">
          <li v-for="t in seoTopics" :key="t.slug">
            <NuxtLink :to="`/topics/${t.slug}`">{{ t.h1 }}</NuxtLink>
          </li>
        </ul>

        <h3 class="seo-hub__sub">Частые вопросы</h3>
        <div class="seo-faq">
          <details v-for="(f, i) in catalogFaqs" :key="i" class="seo-faq__item">
            <summary>{{ f.question }}</summary>
            <p>{{ f.answer }}</p>
          </details>
        </div>
      </section>
    </div>
  </section>
</template>

<style scoped>
.feed-status {
  margin-top: 1.5rem;
  text-align: center;
  color: var(--muted);
  min-height: 2rem;
}

.feed-sentinel {
  height: 1px;
  width: 100%;
}

.paywall__cta {
  margin-top: 0.85rem;
}

.empty-hint {
  margin-top: 1rem;
}

.seo-hub {
  margin-top: 3rem;
  padding-top: 2rem;
  border-top: 1px solid var(--line);
  max-width: 42rem;
  color: var(--muted);
  line-height: 1.7;
}

.seo-hub h2 {
  color: var(--ink);
  font-family: var(--font-display);
  font-size: 1.35rem;
  margin: 0 0 1rem;
}

.seo-hub__sub {
  color: var(--ink);
  font-size: 1.05rem;
  margin: 1.75rem 0 0.75rem;
}

.seo-hub__links {
  margin: 0;
  padding-left: 1.1rem;
}

.seo-hub__links a {
  color: var(--accent);
  text-decoration: underline;
  text-underline-offset: 0.15em;
}

.seo-faq__item {
  border: 1px solid var(--line);
  border-radius: 12px;
  padding: 0.75rem 0.9rem;
  margin-bottom: 0.55rem;
  background: rgba(255, 255, 255, 0.02);
}

.seo-faq__item summary {
  cursor: pointer;
  color: var(--ink);
  font-weight: 600;
}

.seo-faq__item p {
  margin: 0.65rem 0 0;
}
</style>
