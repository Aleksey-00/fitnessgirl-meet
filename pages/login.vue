<script setup lang="ts">
const email = ref('')
const password = ref('')
const error = ref('')
const pending = ref(false)

usePageSeo({
  title: 'Вход',
  description: 'Вход в аккаунт Fitnessgirl Meet.',
  path: '/login',
  noindex: true
})

async function submit() {
  error.value = ''
  pending.value = true
  try {
    const digest = await passwordDigest(password.value)
    try {
      await $fetch('/api/auth/login', {
        method: 'POST',
        body: { email: email.value, password: digest }
      })
    } catch (e: any) {
      // Old accounts: one bridge login with plaintext, then hash is upgraded to digest-only.
      if (e?.statusCode !== 401 && e?.status !== 401) throw e
      await $fetch('/api/auth/login', {
        method: 'POST',
        body: {
          email: email.value,
          password: digest,
          passwordLegacy: password.value
        }
      })
    }
    const { refresh } = useAuth()
    await refresh()
    clearNuxtData('catalog-first-page')
    await navigateTo('/catalog')
  } catch (e: any) {
    error.value = e?.data?.statusMessage || 'Ошибка входа'
  } finally {
    pending.value = false
  }
}
</script>

<template>
  <section class="section">
    <div class="container">
      <h1>Вход</h1>
      <p class="lead">Войдите, чтобы оформить подписку и открыть ссылки на VK.</p>
      <form class="form" @submit.prevent="submit">
        <label>
          Email
          <input v-model="email" type="email" required autocomplete="email" />
        </label>
        <label>
          Пароль
          <input v-model="password" type="password" required minlength="8" autocomplete="current-password" />
        </label>
        <p v-if="error" class="error">{{ error }}</p>
        <button class="btn btn-primary" type="submit" :disabled="pending">
          {{ pending ? 'Входим…' : 'Войти' }}
        </button>
        <p>
          Нет аккаунта?
          <NuxtLink to="/register">Регистрация</NuxtLink>
        </p>
      </form>
    </div>
  </section>
</template>
