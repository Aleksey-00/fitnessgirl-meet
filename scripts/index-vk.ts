import { PrismaClient } from '@prisma/client'
import { isFemaleProfile, isAllowedCatalogAge, scoreProfile, vkApi, type VkUser } from '../server/utils/vk'
import {
  estimateAgeFromPhotoUrl,
  isCatalogFacePass,
  photoAgeCheckEnabled,
  type PhotoAgeEstimate
} from '../lib/photoAge'

const prisma = new PrismaClient()

type SearchResponse = {
  count: number
  items: VkUser[]
}

const DEMO_PROFILES: Array<{
  vkId: bigint
  displayName: string
  age: number
  photoUrl: string
  score: number
  signals: Record<string, unknown>
}> = [
  {
    vkId: 100001n,
    displayName: 'Анна',
    age: 26,
    photoUrl: 'https://images.unsplash.com/photo-1518611012118-696072aa579a?w=400&h=500&fit=crop',
    score: 4.5,
    signals: { sport: true, activelyLooking: true, hasPhoto: true, matchedWords: ['фитнес'] }
  },
  {
    vkId: 100002n,
    displayName: 'Мария',
    age: 29,
    photoUrl: 'https://images.unsplash.com/photo-1571019614242-c5c5dee9f50b?w=400&h=500&fit=crop',
    score: 4,
    signals: { sport: true, activelyLooking: true, hasPhoto: true, matchedWords: ['йога'] }
  },
  {
    vkId: 100003n,
    displayName: 'Екатерина',
    age: 24,
    photoUrl: 'https://images.unsplash.com/photo-1517836357463-d25dfeac3438?w=400&h=500&fit=crop',
    score: 3.5,
    signals: { sport: true, activelyLooking: false, hasPhoto: true, matchedWords: ['зал'] }
  },
  {
    vkId: 100004n,
    displayName: 'Дарья',
    age: 31,
    photoUrl: 'https://images.unsplash.com/photo-1548690312-e3b507d8c110?w=400&h=500&fit=crop',
    score: 3,
    signals: { sport: true, activelyLooking: true, hasPhoto: true, matchedWords: ['бег'] }
  },
  {
    vkId: 100005n,
    displayName: 'Ольга',
    age: 27,
    photoUrl: 'https://images.unsplash.com/photo-1594381898411-846e7d193883?w=400&h=500&fit=crop',
    score: 4.5,
    signals: { sport: true, activelyLooking: true, hasPhoto: true, matchedWords: ['кроссфит'] }
  },
  {
    vkId: 100006n,
    displayName: 'София',
    age: 23,
    photoUrl: 'https://images.unsplash.com/photo-1518310383802-640c2de311b2?w=400&h=500&fit=crop',
    score: 2.5,
    signals: { sport: true, activelyLooking: false, hasPhoto: true, matchedWords: ['танц'] }
  }
]

const NAME_SHARDS = [
  '',
  'анна',
  'мария',
  'елена',
  'ольга',
  'наталья',
  'екатерина',
  'ирина',
  'татьяна',
  'светлана',
  'юлия',
  'анастасия',
  'дарья',
  'алина',
  'виктория',
  'полина',
  'ксения',
  'софия',
  'марина',
  'александра',
  'валерия',
  'кристина',
  'евгения',
  'вероника'
]

async function seedDemo() {
  let upserted = 0
  for (const p of DEMO_PROFILES) {
    await prisma.profile.upsert({
      where: { vkId: p.vkId },
      create: {
        vkId: p.vkId,
        displayName: p.displayName,
        age: p.age,
        city: 'Москва',
        photoUrl: p.photoUrl,
        score: p.score,
        signals: p.signals,
        fetchedAt: new Date(),
        isHidden: false
      },
      update: {
        displayName: p.displayName,
        age: p.age,
        photoUrl: p.photoUrl,
        score: p.score,
        signals: p.signals,
        fetchedAt: new Date()
      }
    })
    upserted += 1
  }
  console.log(`Demo seed complete: ${upserted} profiles`)
}

async function sleep(ms: number) {
  await new Promise((r) => setTimeout(r, ms))
}

async function searchChunk(
  token: string,
  params: Record<string, string | number | undefined>,
  retries = 8
): Promise<VkUser[]> {
  for (let attempt = 0; attempt <= retries; attempt++) {
    try {
      const res = await vkApi<SearchResponse>('users.search', params, token)
      return res.items || []
    } catch (e: any) {
      const msg = String(e?.message || e)
      const flood =
        msg.includes('Too many requests') ||
        msg.includes('Flood control') ||
        msg.includes('API 6') ||
        msg.includes('API 9')
      if (!flood || attempt === retries) throw e
      const wait = Math.min(120_000, 15_000 * (attempt + 1))
      console.warn(`VK rate limit, wait ${Math.round(wait / 1000)}s (attempt ${attempt + 1}/${retries})`)
      await sleep(wait)
    }
  }
  return []
}

