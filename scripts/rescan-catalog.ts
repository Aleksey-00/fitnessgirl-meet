/**
 * Re-scan the whole visible catalog with the latest face rules, in batches.
 * Usage: npm run check:catalog
 */
import { spawn } from 'node:child_process'
import { PrismaClient } from '@prisma/client'

const prisma = new PrismaClient()
const batch = Number(process.env.PHOTO_AGE_CHECK_LIMIT || 200)

async function remainingPending() {
  return prisma.profile.count({
    where: {
      photoUrl: { not: null },
      OR: [{ photoAgeStatus: 'pending' }, { photoAgeStatus: 'error' }]
    }
  })
}

function runBatch(): Promise<number> {
  return new Promise((resolve, reject) => {
    const child = spawn(
      'npx',
      ['tsx', 'scripts/check-photo-ages.ts', '--include-hidden'],
      {
        stdio: 'inherit',
        env: {
          ...process.env,
          PHOTO_AGE_CHECK_LIMIT: String(batch),
          FACE_CHECK_INCLUDE_HIDDEN: '1'
        },
        shell: false
      }
    )
    child.on('error', reject)
    child.on('close', (code) => resolve(code ?? 1))
  })
}

async function main() {
  // Hide not actively looking first
  const notLooking = await prisma.$executeRaw`
    UPDATE "Profile"
    SET "isHidden" = true, "updatedAt" = NOW()
    WHERE "isHidden" = false
      AND COALESCE(("signals"->>'activelyLooking')::boolean, false) = false
  `
  console.log(`Hidden not-in-active-search: ${notLooking}`)

  // Queue current visible catalog (+ any still-ok rows) for one full re-check
  const queued = await prisma.profile.updateMany({
    where: {
      isHidden: false,
      photoUrl: { not: null },
      photoAgeStatus: 'ok'
    },
    data: { photoAgeStatus: 'pending' }
  })
  console.log(`Queued for re-check: ${queued.count}`)

  let round = 0
  for (;;) {
    const left = await remainingPending()
    if (left <= 0) {
      const visible = await prisma.profile.count({
        where: {
          isHidden: false,
          age: { gte: 18, lte: 35 },
          photoAgeStatus: 'ok',
          signals: { path: ['activelyLooking'], equals: true }
        }
      })
      const young = await prisma.profile.count({
        where: {
          isHidden: false,
          photoAgeStatus: 'ok',
          photoEstimatedAge: { lt: 23 }
        }
      })
      console.log(`---\nКАТАЛОГ ПЕРЕПРОВЕРЕН. видимых(ok+поиск)=${visible} youngPhoto<23=${young}`)
      break
    }
    round += 1
    console.log(`\n=== Каталог порция #${round}: осталось≈${left}, берём до ${batch} ===`)
    const code = await runBatch()
    if (code !== 0) throw new Error(`check exited ${code}`)
  }
}

main()
  .catch((e) => {
    console.error(e)
    process.exitCode = 1
  })
  .finally(async () => {
    await prisma.$disconnect()
  })
