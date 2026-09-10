<script setup lang="ts">
const { siteUrl, image } = usePageSeo({
  title: 'Знакомства со спортивными девушками в Москве',
  description:
    'Fitnessgirl Meet — каталог анкет девушек из Москвы, которым близки фитнес и активный поиск. Смотрите карточки и переходите в профиль VK.',
  path: '/'
})

useJsonLd([
  {
    '@context': 'https://schema.org',
    '@type': 'WebSite',
    name: 'Fitnessgirl Meet',
    url: siteUrl,
    description:
      'Каталог знакомств со спортивными девушками в Москве с переходом в оригинальный профиль VK.',
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
          Каталог девушек из Москвы, которым близки спорт и активный поиск. Смотрите карточки и
          переходите в оригинальный профиль VK.
        </p>
        <div class="hero__actions">
          <NuxtLink class="btn btn-primary" to="/catalog">Смотреть анкеты</NuxtLink>
          <NuxtLink class="btn btn-ghost" to="/subscribe">Оформить доступ</NuxtLink>
        </div>
      </div>
    </section>

    <section class="section seo-block" aria-labelledby="how-title">
      <div class="container">
        <h2 id="how-title">Как это работает</h2>
        <p class="lead">
          Мы собираем публичные профили VK через официальный API, отбираем Москву, фото, возраст и
          признаки интереса к спорту — и показываем удобный каталог для знакомств.
        </p>
        <ol class="seo-steps">
          <li>Откройте каталог анкет по Москве</li>
          <li>Оформите подписку, чтобы видеть все карточки и ссылки</li>
          <li>Перейдите в оригинальный профиль VK и напишите сами</li>
        </ol>
        <p>
          <NuxtLink to="/catalog">Анкеты девушек в Москве</NuxtLink>
          ·
          <NuxtLink to="/disclaimer">Дисклеймер</NuxtLink>
          ·
          <NuxtLink to="/opt-out">Удалить анкету</NuxtLink>
        </p>
      </div>
    </section>
  </div>
</template>

<style scoped>
.seo-block {
  padding-top: 2.5rem;
}

.seo-steps {
  margin: 0 0 1.25rem;
  padding-left: 1.2rem;
  color: var(--muted);
  max-width: 36rem;
  line-height: 1.7;
}

.seo-steps li {
  margin-bottom: 0.35rem;
}
</style>
