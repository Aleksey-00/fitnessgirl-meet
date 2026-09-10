export type AuthMe = {
  user: { id: string; email: string; role: string } | null
  subscribed: boolean
  pendingClaim?: boolean
}

/**
 * Auth state backed by httpOnly cookie.
 * Uses useRequestFetch so SSR forwards cookies — hard refresh keeps the session.
 */
export function useAuth() {
  const me = useState<AuthMe | null>('auth-me', () => null)
  const ready = useState('auth-ready', () => false)
  const requestFetch = useRequestFetch()

  async function refresh() {
    me.value = await requestFetch<AuthMe>('/api/auth/me')
    ready.value = true
    return me.value
  }

  async function ensureLoaded() {
    if (!ready.value) {
      await refresh()
    }
    return me.value
  }

  async function logout() {
    await requestFetch('/api/auth/logout', { method: 'POST' })
    me.value = { user: null, subscribed: false, pendingClaim: false }
    ready.value = true
    await navigateTo('/')
  }

  return { me, refresh, ensureLoaded, logout }
}
