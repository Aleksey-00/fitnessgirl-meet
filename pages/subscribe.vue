<script setup lang="ts">
const { me, refresh: refreshMe } = useAuth()
await refreshMe()
const { data: info } = await useFetch('/api/payments/info')

const note = ref('')
const message = ref('')
const error = ref('')
const pending = ref(false)
const waitingApproval = ref(Boolean(me.value?.pendingClaim && !me.value?.subscribed))

usePageSeo({
  title: 'Подписка на каталог анкет',
  description:
    'Оформите доступ к полной ленте анкет Fitnessgirl Meet: спортивные девушки в Москве и прямые ссылки на VK.',
  path: '/subscribe'
})

let pollTimer: ReturnType<typeof setTimeout> | null = null
let pollUntil = 0

function stopPolling() {
  if (pollTimer) {
    clearTimeout(pollTimer)
    pollTimer = null
  }
}

function schedulePoll() {
  stopPolling()
  if (!import.meta.client) return
  pollTimer = setTimeout(async () => {
    try {
      const next = await refreshMe()
      if (next?.subscribed) {
        waitingApproval.value = false
        message.value = 'Подписка активирована — можно открывать анкеты.'
        return
      }
      if (Date.now() < pollUntil && waitingApproval.value) {
        schedulePoll()
      }
    } catch {
      if (Date.now() < pollUntil && waitingApproval.value) {
        schedulePoll()
      }
    }
  }, 2500)
}

function startWaitingForApproval() {
  waitingApproval.value = true
  pollUntil = Date.now() + 30 * 60_000
  schedulePoll()
}

async function claim() {
  error.value = ''
  message.value = ''
  pending.value = true
  try {
    await $fetch('/api/payments/claim', {
      method: 'POST',
      body: { note: note.value || undefined }
    })
    message.value = 'Заявка отправлена. Ждём подтверждение — страница обновится сама.'
    await refreshMe()
    startWaitingForApproval()
  } catch (e: any) {
    const status = e?.statusCode || e?.status || e?.data?.statusCode
    const msg = e?.data?.statusMessage || 'Не удалось отправить заявку'
    if (status === 409) {
      message.value = 'Заявка уже на проверке. Ждём подтверждение — страница обновится сама.'
      error.value = ''
      await refreshMe()
      startWaitingForApproval()
    } else {
      error.value = msg
    }
  } finally {
    pending.value = false
  }
}

onMounted(() => {
  if (waitingApproval.value) startWaitingForApproval()
})

onBeforeUnmount(() => {
  stopPolling()
})

watch(
  () => me.value?.subscribed,
  (subscribed) => {
    if (subscribed) {
      waitingApproval.value = false
      stopPolling()
    }
  }
)
</script>

<template>
  <section class="section">
    <div class="container">
      <h1>Подписка</h1>
      <p class="lead">
        Оплата переводом на карту / СБП.
        <strong>Перевод нужно отправлять только через Сбербанк</strong>
        (перевод из другого банка можем не принять).
        После поступления средств админ подтверждает заявку — доступ на
        {{ info?.days || 30 }} дней.
      </p>

      <div v-if="me?.subscribed" class="panel" style="margin-bottom: 1.25rem">
        <strong style="color: var(--accent)">Подписка активна.</strong>
        <p style="margin: 0.5rem 0 0; color: var(--muted)">Можно открывать полный каталог и ссылки VK.</p>
        <NuxtLink class="btn btn-primary" style="margin-top: 1rem" to="/catalog">К анкетам</NuxtLink>
      </div>

      <div v-else-if="waitingApproval" class="panel" style="margin-bottom: 1.25rem">
        <strong>Заявка на проверке</strong>
        <p style="margin: 0.5rem 0 0; color: var(--muted)">
          Как только перевод подтвердят в Telegram или админке, здесь сразу появится доступ к анкетам —
          перезагружать страницу не нужно.
        </p>
        <p v-if="message" class="ok" style="margin-top: 0.75rem">{{ message }}</p>
        <p class="waiting-pulse" aria-live="polite">Ожидаем подтверждение…</p>
      </div>

      <div class="panel">
        <p class="bank-notice" role="note">
          Обязательно: перевод только из приложения / онлайн-банка <strong>Сбербанк</strong>.
        </p>
        <dl>
          <dt>Банк</dt>
          <dd>{{ info?.bank || 'Сбербанк' }}</dd>
          <dt>Сумма</dt>
          <dd>{{ info?.priceRub || 990 }} ₽</dd>
          <dt>Срок</dt>
          <dd>{{ info?.days || 30 }} дней</dd>
          <dt>Получатель</dt>
          <dd>{{ info?.holder || '—' }}</dd>
          <dt>Карта (Сбер)</dt>
          <dd>{{ info?.card || '—' }}</dd>
          <dt>СБП / телефон (Сбер)</dt>
          <dd>{{ info?.phone || '—' }}</dd>
        </dl>

        <template v-if="!me?.user">
          <p style="color: var(--muted)">Сначала войдите или зарегистрируйтесь.</p>
          <div style="display: flex; gap: 0.5rem; flex-wrap: wrap">
            <NuxtLink class="btn btn-primary" to="/register">Регистрация</NuxtLink>
            <NuxtLink class="btn btn-ghost" to="/login">Вход</NuxtLink>
          </div>
        </template>

        <form
          v-else-if="!me.subscribed && !waitingApproval"
          class="form"
          style="max-width: none"
          @submit.prevent="claim"
        >
          <label>
            Комментарий к переводу (необязательно: последние 4 цифры, имя в Сбере)
            <input v-model="note" type="text" maxlength="200" placeholder="Например: перевод из Сбера от Ивана, ****1234" />
          </label>
          <p v-if="error" class="error">{{ error }}</p>
          <p v-if="message" class="ok">{{ message }}</p>
          <button class="btn btn-primary" type="submit" :disabled="pending">
            {{ pending ? 'Отправляем…' : 'Я перевёл из Сбербанка' }}
          </button>
        </form>
      </div>
    </div>
  </section>
</template>

<style scoped>
.waiting-pulse {
  margin: 1rem 0 0;
  color: var(--accent);
  font-weight: 600;
  animation: waiting-pulse 1.6s ease-in-out infinite;
}

.bank-notice {
  margin: 0 0 1rem;
  padding: 0.75rem 0.9rem;
  border: 1px solid color-mix(in srgb, var(--accent) 45%, transparent);
  background: color-mix(in srgb, var(--accent) 12%, transparent);
  color: var(--text);
  font-weight: 600;
  line-height: 1.4;
}

@keyframes waiting-pulse {
  0%,
  100% {
    opacity: 0.55;
  }
  50% {
    opacity: 1;
  }
}
</style>
