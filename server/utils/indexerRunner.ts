import { spawn } from 'node:child_process'
import { accessSync, constants, existsSync, readFileSync, writeFileSync } from 'node:fs'
import { join } from 'node:path'
import { createError } from 'h3'

export type IndexerMode = 'daily' | 'full'

let running = false

export function isIndexerRunning() {
  return running
}

function projectDir() {
  return String(process.env.INDEXER_PROJECT_DIR || '').trim() || process.cwd()
}

function composeFile(dir: string) {
  return join(dir, 'docker-compose.yml')
}

export function indexerAvailable(): { ok: boolean; reason?: string } {
  const dir = projectDir()
  if (!existsSync(composeFile(dir))) {
    return { ok: false, reason: `Нет docker-compose.yml в ${dir}` }
  }
  try {
    accessSync('/var/run/docker.sock', constants.R_OK | constants.W_OK)
  } catch {
    return { ok: false, reason: 'Нет доступа к Docker socket (/var/run/docker.sock)' }
  }
  return { ok: true }
}

export function persistVkToken(token: string) {
  const dir = projectDir()
  const envPath = join(dir, '.env')
  if (!existsSync(envPath)) {
    throw createError({ statusCode: 500, statusMessage: `.env не найден: ${envPath}` })
  }
  const raw = readFileSync(envPath, 'utf8')
  const line = `VK_ACCESS_TOKEN=${token}`
  const next = /^VK_ACCESS_TOKEN=/m.test(raw)
    ? raw.replace(/^VK_ACCESS_TOKEN=.*$/m, line)
    : `${raw.replace(/\s*$/, '')}\n${line}\n`
  writeFileSync(envPath, next, { mode: 0o600 })
}

export async function runIndexerStream(opts: {
  token: string
  mode: IndexerMode
  limit: number
  onLine: (line: string) => void
}): Promise<number> {
  if (running) {
    throw createError({ statusCode: 409, statusMessage: 'Индексация уже запущена' })
  }
  const avail = indexerAvailable()
  if (!avail.ok) {
    throw createError({ statusCode: 503, statusMessage: avail.reason || 'Indexer unavailable' })
  }

  const dir = projectDir()
  const limitEnv = opts.mode === 'daily' ? 'VK_DAILY_LIMIT' : 'VK_INDEX_LIMIT'
  const scriptArgs =
    opts.mode === 'daily'
      ? ['npx', 'tsx', 'scripts/index-vk.ts', '--daily']
      : ['npx', 'tsx', 'scripts/index-vk.ts']

  const args = [
    'compose',
    '-f',
    composeFile(dir),
    '--project-directory',
    dir,
    '--profile',
    'tools',
    'run',
    '--rm',
    '-e',
    `VK_ACCESS_TOKEN=${opts.token}`,
    '-e',
    `${limitEnv}=${String(opts.limit)}`,
    'indexer',
    ...scriptArgs
  ]

  const fallbackArgs = [
    '-f',
    composeFile(dir),
    '--project-directory',
    dir,
    '--profile',
    'tools',
    'run',
    '--rm',
    '-e',
    `VK_ACCESS_TOKEN=${opts.token}`,
    '-e',
    `${limitEnv}=${String(opts.limit)}`,
    'indexer',
    ...scriptArgs
  ]

  running = true

  const run = (cmd: string, cmdArgs: string[]) =>
    new Promise<number>((resolve) => {
      const safe = cmdArgs.map((a) => (a.startsWith('VK_ACCESS_TOKEN=') ? 'VK_ACCESS_TOKEN=***' : a))
      opts.onLine(`$ ${cmd} ${safe.join(' ')}`)

      const child = spawn(cmd, cmdArgs, {
        cwd: dir,
        env: {
          ...process.env,
          DOCKER_HOST: process.env.DOCKER_HOST || 'unix:///var/run/docker.sock'
        },
        stdio: ['ignore', 'pipe', 'pipe']
      })

      const push = (buf: Buffer) => {
        for (const line of buf.toString('utf8').split(/\r?\n/)) {
          if (line.length) opts.onLine(line)
        }
      }
      child.stdout?.on('data', push)
      child.stderr?.on('data', push)
      child.on('error', (err) => {
        opts.onLine(`spawn error: ${err.message}`)
        resolve(127)
      })
      child.on('close', (code) => resolve(code ?? 1))
    })

  try {
    // Static docker CLI has no compose plugin — prefer standalone docker-compose.
    let code = await run('docker-compose', fallbackArgs)
    if (code === 127) {
      opts.onLine('docker-compose недоступен, пробую docker compose…')
      code = await run('docker', args)
    }
    return code
  } finally {
    running = false
  }
}
