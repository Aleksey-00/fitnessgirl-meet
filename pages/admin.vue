<script setup lang="ts">
definePageMeta({
  middleware: 'admin'
})

const { data: claims, refresh: refreshClaims } = await useFetch('/api/admin/claims')
const busyId = ref<string | null>(null)
const error = ref('')

usePageSeo({
  title: 'Админ',
  description: 'Панель модерации платежей.',
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
</script>

<template>
  <section class="section">
    <div class="container">
      <h1>Заявки на оплату</h1>
      <p class="lead">Подтвердите перевод — пользователю откроется подписка.</p>
      <p v-if="error" class="form error">{{ error }}</p>

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
