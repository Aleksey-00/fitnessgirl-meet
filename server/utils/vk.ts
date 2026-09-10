const SPORT_WORDS = [
  'спорт',
  'фитнес',
  'зал',
  'тренир',
  'yoga',
  'йога',
  'бег',
  'crossfit',
  'кроссфит',
  'танц',
  'плаван',
  'gym',
  'workout',
  'пилатес',
  'растяж',
  'вело',
  'лыж',
  'бокс',
  'единобор'
]

export type VkUser = {
  id: number
  first_name?: string
  last_name?: string
  /** VK: 1 = female, 2 = male, 0 = not specified */
  sex?: number
  bdate?: string
  photo_200?: string
  photo_max?: string
  city?: { id: number; title?: string }
  relation?: number
  status?: string
  interests?: string
  activities?: string
  about?: string
  personal?: { life_main?: number; people_main?: number }
}

/** Hard filter: VK must report female. Photo analyzer catches mislabeled males. */
export function isFemaleProfile(user: VkUser): boolean {
  return user.sex === 1
}

export type ScoreResult = {
  score: number
  signals: {
    activelyLooking: boolean
    sport: boolean
    hasPhoto: boolean
    age?: number | null
    relation?: number | null
    matchedWords: string[]
  }
}

export function parseAge(bdate?: string): number | null {
  if (!bdate) return null
  const parts = bdate.split('.').map(Number)
  // Require full date with year — day.month alone cannot prove adulthood
  if (parts.length < 3 || !parts[2] || parts[2] < 1950) return null
  const [d, m, y] = parts
  if (!d || !m || d < 1 || d > 31 || m < 1 || m > 12) return null
  const birth = new Date(y, m - 1, d)
  if (Number.isNaN(birth.getTime())) return null
  if (birth.getFullYear() !== y || birth.getMonth() !== m - 1 || birth.getDate() !== d) return null
  const now = new Date()
  let age = now.getFullYear() - birth.getFullYear()
  const md = now.getMonth() - birth.getMonth()
  if (md < 0 || (md === 0 && now.getDate() < birth.getDate())) age -= 1
  if (age < 0 || age > 100) return null
  return age
}

/** Catalog policy: only adults 18–35 with a verified numeric age. */
export function isAllowedCatalogAge(age: number | null | undefined): age is number {
  return typeof age === 'number' && Number.isInteger(age) && age >= 18 && age <= 35
}

function textBlob(user: VkUser): string {
  return [user.status, user.interests, user.activities, user.about]
    .filter(Boolean)
    .join(' ')
    .toLowerCase()
}

export function scoreProfile(user: VkUser): ScoreResult {
  const blob = textBlob(user)
  const matchedWords = SPORT_WORDS.filter((w) => blob.includes(w))
  const sport = matchedWords.length > 0 || user.personal?.life_main === 1
  // VK relation: 6 = в активном поиске
  const activelyLooking =
    user.relation === 6 ||
    /в\s*поиске|ищу\s*(парня|мужчину|отношен)|active\s*search/i.test(blob)
  const hasPhoto = Boolean(user.photo_200 || user.photo_max)
  const age = parseAge(user.bdate)

  let score = 0
  if (hasPhoto) score += 1
  if (activelyLooking) score += 2
  if (sport) score += 2
  if (isAllowedCatalogAge(age)) score += 0.5

  return {
    score,
    signals: {
      activelyLooking,
      sport,
      hasPhoto,
      age,
      relation: user.relation ?? null,
      matchedWords
    }
  }
}

export async function vkApi<T>(method: string, params: Record<string, string | number | undefined>, token: string): Promise<T> {
  const url = new URL(`https://api.vk.com/method/${method}`)
  url.searchParams.set('access_token', token)
  url.searchParams.set('v', '5.199')
  for (const [k, v] of Object.entries(params)) {
    if (v !== undefined && v !== '') url.searchParams.set(k, String(v))
  }
  const res = await fetch(url)
  if (!res.ok) {
    throw new Error(`VK HTTP ${res.status}`)
  }
  const data = (await res.json()) as { response?: T; error?: { error_msg: string; error_code: number } }
  if (data.error) {
    throw new Error(`VK API ${data.error.error_code}: ${data.error.error_msg}`)
  }
  return data.response as T
}
