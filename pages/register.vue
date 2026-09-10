<script setup lang="ts">
const email = ref('')
const password = ref('')
const error = ref('')
const pending = ref(false)

usePageSeo({
  title: 'Регистрация',
  description: 'Создайте аккаунт Fitnessgirl Meet, чтобы оформить подписку на каталог.',
  path: '/register',
  noindex: true
})

async function submit() {
  error.value = ''
  pending.value = true
  try {
    const digest = await passwordDigest(password.value)
    await $fetch('/api/auth/register', {
      method: 'POST',
      body: { email: email.value, password: digest }
    })
    const { refresh } = useAuth()
    await refresh()
    clearNuxtData('catalog-first-page')
    await navigateTo('/subscribe')
  } catch (e: any) {
    error.value = e?.data?.statusMessage || 'Ошибка регистрации'
  } finally {
    pending.value = false
  }
}
</script>

<template>
  <section class="section">
    <div class="container">
      <h1>Регистрация</h1>
      <p class="lead">Создайте аккаунт — дальше перевод на карту и активация доступа.</p>
      <form class="form" @submit.prevent="submit">
        <label>
          Email
          <input v-model="email" type="email" required autocomplete="email" />
        </label>
        <label>
          Пароль (от 8 символов)
          <input v-model="password" type="password" required minlength="8" autocomplete="new-password" />
        </label>
        <p v-if="error" class="error">{{ error }}</p>
        <button class="btn btn-primary" type="submit" :disabled="pending">
          {{ pending ? 'Создаём…' : 'Создать аккаунт' }}
        </button>
        <p>
          Уже есть аккаунт?
          <NuxtLink to="/login">Войти</NuxtLink>
        </p>
      </form>
    </div>
  </section>
</template>
