import { PrismaClient } from '@prisma/client'
import {
  estimateAgeFromPhotoUrl,
  photoAgeCheckEnabled,
  shouldHideForPhotoAge
} from '../lib/photoAge'

const prisma = new PrismaClient()

const limit = Number(process.env.PHOTO_AGE_CHECK_LIMIT || 100)
const onlyUnchecked = !process.argv.includes('--all')
const delayMs = Number(process.env.PHOTO_AGE_CHECK_DELAY_MS || 50)
const includeHidden =
  process.argv.includes('--include-hidden') || process.env.FACE_CHECK_INCLUDE_HIDDEN === '1'
/** Re-check current catalog rows (visible). */
const catalogOnly = process.argv.includes('--catalog')

async function sleep(ms: number) {
  await new Promise((r) => setTimeout(r, ms))
}

async function main() {
  if (!photoAgeCheckEnabled()) {
    throw new Error('Local face analyzer is disabled')
  }

  // Drop anyone not in active search from the visible catalog.
  const notLooking = await prisma.$executeRaw`
    UPDATE "Profile"
    SET "isHidden" = true, "updatedAt" = NOW()
    WHERE "isHidden" = false
      AND COALESCE(("signals"->>'activelyLooking')::boolean, false) = false
  `
  if (Number(notLooking) > 0) {
    console.log(`Hidden not-in-active-search: ${notLooking}`)
  }

  const where: Record<string, unknown> = {
    photoUrl: { not: null }
  }
  if (catalogOnly) {
    where.isHidden = false
    where.photoAgeStatus = 'ok'
  } else if (!includeHidden) {
    where.isHidden = false
  }
  if (onlyUnchecked && !catalogOnly) {
    where.OR = [
      { photoAgeStatus: null },
      { photoAgeStatus: 'pending' },
      { photoAgeStatus: 'error' }
    ]
  }

  const remainingBefore = await prisma.profile.count({ where: where as any })
  const profiles = await prisma.profile.findMany({
    where: where as any,
    orderBy: { fetchedAt: 'desc' },
    take: limit,
    select: {
      id: true,
      vkId: true,
      displayName: true,
      age: true,
      photoUrl: true,
      signals: true
    }
  })

  console.log(
    `Local face check: ${profiles.length} profiles (limit=${limit}, remaining≈${remainingBefore}, onlyUnchecked=${onlyUnchecked}, catalogOnly=${catalogOnly})`
  )

  let ok = 0
  let underage = 0
  let unclear = 0
  let male = 0
  let nonhuman = 0
  let errors = 0

  for (const p of profiles) {
    const signals = (p.signals || {}) as { activelyLooking?: boolean }
    if (!signals.activelyLooking) {
      await prisma.profile.update({
        where: { id: p.id },
        data: { isHidden: true }
      })
      unclear += 1
      console.log(`vk=${p.vkId} name=${p.displayName} HIDDEN not actively looking`)
      continue
    }

    const result = await estimateAgeFromPhotoUrl(p.photoUrl!)
    const hide = shouldHideForPhotoAge(result.status)

    await prisma.profile.update({
      where: { id: p.id },
      data: {
        photoEstimatedAge: result.estimatedAge,
        photoAgeConfidence: result.confidence,
        photoAgeStatus: result.status,
        photoAgeCheckedAt: new Date(),
        photoGender: result.gender ?? null,
        photoGenderConfidence: result.genderConfidence ?? null,
        isHidden: hide
      }
    })

    if (result.status === 'ok') ok += 1
    else if (result.status === 'underage') underage += 1
    else if (result.status === 'unclear') unclear += 1
    else if (result.status === 'male') male += 1
    else if (result.status === 'nonhuman') nonhuman += 1
    else errors += 1

    console.log(
      `vk=${p.vkId} name=${p.displayName} vkAge=${p.age} photoAge=${result.estimatedAge} gender=${result.gender}:${result.genderConfidence?.toFixed(2) ?? '-'} status=${result.status} conf=${result.confidence.toFixed(2)}${hide ? ' HIDDEN' : ''}${result.detail ? ` detail=${result.detail.slice(0, 140)}` : ''}`
    )
    if (delayMs > 0) await sleep(delayMs)
  }

  const remainingAfter = await prisma.profile.count({
    where: catalogOnly
      ? ({ isHidden: false, photoAgeStatus: 'ok', photoUrl: { not: null } } as any)
      : ({
          ...(includeHidden ? {} : { isHidden: false }),
          photoUrl: { not: null },
          OR: [{ photoAgeStatus: null }, { photoAgeStatus: 'pending' }, { photoAgeStatus: 'error' }]
        } as any)
  })
  const visible = await prisma.profile.count({
    where: {
      isHidden: false,
      age: { gte: 18, lte: 35 },
      photoAgeStatus: 'ok',
      signals: { path: ['activelyLooking'], equals: true }
    }
  })

  console.log('---')
  console.log(
    `СПРАВКА: ok=${ok} underage=${underage} male=${male} nonhuman=${nonhuman} unclear=${unclear} errors=${errors} | видимых(ok+поиск)=${visible} осталось≈${remainingAfter}`
  )
}

main()
  .catch((e) => {
    console.error(e)
    process.exitCode = 1
  })
  .finally(async () => {
    await prisma.$disconnect()
  })
