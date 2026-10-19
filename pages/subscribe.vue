<script setup lang="ts">
const { me, refresh: refreshMe } = useAuth()
await refreshMe()
const { data: info } = await useFetch('/api/payments/info')

const route = useRoute()

const note = ref('')
const message = ref('')
const error = ref('')
const pending = ref(false)
const robokassaError = ref('')
const robokassaPending = ref(false)
const cancelPending = ref(false)
const waitingApproval = ref(Boolean(me.value?.pendingClaim && !me.value?.subscribed))

/** Robokassa claims never get stuck waiting on Telegram — show retry/cancel instead of a dead end. */
const isRobokassaPending = computed(() => me.value?.pendingClaim?.provider === 'robokassa')
/** Disable both pay actions while either one is in flight, so the user can't fire two at once. */
const payActionsBusy = computed(() => pending.value || robokassaPending.value)

usePageSeo({
  title: 'Доступ к полной подборке',
  description:
    'Оформите доступ к полной ленте Fitnessgirl Meet: люди спорта в Москве и прямые ссылки на VK.',
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

async function payWithRobokassa() {
  robokassaError.value = ''
  robokassaPending.value = true
  try {
    // Backend reuses the existing unpaid Robokassa claim (if any) and returns a fresh paymentUrl
    // for the same InvId, so this doubles as the "Попробовать снова" retry action.
    const res = await $fetch<{ paymentUrl: string }>('/api/payments/robokassa/create', {
      method: 'POST'
    })
    await navigateTo(res.paymentUrl, { external: true })
  } catch (e: any) {
    const status = e?.statusCode || e?.status || e?.data?.statusCode
    const msg = e?.data?.statusMessage || 'Не удалось создать платёж'
    if (status === 409) {
      message.value = 'Заявка уже на проверке. Ждём подтверждение — страница обновится сама.'
      await refreshMe()
      startWaitingForApproval()
    } else {
      robokassaError.value = msg
    }
  } finally {
    robokassaPending.value = false
  }
}

async function cancelRobokassa() {
  robokassaError.value = ''
  cancelPending.value = true
  try {
    await $fetch('/api/payments/robokassa/cancel', { method: 'POST' })
    message.value = ''
    error.value = ''
    waitingApproval.value = false
    stopPolling()
    await refreshMe()
  } catch (e: any) {
    const msg = e?.data?.statusMessage || 'Не удалось отменить заявку'
    robokassaError.value = msg
  } finally {
    cancelPending.value = false
  }
}

onMounted(async () => {
  const rk = route.query.rk

  // FailURL: reject unpaid Robokassa claim immediately so the user can pay again
  // (admin/Telegram remain for manual claims and as a fallback for stuck Robokassa ones).
  if (rk === 'fail') {
    waitingApproval.value = false
    stopPolling()
    try {
      if (me.value?.pendingClaim?.provider === 'robokassa') {
        await $fetch('/api/payments/robokassa/cancel', { method: 'POST' })
      }
    } catch {
      /* already rejected / no claim — still show retry */
    }
    await refreshMe()
    robokassaError.value = 'Платёж не завершён. Можно оплатить снова.'
    return
  }

  if (rk === 'ok' && !me.value?.subscribed) {
    message.value = 'Платёж получен — активируем доступ…'
    startWaitingForApproval()
    return
  }

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
      <p v-if="info?.robokassaEnabled" class="lead">
        Оплатите картой или через СБП — доступ открывается сразу после оплаты.
        Также можно перевести на Сбер вручную, если это удобнее.
      </p>
      <p v-else class="lead">
        Оплата переводом на карту / СБП.
        <strong>Переводить нужно только на реквизиты Сбербанка</strong>
        (карта или СБП ниже) — откуда отправляете, не важно.
        После поступления средств админ подтверждает заявку — доступ на
        {{ info?.days || 30 }} дней.
      </p>

      <div v-if="me?.subscribed" class="panel" style="margin-bottom: 1.25rem">
        <strong style="color: var(--accent)">Подписка активна.</strong>
        <p style="margin: 0.5rem 0 0; color: var(--muted)">Можно открывать полную подборку и ссылки VK.</p>
        <NuxtLink class="btn btn-primary" style="margin-top: 1rem" to="/catalog">К подборке</NuxtLink>
      </div>

      <div v-else-if="waitingApproval" class="panel" style="margin-bottom: 1.25rem">
        <strong>Заявка на проверке</strong>
        <p v-if="isRobokassaPending" style="margin: 0.5rem 0 0; color: var(--muted)">
          Оплата прошла — доступ откроется автоматически. Если страница зависла, админ может подтвердить
          заявку вручную. Если передумали до оплаты — отмените и оплатите снова.
        </p>
        <p v-else style="margin: 0.5rem 0 0; color: var(--muted)">
          Как только перевод подтвердят в Telegram или админке, здесь сразу появится доступ к анкетам —
          перезагружать страницу не нужно.
        </p>
        <p v-if="message" class="ok" style="margin-top: 0.75rem">{{ message }}</p>
        <p v-if="robokassaError" class="error" style="margin-top: 0.75rem">{{ robokassaError }}</p>
        <p class="waiting-pulse" aria-live="polite">
          {{ isRobokassaPending ? 'Активируем доступ…' : 'Ожидаем подтверждение…' }}
        </p>
        <div v-if="isRobokassaPending" style="display: flex; gap: 0.5rem; flex-wrap: wrap; margin-top: 1rem">
          <button
            class="btn btn-ghost"
            type="button"
            :disabled="payActionsBusy || cancelPending"
            @click="cancelRobokassa"
          >
            {{ cancelPending ? 'Отменяем…' : 'Отменить и оплатить снова' }}
          </button>
        </div>
      </div>

      <div v-if="!me?.user" class="panel">
        <p style="color: var(--muted)">Сначала войдите или зарегистрируйтесь.</p>
        <div style="display: flex; gap: 0.5rem; flex-wrap: wrap">
          <NuxtLink class="btn btn-primary" to="/register">Регистрация</NuxtLink>
          <NuxtLink class="btn btn-ghost" to="/login">Вход</NuxtLink>
        </div>
      </div>

      <template v-else-if="!me.subscribed && !waitingApproval">
        <div v-if="info?.robokassaEnabled" class="panel" style="margin-bottom: 1.25rem">
          <p style="margin: 0 0 0.75rem; color: var(--muted)">
            {{ info?.priceRub || 450 }} ₽ · доступ на {{ info?.days || 30 }} дней
          </p>
          <p v-if="robokassaError" class="error">{{ robokassaError }}</p>
          <button class="btn btn-primary" type="button" :disabled="payActionsBusy" @click="payWithRobokassa">
            {{ robokassaPending ? 'Открываем оплату…' : 'Оплатить картой / СБП' }}
          </button>
        </div>

        <div class="panel">
          <h2 v-if="info?.robokassaEnabled" style="margin-top: 0">Или перевод на Сбер вручную</h2>
          <p class="bank-notice" role="note">
            Обязательно: перевод только <strong>на Сбербанк</strong> (реквизиты ниже). Банк отправителя любой.
          </p>
          <dl>
            <dt>Банк получателя</dt>
            <dd>{{ info?.bank || 'Сбербанк' }}</dd>
            <dt>Сумма</dt>
            <dd>{{ info?.priceRub || 450 }} ₽</dd>
            <dt>Срок</dt>
            <dd>{{ info?.days || 30 }} дней</dd>
            <dt>Получатель</dt>
            <dd>{{ info?.holder || '—' }}</dd>
            <dt>Карта Сбербанка</dt>
            <dd>{{ info?.card || '—' }}</dd>
            <dt>СБП / телефон Сбербанка</dt>
            <dd>{{ info?.phone || '—' }}</dd>
          </dl>

          <form class="form" style="max-width: none" @submit.prevent="claim">
            <label>
              Комментарий к переводу (необязательно: последние 4 цифры, имя отправителя)
              <input v-model="note" type="text" maxlength="200" placeholder="Например: перевод от Ивана, ****1234" />
            </label>
            <p v-if="error" class="error">{{ error }}</p>
            <p v-if="message" class="ok">{{ message }}</p>
            <button class="btn btn-primary" type="submit" :disabled="payActionsBusy">
              {{ pending ? 'Отправляем…' : 'Я перевёл на Сбербанк' }}
            </button>
          </form>
        </div>
      </template>
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
