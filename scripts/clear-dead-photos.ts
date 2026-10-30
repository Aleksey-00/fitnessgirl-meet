/**
 * Clear Profile.photoUrl when the stored VK CDN link is dead (HTTP 4xx/5xx).
 * No VK API token needed — safe to run on the VPS.
 *
 *   npx tsx --env-file=.env scripts/clear-dead-photos.ts
 *   npx tsx --env-file=.env scripts/clear-dead-photos.ts --dry-run
 */
import { PrismaClient } from '@prisma/client'

const prisma = new PrismaClient()
const dryRun = process.argv.includes('--dry-run')
const CONCURRENCY = Number(process.env.PHOTO_CLEAR_CONCURRENCY || 8)

async function isDead(url: string): Promise<boolean> {
  try {
    const ctrl = new AbortController()
    const t = setTimeout(() => ctrl.abort(), 12_000)
    let res = await fetch(url, { method: 'HEAD', signal: ctrl.signal, redirect: 'follow' })
    clearTimeout(t)
    if (res.status === 405 || res.status === 501) {
      const ctrl2 = new AbortController()
      const t2 = setTimeout(() => ctrl2.abort(), 12_000)
      res = await fetch(url, {
        method: 'GET',
        signal: ctrl2.signal,
        redirect: 'follow',
        headers: { Range: 'bytes=0-0' }
      })
      clearTimeout(t2)
    }
    return res.status >= 400
  } catch {
    return true
  }
}

async function mapPool<T, R>(items: T[], limit: number, fn: (item: T) => Promise<R>): Promise<R[]> {
  const out: R[] = []
  let i = 0
  async function worker() {
    while (i < items.length) {
      const idx = i++
      out[idx] = await fn(items[idx])
    }
  }
  await Promise.all(Array.from({ length: Math.min(limit, items.length) }, () => worker()))
  return out
}

async function main() {
  const profiles = await prisma.profile.findMany({
    where: { isHidden: false, photoUrl: { not: null } },
    select: { id: true, vkId: true, displayName: true, photoUrl: true }
  })
  console.log(`clear-dead-photos: checking ${profiles.length} profiles${dryRun ? ' [dry-run]' : ''}`)

  let dead = 0
  let live = 0
  await mapPool(profiles, CONCURRENCY, async (p) => {
    const bad = await isDead(p.photoUrl!)
    if (!bad) {
      live += 1
      return
    }
    dead += 1
    console.log(`dead vk=${p.vkId} ${p.displayName}`)
    if (!dryRun) {
      await prisma.profile.update({
        where: { id: p.id },
        data: { photoUrl: null }
      })
    }
  })

  console.log(JSON.stringify({ dead, live, dryRun }, null, 2))
}

main()
  .catch((e) => {
    console.error(e)
    process.exitCode = 1
  })
  .finally(() => prisma.$disconnect())
