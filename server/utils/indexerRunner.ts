import { existsSync, readFileSync, writeFileSync } from 'node:fs'
import { join } from 'node:path'
import { createError } from 'h3'

function projectDir() {
  return String(process.env.INDEXER_PROJECT_DIR || '').trim() || process.cwd()
}

function envPath() {
  return join(projectDir(), '.env')
}

function readEnvFile(): string {
  const path = envPath()
  if (!existsSync(path)) {
    throw createError({ statusCode: 500, statusMessage: `.env не найден: ${path}` })
  }
  return readFileSync(path, 'utf8')
}

function parseEnvValue(raw: string, key: string): string {
  const m = raw.match(new RegExp(`^${key}=(.*)$`, 'm'))
  if (!m) return ''
  let v = m[1].trim()
  if (
    (v.startsWith('"') && v.endsWith('"')) ||
    (v.startsWith("'") && v.endsWith("'"))
  ) {
    v = v.slice(1, -1)
  }
  return v.replace(/\\"/g, '"').replace(/\\\\/g, '\\')
}

/** Admin UI only saves the token; indexing runs on the home PC. */
export function envWritable(): { ok: boolean; reason?: string } {
  const path = envPath()
  if (!existsSync(path)) {
    return { ok: false, reason: `.env не найден: ${path}` }
  }
  return { ok: true }
}

export function getVkTokenStatus() {
  const avail = envWritable()
  if (!avail.ok) {
    return { available: false, reason: avail.reason || null, configured: false, tokenLength: 0 }
  }
  try {
    const token = parseEnvValue(readEnvFile(), 'VK_ACCESS_TOKEN')
    return {
      available: true,
      reason: null as string | null,
      configured: token.length >= 20,
      tokenLength: token.length
    }
  } catch (e: any) {
    return {
      available: false,
      reason: e?.statusMessage || e?.message || 'Не удалось прочитать .env',
      configured: false,
      tokenLength: 0
    }
  }
}

export function persistVkToken(token: string) {
  const path = envPath()
  const raw = readEnvFile()
  // Quote so # & etc. in rare tokens don't break .env parsers.
  const safe = `"${token.replace(/\\/g, '\\\\').replace(/"/g, '\\"')}"`
  const line = `VK_ACCESS_TOKEN=${safe}`
  const next = /^VK_ACCESS_TOKEN=/m.test(raw)
    ? raw.replace(/^VK_ACCESS_TOKEN=.*$/m, line)
    : `${raw.replace(/\s*$/, '')}\n${line}\n`
  writeFileSync(path, next, { mode: 0o600 })
}
