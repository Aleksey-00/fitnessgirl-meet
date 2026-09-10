<script setup lang="ts">
const { me, ensureLoaded, logout } = useAuth()
await ensureLoaded()

const menuOpen = ref(false)
const route = useRoute()

watch(
  () => route.fullPath,
  () => {
    menuOpen.value = false
  }
)

function toggleMenu() {
  menuOpen.value = !menuOpen.value
}

function closeMenu() {
  menuOpen.value = false
}

async function onLogout() {
  closeMenu()
  await logout()
}

function onKeydown(e: KeyboardEvent) {
  if (e.key === 'Escape') closeMenu()
}

onMounted(() => {
  window.addEventListener('keydown', onKeydown)
})

onBeforeUnmount(() => {
  window.removeEventListener('keydown', onKeydown)
  if (import.meta.client) document.documentElement.style.overflow = ''
})

watch(menuOpen, (open) => {
  if (!import.meta.client) return
  document.documentElement.style.overflow = open ? 'hidden' : ''
})
</script>

<template>
  <div>
    <header class="site-header">
      <div class="container site-header__inner">
        <NuxtLink to="/" class="brand" @click="closeMenu">
          Fitnessgirl <span>Meet</span>
        </NuxtLink>

        <button
          class="nav-toggle"
          type="button"
          :aria-expanded="menuOpen"
          aria-controls="site-nav"
          :aria-label="menuOpen ? 'Закрыть меню' : 'Открыть меню'"
          @click="toggleMenu"
        >
          <span class="nav-toggle__bar" />
          <span class="nav-toggle__bar" />
          <span class="nav-toggle__bar" />
        </button>

        <div
          class="nav-backdrop"
          :class="{ 'nav-backdrop--open': menuOpen }"
          aria-hidden="true"
          @click="closeMenu"
        />

        <nav id="site-nav" class="nav" :class="{ 'nav--open': menuOpen }">
          <NuxtLink to="/catalog" @click="closeMenu">Анкеты</NuxtLink>
          <NuxtLink to="/subscribe" @click="closeMenu">Подписка</NuxtLink>
          <NuxtLink to="/disclaimer" @click="closeMenu">Дисклеймер</NuxtLink>
          <NuxtLink to="/opt-out" @click="closeMenu">Opt-out</NuxtLink>
          <template v-if="me?.user">
            <NuxtLink v-if="me.user.role === 'admin'" to="/admin" @click="closeMenu">Админ</NuxtLink>
            <span class="nav__email">{{ me.user.email }}</span>
            <button class="btn btn-ghost" type="button" @click="onLogout">Выйти</button>
          </template>
          <template v-else>
            <NuxtLink to="/login" @click="closeMenu">Вход</NuxtLink>
            <NuxtLink to="/register" class="btn btn-primary" @click="closeMenu">Регистрация</NuxtLink>
          </template>
        </nav>
      </div>
    </header>

    <main>
      <slot />
    </main>

    <footer class="site-footer">
      <div class="container">
        Публичные профили VK через API ·
        <NuxtLink to="/disclaimer">дисклеймер</NuxtLink> ·
        <NuxtLink to="/opt-out">удалить анкету</NuxtLink>
      </div>
    </footer>
  </div>
</template>
