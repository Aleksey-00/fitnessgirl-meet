<script setup lang="ts">
const vk = ref('')
const contact = ref('')
const message = ref('')
const error = ref('')
const pending = ref(false)

usePageSeo({
  title: 'Удалить анкету из каталога',
  description: 'Запросите скрытие своей анкеты из Fitnessgirl Meet по VK id или ссылке на профиль.',
  path: '/opt-out'
})

async function submit() {
  error.value = ''
  message.value = ''
  pending.value = true
  try {
    const res = await $fetch<{ message: string }>('/api/opt-out', {
      method: 'POST',
      body: { vk: vk.value, contact: contact.value || undefined }
    })
    message.value = res.message
    vk.value = ''
    contact.value = ''
  } catch (e: any) {
    error.value = e?.data?.statusMessage || 'Ошибка отправки'
  } finally {
    pending.value = false
  }
}
</script>

<template>
  <section class="section">
    <div class="container">
      <h1>Удалить анкету</h1>
      <p class="lead">
        Укажите числовой VK id или ссылку вида vk.com/id123 / vk.ru/id123. При распознанном id профиль скрывается сразу.
      </p>
      <form class="form" @submit.prevent="submit">
        <label>
          VK id или ссылка
          <input v-model="vk" type="text" required placeholder="https://vk.com/id123456" />
        </label>
        <label>
          Контакт для связи (необязательно)
          <input v-model="contact" type="text" placeholder="email или telegram" />
        </label>
        <p v-if="error" class="error">{{ error }}</p>
        <p v-if="message" class="ok">{{ message }}</p>
        <button class="btn btn-primary" type="submit" :disabled="pending">
          {{ pending ? 'Отправляем…' : 'Скрыть из каталога' }}
        </button>
      </form>
    </div>
  </section>
</template>