async function upsertUser(
  user: VkUser,
  threshold: number,
  existingIds: Set<string>
): Promise<'created' | 'updated' | 'skipped' | 'rejected'> {
  if (!isFemaleProfile(user)) return 'skipped'
  const scored = scoreProfile(user)
  if (!isAllowedCatalogAge(scored.signals.age)) return 'skipped'
  if (!scored.signals.activelyLooking) return 'skipped'
  if (scored.score < threshold || !scored.signals.hasPhoto) return 'skipped'

  const vkId = String(user.id)
  const displayName = [user.first_name, user.last_name].filter(Boolean).join(' ') || `id${user.id}`
  const photoUrl = user.photo_max || user.photo_200 || null
  if (!photoUrl) return 'skipped'

  // Analyze BEFORE writing: only adult female faces enter the catalog DB.
  let face: PhotoAgeEstimate
  if (photoAgeCheckEnabled()) {
    face = await estimateAgeFromPhotoUrl(photoUrl)
  } else {
    face = {
      estimatedAge: null,
      looksUnderage: false,
      confidence: 0,
      status: 'error',
      detail: 'analyzer disabled'
    }
  }

  const existed = existingIds.has(vkId)

  if (!isCatalogFacePass(face.status)) {
    if (existed) {
      await prisma.profile.update({
        where: { vkId: BigInt(user.id) },
        data: {
          photoEstimatedAge: face.estimatedAge,
          photoAgeConfidence: face.confidence,
          photoAgeStatus: face.status,
          photoAgeCheckedAt: new Date(),
          photoGender: face.gender ?? null,
          photoGenderConfidence: face.genderConfidence ?? null,
          isHidden: true
        }
      })
    }
    console.log(
      `reject vk=${vkId} name=${displayName} status=${face.status} age=${face.estimatedAge} gender=${face.gender}:${face.genderConfidence?.toFixed(2) ?? '-'}`
    )
    return 'rejected'
  }

  await prisma.profile.upsert({
    where: { vkId: BigInt(user.id) },
    create: {
      vkId: BigInt(user.id),
      displayName,
      age: scored.signals.age ?? null,
      city: user.city?.title || 'Москва',
      photoUrl,
      score: scored.score,
      signals: scored.signals,
      fetchedAt: new Date(),
      isHidden: false,
      photoEstimatedAge: face.estimatedAge,
      photoAgeConfidence: face.confidence,
      photoAgeStatus: face.status,
      photoAgeCheckedAt: new Date(),
      photoGender: face.gender ?? null,
      photoGenderConfidence: face.genderConfidence ?? null
    },
    update: {
      displayName,
      age: scored.signals.age ?? null,
      city: user.city?.title || 'Москва',
      photoUrl,
      score: scored.score,
      signals: scored.signals,
      fetchedAt: new Date(),
      isHidden: false,
      photoEstimatedAge: face.estimatedAge,
      photoAgeConfidence: face.confidence,
      photoAgeStatus: face.status,
      photoAgeCheckedAt: new Date(),
      photoGender: face.gender ?? null,
      photoGenderConfidence: face.genderConfidence ?? null
    }
  })

  existingIds.add(vkId)
  return existed ? 'updated' : 'created'
}

