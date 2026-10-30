/**
 * Refresh Profile.photoUrl from VK users.get — CDN links expire / 404 over time.
 *
 *   npx tsx --env-file=.env scripts/refresh-photos.ts
 *   npx tsx --env-file=.env scripts/refresh-photos.ts --check   # only rewrite URLs that 404
 *   npx tsx --env-file=.env scripts/refresh-photos.ts --dry-run
 */
import { PrismaClient } from '@prisma/client'
import { vkApi, type VkUser } from '../server/utils/vk'

const prisma = new PrismaClient()

const dryRun = process.argv.includes('--dry-run')
const checkOnly = process.argv.includes('--check')
const BATCH = Number(process.env.VK_PHOTO_REFRESH_BATCH || 80)
const DELAY_MS = Number(process.env.VK_REQUEST_DELAY_MS || 400)

function sleep(ms: number) {
  return new Promise((r) => setTimeout(r, ms))
}

async function urlLooksDead(url: string): Promise<boolean> {
  try {
    const ctrl = new AbortController()
    const t = setTimeout(() => ctrl.abort(), 12_000)
    const res = await fetch(url, { method: 'HEAD', signal: ctrl.signal, redirect: 'follow' })
    clearTimeout(t)
    if (res.status === 405 || res.status === 501) {
      const getCtrl = new AbortController()
      const t2 = setTimeout(() => getCtrl.abort(), 12_000)
      const getRes = await fetch(url, {
        method: 'GET',
        signal: getCtrl.signal,
        redirect: 'follow',
        headers: { Range: 'bytes=0-0' }
      })
      clearTimeout(t2)
      return getRes.status >= 400
    }
    return res.status >= 400
  } catch {
    return true
  }
}

async function main() {
  const token = process.env.VK_ACCESS_TOKEN
  if (!token) throw new Error('VK_ACCESS_TOKEN is required')

  const profiles = await prisma.profile.findMany({
    where: { isHidden: false, vkId: { gt: 0 } },
    select: { id: true, vkId: true, displayName: true, photoUrl: true },
    orderBy: { fetchedAt: 'asc' }
  })

  console.log(
    `refresh-photos: ${profiles.length} visible profiles` +
      `${checkOnly ? ' (only dead URLs)' : ' (all)'}` +
      `${dryRun ? ' [dry-run]' : ''}`
  )

  let updated = 0
  let cleared = 0
  let skipped = 0
  let unchanged = 0
  let errors = 0

  for (let i = 0; i < profiles.length; i += BATCH) {
    const chunk = profiles.slice(i, i + BATCH)

    let toFetch = chunk
    if (checkOnly) {
      const dead: typeof chunk = []
      for (const p of chunk) {
        if (!p.photoUrl) {
          dead.push(p)
          continue
        }
        if (await urlLooksDead(p.photoUrl)) dead.push(p)
        else {
          unchanged += 1
        }
      }
      toFetch = dead
      console.log(
        `batch ${i / BATCH + 1}: ${dead.length}/${chunk.length} need refresh`
      )
    }

    if (!toFetch.length) {
      await sleep(DELAY_MS)
      continue
    }

    const ids = toFetch.map((p) => p.vkId.toString()).join(',')
    let users: VkUser[] = []
    try {
      users = await vkApi<VkUser[]>('users.get', {
        user_ids: ids,
        fields: 'photo_200,photo_max'
      }, token)
    } catch (e) {
      errors += 1
      console.error(`VK users.get failed for batch starting ${i}:`, e)
      await sleep(DELAY_MS * 3)
      continue
    }

    const byId = new Map(users.map((u) => [String(u.id), u]))

    for (const p of toFetch) {
      const u = byId.get(p.vkId.toString())
      const next = u ? u.photo_max || u.photo_200 || null : null

      // Deactivated / deleted / no photo → clear so catalog skips empty media
      if (!next) {
        if (p.photoUrl) {
          if (!dryRun) {
            await prisma.profile.update({
              where: { id: p.id },
              data: { photoUrl: null, fetchedAt: new Date() }
            })
          }
          cleared += 1
          console.log(`cleared vk=${p.vkId} ${p.displayName}`)
        } else {
          skipped += 1
        }
        continue
      }

      if (next === p.photoUrl) {
        unchanged += 1
        continue
      }

      if (!dryRun) {
        await prisma.profile.update({
          where: { id: p.id },
          data: { photoUrl: next, photoHash: null, fetchedAt: new Date() }
        })
      }
      updated += 1
      console.log(`updated vk=${p.vkId} ${p.displayName}`)
    }

    await sleep(DELAY_MS)
  }

  console.log(
    JSON.stringify({ updated, cleared, unchanged, skipped, errors, dryRun, checkOnly }, null, 2)
  )
}

main()
  .catch((e) => {
    console.error(e)
    process.exitCode = 1
  })
  .finally(() => prisma.$disconnect())
