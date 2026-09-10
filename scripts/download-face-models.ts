/**
 * Download face-api weights used by the local age/gender analyzer.
 * Run: npx tsx scripts/download-face-models.ts
 */
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const DIR = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../models/face-api')
const BASE = 'https://cdn.jsdelivr.net/npm/@vladmandic/face-api@1.7.15/model'
const FILES = [
  'tiny_face_detector_model-weights_manifest.json',
  'tiny_face_detector_model.bin',
  'face_landmark_68_model-weights_manifest.json',
  'face_landmark_68_model.bin',
  'ssd_mobilenetv1_model-weights_manifest.json',
  'ssd_mobilenetv1_model.bin',
  'age_gender_model-weights_manifest.json',
  'age_gender_model.bin'
]

async function main() {
  fs.mkdirSync(DIR, { recursive: true })
  for (const file of FILES) {
    const dest = path.join(DIR, file)
    process.stdout.write(`Downloading ${file}... `)
    const res = await fetch(`${BASE}/${file}`)
    if (!res.ok) throw new Error(`${file}: HTTP ${res.status}`)
    const buf = Buffer.from(await res.arrayBuffer())
    fs.writeFileSync(dest, buf)
    console.log(`${buf.length} bytes`)
  }
  console.log(`Models ready in ${DIR}`)
}

main().catch((e) => {
  console.error(e)
  process.exitCode = 1
})
