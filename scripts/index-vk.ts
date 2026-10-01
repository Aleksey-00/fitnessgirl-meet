import { PrismaClient } from '@prisma/client'
import {
  isFemaleProfile,
  isMaleProfile,
  scoreProfile,
  passesCatalogPolicy,
  vkApi,
  type VkUser
} from '../server/utils/vk'

const prisma = new PrismaClient()

type PhotoAgeEstimate = {
  estimatedAge: number | null
  looksUnderage: boolean
  confidence: number
  status: string
  gender?: string | null
  genderConfidence?: number
  detail?: string
}

async function loadPhotoAge() {
  return import('../lib/photoAge')
}

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
  photoGender: 'female' | 'male'
  signals: Record<string, unknown>
}> = [
  {
    vkId: 100001n,
    displayName: 'Анна',
    age: 26,
    photoUrl: 'https://images.unsplash.com/photo-1518611012118-696072aa579a?w=400&h=500&fit=crop',
    score: 4.5,
    photoGender: 'female',
    signals: { sport: true, activelyLooking: true, hasPhoto: true, matchedWords: ['фитнес'] }
  },
  {
    vkId: 100002n,
    displayName: 'Мария',
    age: 29,
    photoUrl: 'https://images.unsplash.com/photo-1571019614242-c5c5dee9f50b?w=400&h=500&fit=crop',
    score: 4,
    photoGender: 'female',
    signals: { sport: true, activelyLooking: true, hasPhoto: true, matchedWords: ['йога'] }
  },
  {
    vkId: 100003n,
    displayName: 'Екатерина',
    age: 24,
    photoUrl: 'https://images.unsplash.com/photo-1517836357463-d25dfeac3438?w=400&h=500&fit=crop',
    score: 3.5,
    photoGender: 'female',
    signals: { sport: true, activelyLooking: false, hasPhoto: true, matchedWords: ['зал'] }
  },
  {
    vkId: 100004n,
    displayName: 'Дарья',
    age: 31,
    photoUrl: 'https://images.unsplash.com/photo-1548690312-e3b507d8c110?w=400&h=500&fit=crop',
    score: 3,
    photoGender: 'female',
    signals: { sport: true, activelyLooking: true, hasPhoto: true, matchedWords: ['бег'] }
  },
  {
    vkId: 100005n,
    displayName: 'Ольга',
    age: 27,
    photoUrl: 'https://images.unsplash.com/photo-1594381898411-846e7d193883?w=400&h=500&fit=crop',
    score: 4.5,
    photoGender: 'female',
    signals: { sport: true, activelyLooking: true, hasPhoto: true, matchedWords: ['кроссфит'] }
  },
  {
    vkId: 100006n,
    displayName: 'София',
    age: 23,
    photoUrl: 'https://images.unsplash.com/photo-1518310383802-640c2de311b2?w=400&h=500&fit=crop',
    score: 2.5,
    photoGender: 'female',
    signals: { sport: true, activelyLooking: false, hasPhoto: true, matchedWords: ['танц'] }
  },
  {
    vkId: 100101n,
    displayName: 'Алексей',
    age: 28,
    photoUrl: 'https://images.unsplash.com/photo-1583454110551-21f2fa2afe61?w=400&h=500&fit=crop',
    score: 4.2,
    photoGender: 'male',
    signals: { sport: true, activelyLooking: true, hasPhoto: true, matchedWords: ['зал'] }
  },
  {
    vkId: 100102n,
    displayName: 'Дмитрий',
    age: 30,
    photoUrl: 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=400&h=500&fit=crop',
    score: 3.8,
    photoGender: 'male',
    signals: { sport: true, activelyLooking: true, hasPhoto: true, matchedWords: ['кроссфит'] }
  },
  {
    vkId: 100103n,
    displayName: 'Иван',
    age: 25,
    photoUrl: 'https://images.unsplash.com/photo-1571902943202-507ec2618e8f?w=400&h=500&fit=crop',
    score: 3.5,
    photoGender: 'male',
    signals: { sport: true, activelyLooking: true, hasPhoto: true, matchedWords: ['бег'] }
  }
]

