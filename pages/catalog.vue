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
  catalogGender?: 'female' | 'male'
  profiles: Profile[]
  hasMore: boolean
  nextCursor: string | null
  lockedCount?: number
  total?: number
}

const route = useRoute()
const router = useRouter()
const { me, ensureLoaded } = useAuth()
await ensureLoaded()

function parseGender(raw: unknown): 'female' | 'male' | null {
  if (raw === 'female' || raw === 'male') return raw
  return null
}

/** Default: opposite of viewer (♂→♀, ♀→♂). Guests → women. */
function defaultCatalogGender(): 'female' | 'male' {
  return me.value?.user?.gender === 'female' ? 'male' : 'female'
}

const catalogGender = ref<'female' | 'male'>(
  parseGender(route.query.gender) || defaultCatalogGender()
)

const {
  data: firstPage,
  error: firstError,
  pending: booting
} = await useAsyncData(
  'catalog-first-page',
  () => {
    const requestFetch = useRequestFetch()
    return requestFetch<ProfilesResponse>('/api/profiles', {
      query: { limit: 24, gender: catalogGender.value }
    })
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
const switching = ref(false)
const loadError = ref('')
const bootError = computed(() => {
  if (!firstError.value) return ''
  return (firstError.value as any)?.data?.statusMessage || 'Не удалось загрузить каталог'
})

watch(firstPage, (page) => {
  if (!page || switching.value) return
  profiles.value = [...(page.profiles || [])]
  subscribed.value = Boolean(page.subscribed)
  hasMore.value = Boolean(page.hasMore)
  nextCursor.value = page.nextCursor ?? null
  lockedCount.value = page.lockedCount || 0
  total.value = page.total || 0
})

const showMenCatalog = computed(() => catalogGender.value === 'male')

const catalogTitle = computed(() =>
  showMenCatalog.value
    ? 'Парни со спортивным образом жизни — Москва'
    : 'Девушки со спортивным образом жизни — Москва'
)

const catalogLead = computed(() =>
  showMenCatalog.value
    ? 'Подборка парней из фитнеса и спорта: публичные профили VK с Москвой, фото, возрастом и явным интересом к спорту — без интим-намёков. Общение в VK.'
    : 'Подборка девушек из фитнеса и спорта: публичные профили VK с Москвой, фото, возрастом и явным интересом к спорту — без интим-намёков. Общение в VK.'
)

const sentinel = ref<HTMLElement | null>(null)
const hydrated = ref(false)

function applyPage(res: ProfilesResponse) {
  profiles.value = [...(res.profiles || [])]
  subscribed.value = Boolean(res.subscribed)
  hasMore.value = Boolean(res.hasMore)
  nextCursor.value = res.nextCursor ?? null
  lockedCount.value = res.lockedCount || 0
  total.value = res.total || 0
  if (res.catalogGender === 'female' || res.catalogGender === 'male') {
    catalogGender.value = res.catalogGender
  }
}

async function setCatalogGender(next: 'female' | 'male') {
  if (catalogGender.value === next || switching.value) return
  switching.value = true
  loadError.value = ''
  catalogGender.value = next
  profiles.value = []
  try {
    await router.replace({ query: { ...route.query, gender: next } })
    const requestFetch = useRequestFetch()
    const res = await requestFetch<ProfilesResponse>('/api/profiles', {
      query: { limit: 24, gender: next }
    })
    applyPage(res)
    // Keep useAsyncData cache in sync for further watches / SSR hydration edges.
    firstPage.value = res
  } catch (e: any) {
    loadError.value = e?.data?.statusMessage || 'Не удалось переключить подборку'
  } finally {
    switching.value = false
  }
}

async function loadMore() {
  if (!hydrated.value) return
  if (loadingMore.value || !hasMore.value || !nextCursor.value || !subscribed.value) return
  loadingMore.value = true
  loadError.value = ''
  try {
    const requestFetch = useRequestFetch()
    const res = await requestFetch<ProfilesResponse>('/api/profiles', {
      query: { limit: 24, cursor: nextCursor.value, gender: catalogGender.value }
    })
    subscribed.value = res.subscribed
    if (res.catalogGender) catalogGender.value = res.catalogGender
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
    question: 'Что это за подборка?',
    answer:
      'Fitnessgirl Meet показывает людей со спортивным образом жизни в Москве: друзья, единомышленники и те, с кем совпадает ритм жизни. Переписка — в VK.'
  },
  {
    question: 'Это сайт знакомств?',
    answer:
      'Нет. Это сервис подборки по спорту и ЗОЖ. Близкие отношения могут сложиться, но продукт про сообщество и совпадение образа жизни, не про «чат знакомств».'
  },
  {
    question: 'Как отсекаете нежелательный контент?',
    answer:
      'В подборку не попадают профили без спортивного сигнала и с признаками интим- или эскорт-услуг в публичном тексте. Есть opt-out.'
  },
  {
    question: 'Только Москва?',
    answer:
      'Да, в базе профили с городом Москва в VK (разные округа), если город указан как Москва.'
  },
  {
    question: 'Нужна ли подписка?',
    answer:
      'Часть подборки доступна в превью. Полная лента и ссылки на VK — после оформления доступа.'
  }
]

usePageSeo({
  title: showMenCatalog.value
    ? 'Парни со спортивным образом жизни в Москве'
    : 'Девушки со спортивным образом жизни в Москве',
  description: showMenCatalog.value
    ? 'Подборка парней из фитнеса и спорта в Москве. Друзья и единомышленники через публичные профили VK.'
    : 'Подборка девушек из фитнеса и спорта в Москве. Друзья и единомышленники через публичные профили VK.',
  path: '/catalog'
})

useJsonLd([
  {
    '@context': 'https://schema.org',
    '@type': 'CollectionPage',
    name: 'Люди спорта в Москве — Fitnessgirl Meet',
    description:
      'Подборка людей со спортивным образом жизни в Москве: друзья, единомышленники, совпадения по ритму жизни.',
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
      <h1>{{ catalogTitle }}</h1>
      <p class="lead">
        {{ catalogLead }}
        <template v-if="total"> Всего в базе: {{ total }}.</template>
      </p>

      <div class="catalog-filter" role="group" aria-label="Кого показывать">
        <button
          type="button"
          class="catalog-filter__btn"
          :class="{ 'is-active': catalogGender === 'female' }"
          :disabled="switching"
          @click="setCatalogGender('female')"
        >
          Девушки
        </button>
        <button
          type="button"
          class="catalog-filter__btn"
          :class="{ 'is-active': catalogGender === 'male' }"
          :disabled="switching"
          @click="setCatalogGender('male')"
        >
          Парни
        </button>
      </div>

      <p v-if="bootError" class="form error">{{ bootError }}</p>

      <div v-else-if="(booting || switching) && !profiles.length" class="lead">Загрузка…</div>

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

      <p v-if="!bootError && !booting && !switching && !profiles.length" class="lead empty-hint">
        Пока пусто в этой подборке.
        <template v-if="catalogGender === 'male'"> Мужские анкеты появятся после индексации.</template>
      </p>

      <section class="seo-hub" aria-labelledby="catalog-seo-title">
        <h2 id="catalog-seo-title">Люди спорта в Москве</h2>
        <p>
          Fitnessgirl Meet — подборка публичных профилей VK, где читается интерес к фитнесу, спорту и
          ЗОЖ. Задача сервиса — помочь найти друзей и единомышленников с похожим образом жизни.
          Близкие отношения, если сложатся, — уже ваш личный выбор вне сайта.
        </p>
        <p>
          Мы ужесточаем отбор: нужен явный спортивный сигнал, живое фото, возраст 18–35 и отсутствие
          признаков интим- или эскорт-услуг в публичном тексте. Переписка только в VK.
        </p>
        <p>
          Фитнес-студиям и клубам — отдельная страница
          <NuxtLink to="/partners">партнёрства</NuxtLink>.
        </p>

        <h3 class="seo-hub__sub">Темы</h3>
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
.catalog-filter {
  display: inline-flex;
  gap: 0.35rem;
  margin: 0 0 1.25rem;
  padding: 0.25rem;
  border: 1px solid var(--line);
  border-radius: 999px;
  background: rgba(255, 255, 255, 0.03);
}

.catalog-filter__btn {
  appearance: none;
  border: 0;
  background: transparent;
  color: var(--muted);
  font: inherit;
  font-weight: 600;
  font-size: 0.92rem;
  padding: 0.45rem 1rem;
  border-radius: 999px;
  cursor: pointer;
  transition: background 0.15s ease, color 0.15s ease;
}

.catalog-filter__btn:disabled {
  opacity: 0.6;
  cursor: wait;
}

.catalog-filter__btn.is-active {
  background: var(--accent);
  color: #0c1412;
}

.catalog-filter__btn:not(.is-active):hover {
  color: var(--ink);
}

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
