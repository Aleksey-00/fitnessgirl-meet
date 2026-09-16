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
        credentials: 'include',
        body: { email: email.value, password: digest }
      })
    } catch (e: any) {
      // Old accounts: one bridge login with plaintext, then hash is upgraded to digest-only.
      if (e?.statusCode !== 401 && e?.status !== 401) throw e
      await $fetch('/api/auth/login', {
        method: 'POST',
        credentials: 'include',
        body: {
          email: email.value,
          password: digest,
          passwordLegacy: password.value
        }
      })
    }
  } catch (e: any) {
    const status = e?.statusCode || e?.status
    const msg = e?.data?.statusMessage || e?.statusMessage || e?.message
    if (status === 401) {
      error.value = msg || 'Неверный email или пароль'
    } else if (!status || status === 502 || status === 503 || status === 504) {
      error.value =
        'Сервер не ответил. Откройте https://www.fitnessgirl-meet.ru/login (именно www) и отключите VPN для этого сайта.'
    } else {
      error.value = msg || `Ошибка входа${status ? ` (${status})` : ''}`
    }
    pending.value = false
    return
  }

  // Full reload so httpOnly session cookie is picked up; skip useAuth().ready (not exported).
  try {
    clearNuxtData('catalog-first-page')
  } catch {
    /* ignore */
  }
  window.location.assign('/catalog')
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