const FEMALE_NAME_SHARDS = [
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

const MALE_NAME_SHARDS = [
  '',
  'александр',
  'дмитрий',
  'максим',
  'сергей',
  'андрей',
  'алексей',
  'артём',
  'илья',
  'кирилл',
  'михаил',
  'николай',
  'иван',
  'евгений',
  'роман',
  'владимир',
  'павел',
  'константин',
  'денис',
  'тимур',
  'никита',
  'олег',
  'виктор',
  'юрий',
  'антон'
]

/** @deprecated use FEMALE_NAME_SHARDS */
const NAME_SHARDS = FEMALE_NAME_SHARDS

async function seedDemo(onlyGender?: 'female' | 'male') {
  let upserted = 0
  for (const p of DEMO_PROFILES) {
    if (onlyGender && p.photoGender !== onlyGender) continue
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
        isHidden: false,
        photoAgeStatus: 'ok',
        photoGender: p.photoGender,
        photoAgeCheckedAt: new Date()
      },
      update: {
        displayName: p.displayName,
        age: p.age,
        photoUrl: p.photoUrl,
        score: p.score,
        signals: p.signals,
        fetchedAt: new Date(),
        isHidden: false,
        photoAgeStatus: 'ok',
        photoGender: p.photoGender,
        photoAgeCheckedAt: new Date()
      }
    })
    upserted += 1
  }
  console.log(`Demo seed complete: ${upserted} profiles${onlyGender ? ` (${onlyGender})` : ''}`)
}

async function sleep(ms: number) {
  await new Promise((r) => setTimeout(r, ms))
}

/** Consecutive flood hits across shards — triggers one long cool-down instead of burning hours per shard. */
let floodHits = 0

async function searchChunk(
  token: string,
  params: Record<string, string | number | undefined>,
  retries = 3
): Promise<VkUser[]> {
  for (let attempt = 0; attempt <= retries; attempt++) {
    try {
      const res = await vkApi<SearchResponse>('users.search', params, token)
      floodHits = 0
      return res.items || []
    } catch (e: any) {
      const msg = String(e?.message || e)
      const flood =
        msg.includes('Too many requests') ||
        msg.includes('Flood control') ||
        msg.includes('API 6') ||
        msg.includes('API 9')
      if (!flood || attempt === retries) {
        if (flood) floodHits += 1
        throw e
      }
      // Short retries only — long per-shard waits blocked the male lane for hours.
      const wait = Math.min(45_000, 15_000 * (attempt + 1))
      console.warn(`VK rate limit, wait ${Math.round(wait / 1000)}s (attempt ${attempt + 1}/${retries})`)
      await sleep(wait)
    }
  }
  return []
}

async function coolDownIfFlooding() {
  if (floodHits < 3) return
  const wait = Number(process.env.VK_FLOOD_COOLDOWN_MS || 600_000)
  console.warn(`VK flood streak=${floodHits}, global cool-down ${Math.round(wait / 1000)}s`)
  await sleep(wait)
  floodHits = 0
}

async function upsertUser(
  user: VkUser,
  threshold: number,
  existingIds: Set<string>,
  expectedSex: 1 | 2
): Promise<'created' | 'updated' | 'skipped' | 'rejected'> {
  const expectedGender = expectedSex === 1 ? 'female' : 'male'
  if (expectedSex === 1 && !isFemaleProfile(user)) return 'skipped'
  if (expectedSex === 2 && !isMaleProfile(user)) return 'skipped'

  const scored = scoreProfile(user)
  if (!passesCatalogPolicy(scored)) return 'skipped'
  // threshold still applies on top of policy (sport-weighted score)
  if (scored.score < threshold) return 'skipped'

  const vkId = String(user.id)
  const displayName = [user.first_name, user.last_name].filter(Boolean).join(' ') || `id${user.id}`
  const photoUrl = user.photo_max || user.photo_200 || null
  if (!photoUrl) return 'skipped'

  // Analyze BEFORE writing: only adult faces of the expected gender enter the catalog DB.
  const { estimateAgeFromPhotoUrl, isCatalogFacePass, photoAgeCheckEnabled } = await loadPhotoAge()
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

  if (!isCatalogFacePass(face, expectedGender)) {
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
      `reject vk=${vkId} name=${displayName} want=${expectedGender} status=${face.status} age=${face.estimatedAge} gender=${face.gender}:${face.genderConfidence?.toFixed(2) ?? '-'}`
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
      photoGender: face.gender ?? expectedGender,
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
      photoGender: face.gender ?? expectedGender,
      photoGenderConfidence: face.genderConfidence ?? null
    }
  })

  existingIds.add(vkId)
  const tag = existed ? 'updated' : 'created'
  console.log(
    `${tag} vk=${vkId} name=${displayName} gender=${expectedGender} age=${scored.signals.age ?? '?'} score=${scored.score} photoAge=${face.estimatedAge ?? '?'}`
  )
  return tag
}