/** Once per day: add ~N new profiles, rotating age/name shards by calendar day. */
async function indexDaily() {
  const token = process.env.VK_ACCESS_TOKEN
  if (!token) throw new Error('VK_ACCESS_TOKEN is required')

  const cityId = Number(process.env.VK_CITY_ID || 1)
  const ageFrom = Number(process.env.VK_AGE_FROM || 18)
  const ageTo = Number(process.env.VK_AGE_TO || 35)
  const threshold = Number(process.env.VK_SCORE_THRESHOLD || 2)
  const dailyLimit = Number(process.env.VK_DAILY_LIMIT || 100)
  const requestDelay = Number(process.env.VK_REQUEST_DELAY_MS || 1200)

  const existing = await prisma.profile.findMany({ select: { vkId: true } })
  const existingIds = new Set(existing.map((p) => p.vkId.toString()))

  const day = Math.floor(Date.now() / 86_400_000)
  const ageSpan = Math.max(1, ageTo - ageFrom + 1)
  const focusAge = ageFrom + (day % ageSpan)
  const focusName = NAME_SHARDS[day % NAME_SHARDS.length]
  // also try neighbouring ages / next names if not enough new
  const ages = [focusAge, focusAge + 1 > ageTo ? ageFrom : focusAge + 1, focusAge - 1 < ageFrom ? ageTo : focusAge - 1]
  const names = [
    focusName,
    NAME_SHARDS[(day + 1) % NAME_SHARDS.length],
    NAME_SHARDS[(day + 2) % NAME_SHARDS.length],
    ''
  ]

  const fields = 'sex,photo_200,photo_max,bdate,city,relation,status,interests,activities,about,personal'
  let created = 0
  let updated = 0
  let skipped = 0
  let rejected = 0

  console.log(
    `Daily index start: target=${dailyLimit} new, focusAge=${focusAge}, focusName="${focusName || '*'}", existing=${existingIds.size}`
  )

  outer: for (const age of ages) {
    for (const q of names) {
      for (const status of [6, undefined] as Array<number | undefined>) {
        if (created >= dailyLimit) break outer
        console.log(
          `search age=${age} q="${q || '*'}" status=${status ?? 'any'} created=${created}/${dailyLimit}`
        )
        let chunk: VkUser[] = []
        try {
          chunk = await searchChunk(token, {
            q: q || undefined,
            sex: 1,
            city: cityId,
            age_from: age,
            age_to: age,
            has_photo: 1,
            status,
            count: 100,
            offset: 0,
            fields
          })
        } catch (e) {
          console.warn('shard failed, skip:', e)
          await sleep(30_000)
          continue
        }
        for (const user of chunk) {
          if (created >= dailyLimit) break outer
          // Prefer brand-new profiles for daily quota
          if (existingIds.has(String(user.id))) {
            const r = await upsertUser(user, threshold, existingIds)
            if (r === 'updated') updated += 1
            else if (r === 'rejected') rejected += 1
            else if (r === 'skipped') skipped += 1
            continue
          }
          const r = await upsertUser(user, threshold, existingIds)
          if (r === 'created') created += 1
          else if (r === 'updated') updated += 1
          else if (r === 'rejected') rejected += 1
          else skipped += 1
        }
        await sleep(requestDelay)
      }
    }
  }

  console.log(
    `Daily index complete: created=${created} updated=${updated} rejected=${rejected} skipped=${skipped}`
  )
}

/** Larger backfill with gentle rate limits (not for hourly use). */
async function indexFull() {
  const token = process.env.VK_ACCESS_TOKEN
  if (!token) throw new Error('VK_ACCESS_TOKEN is required')

  const cityId = Number(process.env.VK_CITY_ID || 1)
  const ageFrom = Number(process.env.VK_AGE_FROM || 18)
  const ageTo = Number(process.env.VK_AGE_TO || 35)
  const threshold = Number(process.env.VK_SCORE_THRESHOLD || 2)
  const limit = Number(process.env.VK_INDEX_LIMIT || 5000)
  const requestDelay = Number(process.env.VK_REQUEST_DELAY_MS || 1200)

  const existing = await prisma.profile.findMany({ select: { vkId: true } })
  const existingIds = new Set(existing.map((p) => p.vkId.toString()))
  const fields = 'sex,photo_200,photo_max,bdate,city,relation,status,interests,activities,about,personal'

  let created = 0
  let updated = 0
  let skipped = 0
  let rejected = 0

  console.log(`Full index start: target=${limit}, existing=${existingIds.size}`)

  outer: for (let age = ageFrom; age <= ageTo; age++) {
    for (const q of NAME_SHARDS) {
      for (const status of [6, undefined] as Array<number | undefined>) {
        if (created + updated >= limit && created >= limit) break outer
        if (existingIds.size >= limit && created + existing.size >= limit) {
          // keep going until we have enough total visible-ish; stop when created hits remaining room
        }
        const need = limit - existingIds.size
        if (need <= 0 && created > 0) break outer
        if (existingIds.size >= limit) break outer

        console.log(
          `search age=${age} q="${q || '*'}" status=${status ?? 'any'} total=${existingIds.size} created=${created}`
        )
        try {
          const chunk = await searchChunk(token, {
            q: q || undefined,
            sex: 1,
            city: cityId,
            age_from: age,
            age_to: age,
            has_photo: 1,
            status,
            count: 100,
            offset: 0,
            fields
          })
          for (const user of chunk) {
            if (existingIds.size >= limit) break outer
            const r = await upsertUser(user, threshold, existingIds)
            if (r === 'created') created += 1
            else if (r === 'updated') updated += 1
            else if (r === 'rejected') rejected += 1
            else skipped += 1
          }
        } catch (e) {
          console.warn('search failed, continue', e)
        }
        await sleep(requestDelay)
      }
    }
  }

  console.log(
    `Full index complete: created=${created} updated=${updated} rejected=${rejected} skipped=${skipped} total=${existingIds.size}`
  )
}

async function main() {
  const demo = process.argv.includes('--demo')
  const daily = process.argv.includes('--daily')
  if (demo) await seedDemo()
  else if (daily) await indexDaily()
  else await indexFull()
}

main()
  .catch((err) => {
    console.error(err)
    process.exitCode = 1
  })
  .finally(async () => {
    await prisma.$disconnect()
  })
