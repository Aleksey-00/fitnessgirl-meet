<script setup lang="ts">
definePageMeta({
  middleware: 'admin'
})

const { data: claims, refresh: refreshClaims } = await useFetch('/api/admin/claims')
const { data: tokenStatus, refresh: refreshToken } = await useFetch('/api/admin/indexer')

const busyId = ref<string | null>(null)
const error = ref('')
const okMsg = ref('')
const token = ref('')
const saving = ref(false)

usePageSeo({
  title: 'Админ',
  description: 'Панель модерации платежей и VK-токена.',
  path: '/admin',
  noindex: true
})

async function act(claimId: string, action: 'approve' | 'reject') {
  error.value = ''
  busyId.value = claimId
  try {
    await $fetch('/api/admin/claims', {
      method: 'POST',
      body: { claimId, action }
    })
    await refreshClaims()
  } catch (e: any) {
    error.value = e?.data?.statusMessage || 'Ошибка'
  } finally {
    busyId.value = null
  }
}

async function saveVkToken() {
  error.value = ''
  okMsg.value = ''
  if (!token.value.trim()) {
    error.value = 'Вставьте VK access token'
    return
  }
  saving.value = true
  try {
    const res = await $fetch<{ ok: boolean; tokenLength: number; hint: string }>('/api/admin/indexer', {
      method: 'POST',
      body: { token: token.value.trim() }
    })
    okMsg.value = res.hint || 'Токен сохранён'
    token.value = ''
    await refreshToken()
  } catch (e: any) {
    error.value = e?.data?.statusMessage || e?.message || 'Не удалось сохранить токен'
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <section class="section">
    <div class="container">
      <h1>Админ</h1>
      <p v-if="error" class="form error">{{ error }}</p>
      <p v-if="okMsg" class="lead" style="color: var(--accent)">{{ okMsg }}</p>

      <h2 class="admin-h2">VK-токен для индексации</h2>
      <p class="lead">
        Сохраните свежий токен в <code>.env</code> на сервере. Пополнение базы запускайте с домашнего ПК
        (токен привязан к вашему IP):
        <code>./scripts/run-home-indexer.sh</code>
      </p>

      <div v-if="tokenStatus && !tokenStatus.available" class="form error" style="max-width: 720px">
        Нельзя записать .env: {{ tokenStatus.reason }}
      </div>
      <p v-else-if="tokenStatus" class="lead">
        Сейчас в .env:
        <template v-if="tokenStatus.configured">
          токен есть (длина {{ tokenStatus.tokenLength }})
        </template>
        <template v-else>токен не задан</template>
      </p>

      <form class="form admin-index-form" @submit.prevent="saveVkToken">
        <label>
          VK_ACCESS_TOKEN
          <textarea
            v-model="token"
            rows="3"
            placeholder="vk1.a.... или …access_token=…&expires_in=0"
            autocomplete="off"
          />
        </label>
        <button
          class="btn btn-primary"
          type="submit"
          :disabled="saving || (tokenStatus && !tokenStatus.available)"
        >
          {{ saving ? 'Сохраняю…' : 'Сохранить токен' }}
        </button>
      </form>

      <h2 class="admin-h2">Заявки на оплату</h2>
      <p class="lead">Подтвердите перевод — пользователю откроется подписка.</p>

      <div style="overflow-x: auto">
        <table class="table">
          <thead>
            <tr>
              <th>Когда</th>
              <th>Email</th>
              <th>Сумма</th>
              <th>Комментарий</th>
              <th>Статус</th>
              <th />
            </tr>
          </thead>
          <tbody>
            <tr v-for="c in claims || []" :key="c.id">
              <td>{{ new Date(c.createdAt).toLocaleString('ru-RU') }}</td>
              <td>{{ c.user.email }}</td>
              <td>{{ c.amount }} ₽</td>
              <td>{{ c.note || '—' }}</td>
              <td>{{ c.status }}</td>
              <td style="white-space: nowrap">
                <template v-if="c.status === 'pending'">
                  <button
                    class="btn btn-primary"
                    type="button"
                    :disabled="busyId === c.id"
                    @click="act(c.id, 'approve')"
                  >
                    OK
                  </button>
                  <button
                    class="btn btn-danger"
                    type="button"
                    :disabled="busyId === c.id"
                    @click="act(c.id, 'reject')"
                  >
                    Нет
                  </button>
                </template>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
      <p v-if="!(claims || []).length" class="lead">Заявок пока нет.</p>
    </div>
  </section>
</template>

<style scoped>
.admin-h2 {
  margin-top: 2.5rem;
  font-size: 1.35rem;
}
.admin-index-form {
  max-width: 720px;
}
</style>
