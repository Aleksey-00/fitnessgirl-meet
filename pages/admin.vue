<script setup lang="ts">
definePageMeta({
  middleware: 'admin'
})

const { data: claims, refresh: refreshClaims } = await useFetch('/api/admin/claims')
const { data: indexerStatus, refresh: refreshIndexer } = await useFetch('/api/admin/indexer')

const busyId = ref<string | null>(null)
const error = ref('')

const token = ref('')
const limit = ref(100)
const mode = ref<'daily' | 'full'>('daily')
const saveToken = ref(true)
const indexing = ref(false)
const logs = ref('')
const logEl = ref<HTMLElement | null>(null)

usePageSeo({
  title: 'Админ',
  description: 'Панель модерации платежей и индексации VK.',
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

function appendLog(chunk: string) {
  logs.value += chunk
  nextTick(() => {
    if (logEl.value) logEl.value.scrollTop = logEl.value.scrollHeight
  })
}

async function startIndexer() {
  error.value = ''
  if (!token.value.trim()) {
    error.value = 'Вставьте VK access token'
    return
  }
  indexing.value = true
  logs.value = ''
  try {
    const res = await fetch('/api/admin/indexer', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        token: token.value.trim(),
        limit: Number(limit.value) || 100,
        mode: mode.value,
        saveToken: saveToken.value
      }),
      credentials: 'same-origin'
    })
    if (!res.ok) {
      const msg = await res.text()
      throw new Error(msg || `HTTP ${res.status}`)
    }
    const reader = res.body?.getReader()
    if (!reader) throw new Error('Нет потока логов')
    const dec = new TextDecoder()
    while (true) {
      const { done, value } = await reader.read()
      if (done) break
      appendLog(dec.decode(value, { stream: true }))
    }
  } catch (e: any) {
    error.value = e?.message || 'Ошибка индексации'
    appendLog(`\n# client error: ${error.value}\n`)
  } finally {
    indexing.value = false
    await refreshIndexer()
  }
}
</script>

<template>
  <section class="section">
    <div class="container">
      <h1>Админ</h1>
      <p v-if="error" class="form error">{{ error }}</p>

      <h2 class="admin-h2">Пополнить базу VK</h2>
      <p class="lead">
        Вставьте токен (строка или кусок URL с <code>access_token=</code>), нажмите кнопку — ниже пойдёт живой лог.
      </p>

      <div v-if="indexerStatus && !indexerStatus.available" class="form error" style="max-width: 720px">
        Индексатор недоступен: {{ indexerStatus.reason }}
      </div>

      <form class="form admin-index-form" @submit.prevent="startIndexer">
        <label>
          VK_ACCESS_TOKEN
          <textarea
            v-model="token"
            rows="3"
            placeholder="vk1.a.... или …access_token=…&expires_in=0"
            :disabled="indexing"
            autocomplete="off"
          />
        </label>
        <label>
          Режим
          <select v-model="mode" :disabled="indexing">
            <option value="daily">Daily (~лимит новых анкет)</option>
            <option value="full">Full (длинный прогон)</option>
          </select>
        </label>
        <label>
          Лимит
          <input v-model.number="limit" type="number" min="1" max="2000" :disabled="indexing" />
        </label>
        <label class="check">
          <input v-model="saveToken" type="checkbox" :disabled="indexing" />
          Сохранить токен в .env на сервере
        </label>
        <button
          class="btn btn-primary"
          type="submit"
          :disabled="indexing || (indexerStatus && !indexerStatus.available)"
        >
          {{ indexing ? 'Идёт индексация…' : 'Пополнить базу' }}
        </button>
      </form>

      <pre ref="logEl" class="admin-log" aria-live="polite">{{ logs || 'Лог появится здесь…' }}</pre>

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
.admin-index-form select {
  width: 100%;
  border-radius: 12px;
  border: 1px solid var(--line);
  background: rgba(255, 255, 255, 0.04);
  color: var(--ink);
  padding: 0.75rem 0.85rem;
}
.check {
  display: flex !important;
  align-items: center;
  gap: 0.5rem;
  grid-template-columns: none;
}
.admin-log {
  margin-top: 1rem;
  max-width: 960px;
  max-height: 420px;
  overflow: auto;
  padding: 1rem;
  border-radius: 12px;
  border: 1px solid var(--line);
  background: #0b0f0c;
  color: #c8f06c;
  font-size: 0.8rem;
  line-height: 1.45;
  white-space: pre-wrap;
  word-break: break-word;
}
</style>
