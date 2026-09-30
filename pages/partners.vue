<script setup lang="ts">
usePageSeo({
  title: 'Для фитнес-студий и клубов — партнёрство',
  description:
    'Кросс-промо и community для фитнес-студий Москвы: Fitnessgirl Meet помогает членам клуба находить единомышленников со спортивным образом жизни.',
  path: '/partners'
})

const email = 'a.azorabekov1991@gmail.com'
const telegram = 'alexs_azor_91'
</script>

<template>
  <section class="section">
    <div class="container partners">
      <p class="eyebrow">Для студий и клубов</p>
      <h1>Партнёрство без dating-рекламы</h1>
      <p class="lead">
        Fitnessgirl Meet — сервис, где люди со спортивным образом жизни находят друзей и
        единомышленников. Мы сознательно уходим от формата «сайт знакомств» и жёстко фильтруем
        интим- и эскорт-контент — чтобы клубам было спокойно рекомендовать нас участникам.
      </p>

      <h2>Что получаете вы</h2>
      <ul>
        <li>Кросс-промо для членов клуба: промокод / лендинг «для X-Fit / вашей студии»</li>
        <li>Дополнительная ценность абонемента — community вокруг спорта и ЗОЖ</li>
        <li>Без бюджета с вашей стороны на старте: обмен охватом и пользой</li>
        <li>Публичный opt-out: любой может скрыть профиль из подборки</li>
      </ul>

      <h2>Что делаем мы</h2>
      <ul>
        <li>Показываем только публичные профили VK с Москвой и спортивным интересом</li>
        <li>Отсекаем тексты с намёками на интим, эскорт и «услуги»</li>
        <li>Общение — только в VK, мы не посредник и не чат знакомств</li>
      </ul>

      <h2>Как начать</h2>
      <p>
        Напишите нам с темой «Партнёрство / [название студии]». В сообщении коротко укажите:
      </p>
      <ol>
        <li>Название и район студии</li>
        <li>Формат: промокод, пост, сторис, совместный мини-ивент</li>
        <li>Контакт для обратной связи</li>
      </ol>

      <div class="partners-contacts">
        <p>
          Email:
          <a :href="`mailto:${email}?subject=${encodeURIComponent('Партнёрство / студия')}`">{{
            email
          }}</a>
        </p>
        <p>
          Telegram:
          <a :href="`https://t.me/${telegram}`" target="_blank" rel="noopener noreferrer"
            >@{{ telegram }}</a
          >
        </p>
      </div>

      <div class="partners-actions">
        <a
          class="btn btn-primary"
          :href="`mailto:${email}?subject=${encodeURIComponent('Партнёрство / студия')}`"
          >Написать на почту</a
        >
        <a
          class="btn btn-ghost"
          :href="`https://t.me/${telegram}`"
          target="_blank"
          rel="noopener noreferrer"
          >Открыть Telegram</a
        >
        <NuxtLink class="btn btn-ghost" to="/catalog">Посмотреть подборку</NuxtLink>
      </div>
    </div>
  </section>
</template>

<style scoped>
.partners .eyebrow {
  color: var(--muted);
  text-transform: uppercase;
  letter-spacing: 0.06em;
  font-size: 0.8rem;
  margin: 0 0 0.5rem;
}
.partners h2 {
  margin-top: 2rem;
}
.partners ul,
.partners ol {
  padding-left: 1.2rem;
  line-height: 1.55;
  color: var(--text);
}
.partners-contacts {
  margin-top: 1.25rem;
  padding: 1rem 1.1rem;
  border: 1px solid color-mix(in srgb, var(--text) 12%, transparent);
  border-radius: 10px;
  line-height: 1.6;
}
.partners-contacts p {
  margin: 0.25rem 0;
}
.partners-contacts a {
  color: var(--accent, #0b6e4f);
  text-decoration: underline;
  text-underline-offset: 2px;
}
.partners-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 0.75rem;
  margin-top: 2rem;
}
</style>
