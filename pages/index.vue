<script setup lang="ts">
import { seoTopics } from '../data/seo-topics'

const homeTopics = seoTopics.filter((t) =>
  ['sportivnye-devushki', 'fitonyashki', 'fitness-devushki', 'znakomstva-sport', 'gde-poznakomitsya'].includes(
    t.slug
  )
)

const { siteUrl, image } = usePageSeo({
  title: 'Люди спорта в Москве — друзья и единомышленники',
  description:
    'Fitnessgirl Meet — подборка людей со спортивным образом жизни в Москве. Находите друзей, единомышленников и близких по ритму жизни через публичные профили VK.',
  path: '/'
})

useJsonLd([
  {
    '@context': 'https://schema.org',
    '@type': 'WebSite',
    name: 'Fitnessgirl Meet',
    url: siteUrl,
    description:
      'Сервис для поиска друзей и единомышленников со спортивным образом жизни в Москве.',
    inLanguage: 'ru-RU'
  },
  {
    '@context': 'https://schema.org',
    '@type': 'Organization',
    name: 'Fitnessgirl Meet',
    url: siteUrl,
    logo: `${siteUrl}/favicon.svg`,
    image
  }
])
</script>

<template>
  <div>
    <section class="hero">
      <div class="hero__media" aria-hidden="true" />
      <div class="container hero__content">
        <h1 class="hero__brand">Fitnessgirl <span>Meet</span></h1>
        <p class="hero__lead">
          Люди спорта в Москве: друзья, единомышленники и те, с кем совпадает образ жизни.
          Смотрите карточки и пишите в оригинальный профиль VK.
        </p>
        <div class="hero__actions">
          <NuxtLink class="btn btn-primary" to="/catalog">Смотреть подборку</NuxtLink>
          <NuxtLink class="btn btn-ghost" to="/subscribe">Оформить доступ</NuxtLink>
        </div>
      </div>
    </section>

    <section class="section seo-block" aria-labelledby="how-title">
      <div class="container">
        <h2 id="how-title">Как это работает</h2>
        <p class="lead">
          Мы собираем публичные профили VK через официальный API, оставляем Москву, живое фото,
          возраст и явный интерес к спорту — без интим- и эскорт-намёков. Общение только в VK.
        </p>
        <ol class="seo-steps">
          <li>Откройте подборку людей со спортивным образом жизни</li>
          <li>Оформите доступ, чтобы видеть все карточки и ссылки</li>
          <li>Перейдите в профиль VK и напишите сами — как другу по интересам</li>
        </ol>
        <p>
          <NuxtLink to="/catalog">Подборка по Москве</NuxtLink>
          ·
          <NuxtLink to="/partners">Для фитнес-студий</NuxtLink>
          ·
          <NuxtLink to="/disclaimer">Дисклеймер</NuxtLink>
          ·
          <NuxtLink to="/opt-out">Скрыть профиль</NuxtLink>
        </p>
      </div>
    </section>

    <section class="section seo-block" aria-labelledby="for-whom-title">
      <div class="container">
        <h2 id="for-whom-title">Кому это подходит</h2>
        <p class="lead">
          Если вам близки зал, бег, ЗОЖ или просто активный ритм — здесь удобнее найти людей с тем же
          вайбом: для дружбы, совместных тренировок или более близких отношений, если так сложится.
        </p>
        <ul class="topic-list">
          <li v-for="t in homeTopics" :key="t.slug">
            <NuxtLink :to="`/topics/${t.slug}`">{{ t.title }}</NuxtLink>
          </li>
          <li>
            <NuxtLink to="/catalog">Вся подборка</NuxtLink>
          </li>
          <li>
            <NuxtLink to="/partners">Партнёрство для студий</NuxtLink>
          </li>
        </ul>
      </div>
    </section>
  </div>
</template>

<style scoped>
.seo-block {
  padding-top: 2.5rem;
}
</style>
