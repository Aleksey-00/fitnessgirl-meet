<script setup lang="ts">
const email = ref('')
const password = ref('')
const gender = ref<'male' | 'female' | ''>('')
const error = ref('')
const pending = ref(false)

usePageSeo({
  title: 'Регистрация',
  description:
    'Создайте аккаунт Fitnessgirl Meet: укажите пол и получите доступ к подборке людей со спортивным образом жизни.',
  path: '/register',
  noindex: true
})

async function submit() {
  error.value = ''
  if (gender.value !== 'male' && gender.value !== 'female') {
    error.value = 'Укажите пол'
    return
  }
  pending.value = true
  try {
    const digest = await passwordDigest(password.value)
    await $fetch('/api/auth/register', {
      method: 'POST',
      credentials: 'include',
      body: { email: email.value, password: digest, gender: gender.value }
    })
    clearNuxtData('catalog-first-page')
    window.location.assign('/subscribe')
  } catch (e: any) {
    error.value = e?.data?.statusMessage || 'Ошибка регистрации'
    pending.value = false
  }
}
</script>

<template>
  <section class="section">
    <div class="container">
      <h1>Регистрация</h1>
      <p class="lead">
        Укажите пол: мужчины видят подборку девушек из спорта, девушки — подборку парней. Дальше
        перевод на Сбербанк и активация доступа.
      </p>
      <form class="form" @submit.prevent="submit">
        <fieldset class="gender-fieldset">
          <legend>Пол</legend>
          <label class="gender-option">
            <input v-model="gender" type="radio" name="gender" value="male" required />
            Я мужчина
          </label>
          <label class="gender-option">
            <input v-model="gender" type="radio" name="gender" value="female" required />
            Я девушка
          </label>
        </fieldset>
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

<style scoped>
.gender-fieldset {
  border: 0;
  margin: 0 0 1rem;
  padding: 0;
  display: grid;
  gap: 0.5rem;
}
.gender-fieldset legend {
  font-weight: 600;
  margin-bottom: 0.35rem;
}
.gender-option {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-weight: 500;
  cursor: pointer;
}
.gender-option input {
  width: auto;
  margin: 0;
}
</style>
