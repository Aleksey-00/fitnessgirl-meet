<script setup lang="ts">
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

usePageSeo({
  title: 'Анкеты спортивных девушек в Москве',
  description:
    'Лента анкет девушек из Москвы: фитнес, спорт и активный поиск. Смотрите карточки и открывайте профили VK.',
  path: '/catalog'
})

useJsonLd({
  '@context': 'https://schema.org',
  '@type': 'CollectionPage',
  name: 'Анкеты · Москва — Fitnessgirl Meet',
  description: 'Каталог анкет для знакомств со спортивными девушками в Москве.',
  isPartOf: {
    '@type': 'WebSite',
    name: 'Fitnessgirl Meet'
  }
})
</script>

<template>
  <section class="section">
    <div class="container">
      <h1>Анкеты · Москва</h1>
      <p class="lead">
        Отбор по публичным полям VK: фото, возраст, город, признаки спорта и активного поиска.
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
</style>
