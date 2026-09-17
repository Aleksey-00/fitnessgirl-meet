<script setup lang="ts">
import { getSeoTopic, getSeoTopicBySlugs, seoTopics } from '../../data/seo-topics'

const route = useRoute()
const slug = computed(() => String(route.params.slug || ''))
const topic = computed(() => getSeoTopic(slug.value))

if (!topic.value) {
  throw createError({ statusCode: 404, statusMessage: 'Тема не найдена' })
}

const related = computed(() => getSeoTopicBySlugs(topic.value?.related || []))

usePageSeo({
  title: topic.value.title,
  description: topic.value.description,
  path: `/topics/${topic.value.slug}`
})

useJsonLd([
  {
    '@context': 'https://schema.org',
    '@type': 'WebPage',
    name: topic.value.h1,
    description: topic.value.description,
    isPartOf: {
      '@type': 'WebSite',
      name: 'Fitnessgirl Meet'
    }
  },
  {
    '@context': 'https://schema.org',
    '@type': 'FAQPage',
    mainEntity: topic.value.faqs.map((f) => ({
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
  <section v-if="topic" class="section">
    <div class="container topic">
      <p class="topic__crumb">
        <NuxtLink to="/">Главная</NuxtLink>
        ·
        <NuxtLink to="/catalog">Каталог</NuxtLink>
      </p>
      <h1>{{ topic.h1 }}</h1>
      <p class="lead">{{ topic.lead }}</p>

      <div class="topic__actions">
        <NuxtLink class="btn btn-primary" to="/catalog">Смотреть анкеты</NuxtLink>
        <NuxtLink class="btn btn-ghost" to="/subscribe">Оформить доступ</NuxtLink>
      </div>

      <div class="topic__body">
        <p v-for="(p, i) in topic.paragraphs" :key="i">{{ p }}</p>
      </div>

      <h2 class="topic__sub">Частые вопросы</h2>
      <div class="seo-faq">
        <details v-for="(f, i) in topic.faqs" :key="i" class="seo-faq__item">
          <summary>{{ f.question }}</summary>
          <p>{{ f.answer }}</p>
        </details>
      </div>

      <h2 class="topic__sub">Похожие темы</h2>
      <ul class="topic__related">
        <li v-for="r in related" :key="r.slug">
          <NuxtLink :to="`/topics/${r.slug}`">{{ r.title }}</NuxtLink>
        </li>
        <li>
          <NuxtLink to="/catalog">Все анкеты спортивных девушек в Москве</NuxtLink>
        </li>
      </ul>

      <p class="topic__all">
        Все темы:
        <template v-for="(t, i) in seoTopics" :key="t.slug">
          <NuxtLink :to="`/topics/${t.slug}`">{{ t.title }}</NuxtLink>
          <template v-if="i < seoTopics.length - 1"> · </template>
        </template>
      </p>
    </div>
  </section>
</template>

<style scoped>
.topic {
  max-width: 42rem;
}

.topic__crumb {
  color: var(--muted);
  margin-bottom: 0.75rem;
}

.topic__crumb a {
  color: var(--accent);
  text-decoration: underline;
  text-underline-offset: 0.15em;
}

.topic__actions {
  display: flex;
  flex-wrap: wrap;
  gap: 0.75rem;
  margin: 1.25rem 0 1.75rem;
}

.topic__body {
  color: var(--muted);
  line-height: 1.75;
}

.topic__body p {
  margin: 0 0 1rem;
}

.topic__sub {
  margin: 2rem 0 0.85rem;
  font-size: 1.2rem;
  font-family: var(--font-display);
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
  color: var(--muted);
  line-height: 1.6;
}

.topic__related {
  margin: 0;
  padding-left: 1.1rem;
  line-height: 1.8;
}

.topic__related a,
.topic__all a {
  color: var(--accent);
  text-decoration: underline;
  text-underline-offset: 0.15em;
}

.topic__all {
  margin-top: 2rem;
  color: var(--muted);
  line-height: 1.7;
  font-size: 0.95rem;
}
</style>
