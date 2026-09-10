import { PrismaClient } from '@prisma/client'
import { computePhotoDHash, fetchImageBuffer, hammingDistanceHex } from '../lib/photoHash'

const prisma = new PrismaClient()

/** Hamming distance threshold for 64-bit dHash (0 = identical, ~8–12 = visually similar). */
const THRESHOLD = Number(process.env.PHOTO_DEDUP_THRESHOLD || 10)
const dryRun = process.argv.includes('--dry-run')

type Row = {
  id: string
  vkId: bigint
  displayName: string
  score: number
  photoUrl: string | null
  photoHash: string | null
}

async function hashProfiles(profiles: Row[]) {
  let hashed = 0
  let failed = 0
  for (const p of profiles) {
    if (!p.photoUrl) {
      failed += 1
      continue
    }
    if (p.photoHash) continue
    const buf = await fetchImageBuffer(p.photoUrl)
    if (!buf) {
      failed += 1
      console.warn(`skip hash vk=${p.vkId}: download failed`)
      continue
    }
    try {
      const hash = await computePhotoDHash(buf)
      if (!dryRun) {
        await prisma.profile.update({ where: { id: p.id }, data: { photoHash: hash } })
      }
      p.photoHash = hash
      hashed += 1
    } catch (e) {
      failed += 1
      console.warn(`skip hash vk=${p.vkId}:`, e)
    }
  }
  return { hashed, failed }
}

function findDuplicateGroups(profiles: Row[]) {
  const withHash = profiles.filter((p) => p.photoHash)
  const parent = new Map<string, string>()
  const find = (id: string): string => {
    const p = parent.get(id) || id
    if (p !== id) {
      const root = find(p)
      parent.set(id, root)
      return root
    }
    return id
  }
  const union = (a: string, b: string) => {
    const ra = find(a)
    const rb = find(b)
    if (ra !== rb) parent.set(rb, ra)
  }

  for (const p of withHash) parent.set(p.id, p.id)

  for (let i = 0; i < withHash.length; i++) {
    for (let j = i + 1; j < withHash.length; j++) {
      const a = withHash[i]
      const b = withHash[j]
      if (hammingDistanceHex(a.photoHash!, b.photoHash!) <= THRESHOLD) {
        union(a.id, b.id)
      }
    }
  }

  const buckets = new Map<string, Row[]>()
  for (const p of withHash) {
    const root = find(p.id)
    const list = buckets.get(root) || []
    list.push(p)
    buckets.set(root, list)
  }

  return [...buckets.values()].filter((g) => g.length > 1)
}

async function main() {
  const profiles = (await prisma.profile.findMany({
    where: { isHidden: false },
    select: {
      id: true,
      vkId: true,
      displayName: true,
      score: true,
      photoUrl: true,
      photoHash: true
    },
    orderBy: { score: 'desc' }
  })) as Row[]

  console.log(`Profiles visible: ${profiles.length}, threshold=${THRESHOLD}, dryRun=${dryRun}`)

  const { hashed, failed } = await hashProfiles(profiles)
  console.log(`Hashed: ${hashed}, failed/skipped: ${failed}`)

  const groups = findDuplicateGroups(profiles)
  let hidden = 0

  for (const group of groups) {
    group.sort((a, b) => b.score - a.score || Number(a.vkId - b.vkId))
    const keep = group[0]
    const drop = group.slice(1)
    console.log(
      `dup group keep=${keep.displayName} (${keep.vkId}) score=${keep.score} | drop=${drop
        .map((d) => `${d.displayName}(${d.vkId})`)
        .join(', ')}`
    )
    if (!dryRun) {
      const res = await prisma.profile.updateMany({
        where: { id: { in: drop.map((d) => d.id) } },
        data: { isHidden: true }
      })
      hidden += res.count
    } else {
      hidden += drop.length
    }
  }

  console.log(`Done. Duplicate groups=${groups.length}, hidden=${hidden}`)
}

main()
  .catch((err) => {
    console.error(err)
    process.exitCode = 1
  })
  .finally(async () => {
    await prisma.$disconnect()
  })
