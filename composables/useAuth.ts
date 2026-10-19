export type PendingClaim = {
  id: string
  /** manual | robokassa | yookassa */
  provider: string
  /** Set once the provider confirms payment (manual claims keep this null). */
  paidAt: string | null
}

export type AuthMe = {
  user: { id: string; email: string; role: string; gender?: 'male' | 'female' } | null
  subscribed: boolean
  pendingClaim?: PendingClaim | null
}

/**
 * Auth state backed by httpOnly cookie.
 * Uses useRequestFetch so SSR forwards cookies — hard refresh keeps the session.
 */
export function useAuth() {
  const me = useState<AuthMe | null>('auth-me', () => null)
  const ready = useState('auth-ready', () => false)

  /** Prefer requestFetch on SSR (forwards cookies); on client force credentials. */
  async function apiFetch<T>(url: string, opts: Record<string, unknown> = {}) {
    if (import.meta.server) {
      const requestFetch = useRequestFetch()
      return requestFetch<T>(url, opts as any)
    }
    return $fetch<T>(url, { ...opts, credentials: 'include' })
  }

  async function refresh() {
    me.value = await apiFetch<AuthMe>('/api/auth/me')
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
    await apiFetch('/api/auth/logout', { method: 'POST' })
    me.value = { user: null, subscribed: false, pendingClaim: null }
    ready.value = true
    if (import.meta.client) {
      window.location.assign('/')
      return
    }
    await navigateTo('/')
  }

  return { me, refresh, ensureLoaded, logout }
}
