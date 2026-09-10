export default defineNuxtRouteMiddleware(async () => {
  const { me, ensureLoaded } = useAuth()
  await ensureLoaded()
  if (!me.value?.user || me.value.user.role !== 'admin') {
    return navigateTo('/login')
  }
})
