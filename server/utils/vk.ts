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
  'единобор',
  'зож',
  'пауэр',
  'powerlift',
  'качал',
  'тренер',
  'марафон',
  'функционал',
  'hiit',
  'swimming',
  'running'
]

/**
 * Hard reject: intimate / escort / transactional sex signals in public text.
 * Keep patterns specific enough to avoid false positives on normal chat.
 */
const BLOCKED_PATTERNS: RegExp[] = [
  /эскорт/i,
  /\bescort\b/i,
  /интим(?!\w)/i,
  /вирт(уал)?/i,
  /секс\s*за\s*деньг/i,
  /только\s*секс/i,
  /ищу\s*секс/i,
  /хочу\s*секс/i,
  /секс\s*без\s*обязат/i,
  /с\s*выездом/i,
  /выезд\s*к\s*тебе/i,
  /массаж\s*(интим|с\s*продолжен)/i,
  /ищу\s*спонсор/i,
  /ищ(у|ет)\s*содержан/i,
  /\bsugar\s*(daddy|baby)\b/i,
  /сахарн(ый|ая)\s*(папа|мама|дет)/i,
  /час\s*(от|=|:)?\s*\d{3,}/i,
  /\d{3,}\s*(руб|₽)\s*\/?\s*(час|встречу)/i,
  /индивидуалк/i,
  /\b18\+\s*услуг/i,
  /услуги\s*для\s*мужчин/i,
  /досуг\s*для\s*мужчин/i,
  /снят(ь|ие)\s*на\s*ночь/i,
  /\bonlyfans\b/i,
  /\bbabes?\b/i
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

/** Hard filter: VK must report male. */
export function isMaleProfile(user: VkUser): boolean {
  return user.sex === 2
}

export type ScoreResult = {
  score: number
  signals: {
    /** Open to meeting people (friends / lifestyle / relationship) — not escort. */
    activelyLooking: boolean
    sport: boolean
    hasPhoto: boolean
    blocked: boolean
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
  return [user.first_name, user.last_name, user.status, user.interests, user.activities, user.about]
    .filter(Boolean)
    .join(' ')
    .toLowerCase()
}

/** True if public text looks like escort / intimate services. */
export function hasBlockedContent(user: VkUser): boolean {
  const blob = textBlob(user)
  return BLOCKED_PATTERNS.some((re) => re.test(blob))
}

export function scoreProfile(user: VkUser): ScoreResult {
  const blob = textBlob(user)
  const matchedWords = SPORT_WORDS.filter((w) => blob.includes(w))
  const sport = matchedWords.length > 0 || user.personal?.life_main === 1
  const blocked = BLOCKED_PATTERNS.some((re) => re.test(blob))

  // Open to connect: friends, training partners, like-minded — not transactional intimacy.
  // VK relation 6 = «в активном поиске» (kept as soft signal of openness).
  const activelyLooking =
    !blocked &&
    (user.relation === 6 ||
      /в\s*поиске|ищу\s*(общения|друз|компанию|единомышлен|партн[её]ра\s*по\s*(спорт|трен)|парня|мужчину|девушку|женщину|девушки|отношен)|open\s*to\s*(meet|friends)|active\s*search/i.test(
        blob
      ))

  const hasPhoto = Boolean(user.photo_200 || user.photo_max)
  const age = parseAge(user.bdate)

  let score = 0
  if (hasPhoto) score += 1
  if (sport) score += 3
  if (activelyLooking) score += 1.5
  if (isAllowedCatalogAge(age)) score += 0.5
  if (blocked) score = 0

  return {
    score,
    signals: {
      activelyLooking,
      sport,
      hasPhoto,
      blocked,
      age,
      relation: user.relation ?? null,
      matchedWords
    }
  }
}

/** Catalog gate: adult + photo + sport + open + not blocked. */
export function passesCatalogPolicy(scored: ScoreResult): boolean {
  return (
    !scored.signals.blocked &&
    scored.signals.sport &&
    scored.signals.activelyLooking &&
    scored.signals.hasPhoto &&
    isAllowedCatalogAge(scored.signals.age) &&
    scored.score >= 2
  )
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