function parseSexFilter(): 'both' | 'female' | 'male' {
  const arg = process.argv.find((a) => a.startsWith('--sex='))?.slice('--sex='.length)
  const env = process.env.VK_INDEX_SEX
  const raw = (arg || env || 'both').toLowerCase()
  if (raw === 'female' || raw === '1' || raw === 'women') return 'female'
  if (raw === 'male' || raw === '2' || raw === 'men') return 'male'
  return 'both'
}

/** Once per day: add ~N new profiles (women + men), rotating age/name shards by calendar day. */
async function indexDaily() {
  const token = process.env.VK_ACCESS_TOKEN
  if (!token) throw new Error('VK_ACCESS_TOKEN is required')

  const cityId = Number(process.env.VK_CITY_ID || 1)
  const ageFrom = Number(process.env.VK_AGE_FROM || 18)
  const ageTo = Number(process.env.VK_AGE_TO || 35)
  const threshold = Number(process.env.VK_SCORE_THRESHOLD || 2)
  const dailyLimit = Number(process.env.VK_DAILY_LIMIT || 100)
  const requestDelay = Number(process.env.VK_REQUEST_DELAY_MS || 1200)
  const sexFilter = parseSexFilter()

  const existing = await prisma.profile.findMany({
    select: { vkId: true, photoGender: true, isHidden: true }
  })
  const existingIds = new Set(existing.map((p) => p.vkId.toString()))
  const visibleMale = existing.filter((p) => p.photoGender === 'male' && !p.isHidden).length
  const visibleFemale = existing.filter((p) => p.photoGender === 'female' && !p.isHidden).length

  // Fill the empty lane first so flood on women never starves men (and vice versa).
  let femaleQuota = 0
  let maleQuota = 0
  if (sexFilter === 'female') {
    femaleQuota = dailyLimit
  } else if (sexFilter === 'male') {
    maleQuota = dailyLimit
  } else if (visibleMale === 0 && visibleFemale > 0) {
    maleQuota = dailyLimit
    femaleQuota = 0
  } else if (visibleFemale === 0 && visibleMale > 0) {
    femaleQuota = dailyLimit
    maleQuota = 0
  } else {
    femaleQuota = Math.ceil(dailyLimit / 2)
    maleQuota = Math.max(0, dailyLimit - femaleQuota)
  }

  // VK_INDEX_SALT shifts name/age shards so same-day re-runs find new people.
  const daySalt = Number(process.env.VK_INDEX_SALT || 0)
  const day = Math.floor(Date.now() / 86_400_000) + (Number.isFinite(daySalt) ? daySalt : 0)
  const ageSpan = Math.max(1, ageTo - ageFrom + 1)
  const focusAge = ageFrom + (day % ageSpan)
  const ages = [
    focusAge,
    focusAge + 1 > ageTo ? ageFrom : focusAge + 1,
    focusAge - 1 < ageFrom ? ageTo : focusAge - 1,
    focusAge + 2 > ageTo ? ageFrom + ((focusAge + 2 - ageFrom) % ageSpan) : focusAge + 2,
    focusAge + 3 > ageTo ? ageFrom + ((focusAge + 3 - ageFrom) % ageSpan) : focusAge + 3
  ]
  const searchOffsets = String(process.env.VK_SEARCH_OFFSETS || '0,100')
    .split(',')
    .map((s) => Number(s.trim()))
    .filter((n) => Number.isFinite(n) && n >= 0)

  const fields = 'sex,photo_200,photo_max,bdate,city,relation,status,interests,activities,about,personal'
  let created = 0
  let updated = 0
  let skipped = 0
  let rejected = 0
  let createdFemale = 0
  let createdMale = 0

  console.log(
    `Daily index start: target=${dailyLimit} sex=${sexFilter} (♀${femaleQuota}/♂${maleQuota}), focusAge=${focusAge}, salt=${daySalt}, offsets=${searchOffsets.join('|')}, existing=${existingIds.size} visible♀=${visibleFemale} visible♂=${visibleMale}`
  )

  const sexes: Array<{ sex: 1 | 2; quota: number; names: string[] }> = []
  const femaleLane = {
    sex: 1 as const,
    quota: femaleQuota,
    names: [
      FEMALE_NAME_SHARDS[day % FEMALE_NAME_SHARDS.length],
      FEMALE_NAME_SHARDS[(day + 1) % FEMALE_NAME_SHARDS.length],
      FEMALE_NAME_SHARDS[(day + 2) % FEMALE_NAME_SHARDS.length],
      ''
    ]
  }
  const maleLane = {
    sex: 2 as const,
    quota: maleQuota,
    names: [
      MALE_NAME_SHARDS[day % MALE_NAME_SHARDS.length],
      MALE_NAME_SHARDS[(day + 1) % MALE_NAME_SHARDS.length],
      MALE_NAME_SHARDS[(day + 2) % MALE_NAME_SHARDS.length],
      ''
    ]
  }
  // Empty male catalog → men first. Explicit --sex=male also puts men only.
  if (maleQuota > 0 && (femaleQuota === 0 || visibleMale === 0)) {
    if (maleQuota > 0) sexes.push(maleLane)
    if (femaleQuota > 0) sexes.push(femaleLane)
  } else {
    if (femaleQuota > 0) sexes.push(femaleLane)
    if (maleQuota > 0) sexes.push(maleLane)
  }

  for (const lane of sexes) {
    let laneCreated = 0
    let laneFloodSkips = 0
    outer: for (const age of ages) {
      for (const q of lane.names) {
        for (const status of [6, undefined] as Array<number | undefined>) {
          for (const offset of searchOffsets) {
            if (laneCreated >= lane.quota || created >= dailyLimit) break outer
            if (laneFloodSkips >= 6) {
              console.warn(`lane sex=${lane.sex} abort after ${laneFloodSkips} flood skips`)
              break outer
            }
            await coolDownIfFlooding()
            console.log(
              `search sex=${lane.sex} age=${age} q="${q || '*'}" status=${status ?? 'any'} offset=${offset} lane=${laneCreated}/${lane.quota}`
            )
            let chunk: VkUser[] = []
            try {
              chunk = await searchChunk(token, {
                q: q || undefined,
                sex: lane.sex,
                city: cityId,
                age_from: age,
                age_to: age,
                has_photo: 1,
                status,
                count: 100,
                offset,
                fields
              })
            } catch (e) {
              const msg = String((e as Error)?.message || e)
              const flood = msg.includes('Flood') || msg.includes('API 9') || msg.includes('API 6')
              console.warn('shard failed, skip:', e)
              if (flood) {
                laneFloodSkips += 1
                await sleep(20_000)
              } else {
                await sleep(5_000)
              }
              continue
            }
            for (const user of chunk) {
              if (laneCreated >= lane.quota || created >= dailyLimit) break outer
              if (existingIds.has(String(user.id))) {
                const r = await upsertUser(user, threshold, existingIds, lane.sex)
                if (r === 'updated') updated += 1
                else if (r === 'rejected') rejected += 1
                else if (r === 'skipped') skipped += 1
                continue
              }
              const r = await upsertUser(user, threshold, existingIds, lane.sex)
              if (r === 'created') {
                created += 1
                laneCreated += 1
                if (lane.sex === 1) createdFemale += 1
                else createdMale += 1
              } else if (r === 'updated') updated += 1
              else if (r === 'rejected') rejected += 1
              else skipped += 1
            }
            await sleep(requestDelay)
          }
        }
      }
    }
  }

  console.log(
    `Daily index complete: created=${created} (♀${createdFemale}/♂${createdMale}) updated=${updated} rejected=${rejected} skipped=${skipped}`
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

  const lanes: Array<{ sex: 1 | 2; names: string[] }> = [
    { sex: 1, names: FEMALE_NAME_SHARDS },
    { sex: 2, names: MALE_NAME_SHARDS }
  ]

  outer: for (const lane of lanes) {
    for (let age = ageFrom; age <= ageTo; age++) {
      for (const q of lane.names) {
        for (const status of [6, undefined] as Array<number | undefined>) {
          if (existingIds.size >= limit) break outer

          console.log(
            `search sex=${lane.sex} age=${age} q="${q || '*'}" status=${status ?? 'any'} total=${existingIds.size} created=${created}`
          )
          try {
            const chunk = await searchChunk(token, {
              q: q || undefined,
              sex: lane.sex,
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
              const r = await upsertUser(user, threshold, existingIds, lane.sex)
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
  }

  console.log(
    `Full index complete: created=${created} updated=${updated} rejected=${rejected} skipped=${skipped} total=${existingIds.size}`
  )
}

async function main() {
  const demoMale = process.argv.includes('--demo-male')
  const demo = process.argv.includes('--demo') || demoMale
  const daily = process.argv.includes('--daily')
  if (demoMale) await seedDemo('male')
  else if (demo) await seedDemo()
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
