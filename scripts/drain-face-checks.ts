/**
 * Run face checks in batches until every visible unchecked profile is processed.
 * Prints a brief report after each batch.
 */
import { spawn } from 'node:child_process'
import { PrismaClient } from '@prisma/client'

const prisma = new PrismaClient()
const batch = Number(process.env.PHOTO_AGE_CHECK_LIMIT || 200)

async function remaining() {
  return prisma.profile.count({
    where: {
      photoUrl: { not: null },
      OR: [{ photoAgeStatus: null }, { photoAgeStatus: 'pending' }, { photoAgeStatus: 'error' }]
    }
  })
}

function runBatch(): Promise<number> {
  return new Promise((resolve, reject) => {
    const child = spawn('npx', ['tsx', 'scripts/check-photo-ages.ts', '--include-hidden'], {
      stdio: 'inherit',
      env: {
        ...process.env,
        PHOTO_AGE_CHECK_LIMIT: String(batch),
        FACE_CHECK_INCLUDE_HIDDEN: '1'
      },
      shell: false
    })
    child.on('error', reject)
    child.on('close', (code) => resolve(code ?? 1))
  })
}

async function main() {
  let round = 0
  for (;;) {
    const left = await remaining()
    if (left <= 0) {
      const visible = await prisma.profile.count({
        where: { isHidden: false, age: { gte: 18, lte: 35 }, photoAgeStatus: 'ok' }
      })
      console.log(`---\nВСЕ ПРОВЕРЕНЫ. видимых(ok)=${visible}. Можно пополнять из VK.`)
      break
    }
    round += 1
    console.log(`\n=== Порция #${round}: осталось≈${left}, берём до ${batch} ===`)
    const code = await runBatch()
    if (code !== 0) {
      throw new Error(`check:faces exited with code ${code}`)
    }
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
