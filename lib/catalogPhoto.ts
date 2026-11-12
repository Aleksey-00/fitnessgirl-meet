import { vkApi, type VkUser } from '../server/utils/vk'

export const CATALOG_PLACEHOLDER = {
  female: '/placeholders/catalog-female.svg',
  male: '/placeholders/catalog-male.svg'
} as const

export function catalogPlaceholderUrl(gender: 'female' | 'male') {
  return CATALOG_PLACEHOLDER[gender]
}

export function isCatalogPlaceholderUrl(url: string | null | undefined) {
  if (!url) return false
  return url.includes('/placeholders/catalog-female.svg') || url.includes('/placeholders/catalog-male.svg')
}

type VkSize = { type?: string; url?: string; width?: number; height?: number }
type VkPhoto = {
  id?: number
  sizes?: VkSize[]
  photo_2560?: string
  photo_1280?: string
  photo_807?: string
  photo_604?: string
  photo_130?: string
}

const SIZE_RANK: Record<string, number> = {
  w: 90,
  z: 80,
  y: 70,
  x: 60,
  r: 50,
  q: 40,
  p: 30,
  o: 20,
  m: 10,
  s: 5
}

/** Largest usable URL from one VK photo object. */
export function largestVkPhotoUrl(photo: VkPhoto): string | null {
  if (photo.sizes?.length) {
    let best: VkSize | null = null
    let bestScore = -1
    for (const s of photo.sizes) {
      if (!s?.url) continue
      const area = (s.width || 0) * (s.height || 0)
      const rank = SIZE_RANK[s.type || ''] || 0
      const score = area > 0 ? area : rank * 10_000
      if (score > bestScore) {
        bestScore = score
        best = s
      }
    }
    return best?.url || null
  }
  return (
    photo.photo_2560 ||
    photo.photo_1280 ||
    photo.photo_807 ||
    photo.photo_604 ||
    photo.photo_130 ||
    null
  )
}

/** Deduped candidate URLs: avatar first, then album photos. */
export function mergePhotoCandidates(avatarUrls: Array<string | null | undefined>, albumUrls: string[]) {
  const out: string[] = []
  const seen = new Set<string>()
  for (const raw of [...avatarUrls, ...albumUrls]) {
    const u = (raw || '').trim()
    if (!u || seen.has(u)) continue
    seen.add(u)
    out.push(u)
  }
  return out
}

/**
 * Avatar URLs from users.search/get, then up to `limit` profile album photos via photos.getAll.
 * On API failure returns avatars only (never throws).
 */
export async function listProfilePhotoCandidates(
  user: VkUser,
  token: string,
  opts?: { albumLimit?: number; requestDelayMs?: number }
): Promise<string[]> {
  const albumLimit = opts?.albumLimit ?? 12
  const avatars = mergePhotoCandidates([user.photo_max, user.photo_200], [])
  let albumUrls: string[] = []
  try {
    const res = await vkApi<{ count?: number; items?: VkPhoto[] }>(
      'photos.getAll',
      {
        owner_id: user.id,
        count: albumLimit,
        photo_sizes: 1,
        no_service_albums: 0
      },
      token
    )
    for (const item of res.items || []) {
      const url = largestVkPhotoUrl(item)
      if (url) albumUrls.push(url)
    }
  } catch {
    albumUrls = []
  }
  if (opts?.requestDelayMs) {
    await new Promise((r) => setTimeout(r, opts.requestDelayMs))
  }
  return mergePhotoCandidates(avatars, albumUrls)
}
