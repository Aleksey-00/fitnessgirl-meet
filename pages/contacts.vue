<script setup lang="ts">
const { data: legal } = await useFetch('/api/legal/info')

usePageSeo({
  title: 'Контакты и реквизиты',
  description:
    'Контакты Fitnessgirl Meet: email, телефон, юридический адрес и реквизиты компании.',
  path: '/contacts'
})

const missing = computed(
  () =>
    !legal.value?.entityName &&
    !legal.value?.inn &&
    !legal.value?.address &&
    !legal.value?.email &&
    !legal.value?.phone
)
</script>

<template>
  <section class="section">
    <div class="container legal">
      <h1>Контакты</h1>
      <p>
        Пишите нам по вопросам оплаты, доступа, партнёрства или удаления профиля из подборки
        (см. также <NuxtLink to="/opt-out">opt-out</NuxtLink>).
      </p>

      <p v-if="missing" class="contacts-notice" role="note">
        Реквизиты компании ещё не заполнены в настройках сайта (переменные окружения
        <code>LEGAL_*</code>). Это необходимо сделать перед подключением приёма платежей.
      </p>

      <dl class="contacts-list">
        <dt>Наименование организации / ИП</dt>
        <dd>{{ legal?.entityName || '—' }}</dd>
        <dt>ИНН</dt>
        <dd>{{ legal?.inn || '—' }}</dd>
        <dt>ОГРН / ОГРНИП</dt>
        <dd>{{ legal?.ogrn || '—' }}</dd>
        <dt>Юридический / почтовый адрес</dt>
        <dd>{{ legal?.address || '—' }}</dd>
        <dt>Email</dt>
        <dd>
          <a v-if="legal?.email" :href="`mailto:${legal.email}`">{{ legal.email }}</a>
          <template v-else>—</template>
        </dd>
        <dt>Телефон</dt>
        <dd>
          <a v-if="legal?.phone" :href="`tel:${legal.phone.replace(/[^\d+]/g, '')}`">{{
            legal.phone
          }}</a>
          <template v-else>—</template>
        </dd>
      </dl>

      <p>
        Условия предоставления доступа — в <NuxtLink to="/offer">публичной оферте</NuxtLink>.
      </p>
    </div>
  </section>
</template>

<style scoped>
.contacts-notice {
  margin: 0 0 1.25rem;
  padding: 0.75rem 0.9rem;
  border: 1px solid color-mix(in srgb, var(--accent) 45%, transparent);
  background: color-mix(in srgb, var(--accent) 12%, transparent);
  color: var(--text);
  font-weight: 600;
  line-height: 1.4;
}
.contacts-list {
  display: grid;
  grid-template-columns: 14rem 1fr;
  gap: 0.5rem 0.75rem;
  margin: 1rem 0 1.5rem;
}
.contacts-list dt {
  color: var(--muted);
}
.contacts-list dd {
  margin: 0;
}
@media (max-width: 560px) {
  .contacts-list {
    grid-template-columns: 1fr;
  }
}
</style>
