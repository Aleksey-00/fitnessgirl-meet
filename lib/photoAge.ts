import { createRequire } from 'node:module'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import sharp from 'sharp'
import { fetchImageBuffer } from './photoHash'

// tfjs-node must load before face-api so Node tensor backends register.
const require = createRequire(import.meta.url)
require('@tensorflow/tfjs-node')
const faceapi = require('@vladmandic/face-api') as typeof import('@vladmandic/face-api')

export type PhotoAgeEstimate = {
  estimatedAge: number | null
  /** Model thinks the person appears under 18 / unsafe for adult catalog */
  looksUnderage: boolean
  confidence: number
  status: 'ok' | 'underage' | 'unclear' | 'male' | 'nonhuman' | 'error'
  gender?: 'female' | 'male' | 'unknown'
  genderConfidence?: number
  detail?: string
}

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const MODEL_DIR = path.join(ROOT, 'models', 'face-api')

/** Apparent photo age must be at least this (MAE ~5y → keep buffer above 18). */
const MIN_APPARENT_AGE = Number(process.env.PHOTO_MIN_APPARENT_AGE || 23)
const MIN_FACE_SCORE = Number(process.env.PHOTO_MIN_FACE_SCORE || 0.72)
const MIN_FEMALE_PROB = Number(process.env.PHOTO_MIN_FEMALE_PROB || 0.62)

/** Profiles that must not appear in the adult women catalog. */
export function shouldHideForPhotoAge(status: PhotoAgeEstimate['status']) {
  return (
    status === 'underage' ||
    status === 'unclear' ||
    status === 'male' ||
    status === 'nonhuman' ||
    status === 'error'
  )
}

/** Only clear adult female real-photo faces are allowed into the catalog DB. */
export function isCatalogFacePass(status: PhotoAgeEstimate['status']) {
  return status === 'ok'
}

export function photoAgeCheckEnabled() {
  return true
}

let modelsReady: Promise<void> | null = null

async function ensureModels() {
  if (!modelsReady) {
    modelsReady = (async () => {
      await faceapi.nets.ssdMobilenetv1.loadFromDisk(MODEL_DIR)
      await faceapi.nets.faceLandmark68Net.loadFromDisk(MODEL_DIR)
      await faceapi.nets.ageGenderNet.loadFromDisk(MODEL_DIR)
    })().catch((err) => {
      modelsReady = null
      throw err
    })
  }
  await modelsReady
}

async function toRgbTensorInput(buffer: Buffer): Promise<Buffer> {
  return sharp(buffer)
    .rotate()
    .resize({ width: 640, height: 640, fit: 'inside', withoutEnlargement: true })
    .removeAlpha()
    .jpeg({ quality: 92 })
    .toBuffer()
}

/**
 * Reject anime / drawings / flat avatars: too few colors + weak photo texture.
 */
async function assessPhotoRealism(buffer: Buffer): Promise<{ ok: boolean; detail: string }> {
  const { data, info } = await sharp(buffer)
    .rotate()
    .resize(96, 96, { fit: 'fill' })
    .removeAlpha()
    .raw()
    .toBuffer({ resolveWithObject: true })

  const colors = new Set<number>()
  for (let i = 0; i < data.length; i += 3) {
    const r = data[i] >> 4
    const g = data[i + 1] >> 4
    const b = data[i + 2] >> 4
    colors.add((r << 8) | (g << 4) | b)
  }

  let edge = 0
  let n = 0
  const w = info.width
  const gray = (i: number) => 0.3 * data[i] + 0.59 * data[i + 1] + 0.11 * data[i + 2]
  for (let y = 0; y < info.height - 1; y++) {
    for (let x = 0; x < w - 1; x++) {
      const i = (y * w + x) * 3
      const right = (y * w + x + 1) * 3
      const down = ((y + 1) * w + x) * 3
      const g0 = gray(i)
      edge += Math.abs(g0 - gray(right)) + Math.abs(g0 - gray(down))
      n += 2
    }
  }
  const meanEdge = n ? edge / n : 0

  if (colors.size < 70) {
    return { ok: false, detail: `non-photo/flat colors=${colors.size}` }
  }
  if (meanEdge < 3.5) {
    return { ok: false, detail: `non-photo/weak texture edge=${meanEdge.toFixed(2)}` }
  }
  return { ok: true, detail: `colors=${colors.size} edge=${meanEdge.toFixed(2)}` }
}

type Pt = { x: number; y: number }

function dist(a: Pt, b: Pt) {
  const dx = a.x - b.x
  const dy = a.y - b.y
  return Math.hypot(dx, dy)
}

/**
 * Anime / stylized faces often have oversized eyes vs face height.
 */
function looksStylizedLandmarks(positions: Pt[]): boolean {
  if (!positions || positions.length < 68) return true
  const leftEye = positions.slice(36, 42)
  const rightEye = positions.slice(42, 48)
  const eyeH = (pts: Pt[]) => {
    const top = Math.min(...pts.map((p) => p.y))
    const bottom = Math.max(...pts.map((p) => p.y))
    return Math.max(1, bottom - top)
  }
  const faceH = Math.max(1, positions[8].y - positions[27].y)
  const eyeFaceRatio = (eyeH(leftEye) + eyeH(rightEye)) / 2 / faceH
  const eyeDist = dist(
    {
      x: (leftEye[0].x + leftEye[3].x) / 2,
      y: (leftEye[0].y + leftEye[3].y) / 2
    },
    {
      x: (rightEye[0].x + rightEye[3].x) / 2,
      y: (rightEye[0].y + rightEye[3].y) / 2
    }
  )
  const jawW = dist(positions[0], positions[16])
  const eyeSpanRatio = eyeDist / Math.max(1, jawW)

  // Oversized eyes or extreme spacing → likely anime/cartoon
  if (eyeFaceRatio > 0.16) return true
  if (eyeSpanRatio > 0.55) return true
  return false
}

/**
 * Local face analyzer: age + gender + real-photo gate (no cloud API).
 * Safety-first: prefer hiding over letting a minor / non-human through.
 */
export async function estimateAgeFromImageBuffer(buffer: Buffer): Promise<PhotoAgeEstimate> {
  try {
    const realism = await assessPhotoRealism(buffer)
    if (!realism.ok) {
      return {
        estimatedAge: null,
        looksUnderage: false,
        confidence: 0.9,
        status: 'nonhuman',
        gender: 'unknown',
        genderConfidence: 0,
        detail: realism.detail
      }
    }

    await ensureModels()
    const jpeg = await toRgbTensorInput(buffer)
    const tensor = faceapi.tf.node.decodeImage(jpeg, 3)

    try {
      const detections = (await faceapi
        .detectAllFaces(
          tensor as any,
          new faceapi.SsdMobilenetv1Options({ minConfidence: 0.55 })
        )
        .withFaceLandmarks()
        .withAgeAndGender()) as Array<{
        detection: { score: number; box: { area: number; width: number; height: number } }
        landmarks: { positions: Pt[] }
        age: number
        gender: 'male' | 'female'
        genderProbability: number
      }>

      if (!detections.length) {
        return {
          estimatedAge: null,
          looksUnderage: false,
          confidence: 0,
          status: 'unclear',
          gender: 'unknown',
          genderConfidence: 0,
          detail: 'no face detected'
        }
      }

      const best = detections.reduce((a, b) =>
        (b.detection?.box?.area || 0) > (a.detection?.box?.area || 0) ? b : a
      )

      const estimatedAge = Math.round(Number(best.age))
      const genderProb = Number(best.genderProbability) || 0
      const genderRaw = best.gender === 'male' || best.gender === 'female' ? best.gender : 'unknown'
      const faceScore = Number(best.detection?.score) || 0
      const positions = best.landmarks?.positions || []

      // Age first — never let a young apparent age slip as "unclear".
      if (Number.isFinite(estimatedAge) && estimatedAge < MIN_APPARENT_AGE) {
        return {
          estimatedAge,
          looksUnderage: true,
          confidence: Math.min(1, Math.max(faceScore, 0.7)),
          status: 'underage',
          gender: genderRaw === 'female' ? 'female' : genderRaw === 'male' ? 'male' : 'unknown',
          genderConfidence: genderProb,
          detail: `apparent age ${estimatedAge} < min ${MIN_APPARENT_AGE}`
        }
      }

      if (faceScore < MIN_FACE_SCORE) {
        return {
          estimatedAge,
          looksUnderage: false,
          confidence: faceScore,
          status: 'unclear',
          gender: genderRaw === 'female' ? 'female' : genderRaw === 'male' ? 'male' : 'unknown',
          genderConfidence: genderProb,
          detail: `weak face score=${faceScore.toFixed(2)}`
        }
      }

      if (looksStylizedLandmarks(positions)) {
        return {
          estimatedAge,
          looksUnderage: false,
          confidence: 0.85,
          status: 'nonhuman',
          gender: genderRaw === 'female' ? 'female' : genderRaw === 'male' ? 'male' : 'unknown',
          genderConfidence: genderProb,
          detail: 'stylized/anime landmarks'
        }
      }

      if (genderRaw === 'male' && genderProb >= 0.55) {
        return {
          estimatedAge,
          looksUnderage: false,
          confidence: Math.min(1, genderProb),
          status: 'male',
          gender: 'male',
          genderConfidence: genderProb,
          detail: `male face conf=${genderProb.toFixed(2)} face=${faceScore.toFixed(2)}`
        }
      }

      if (!Number.isFinite(estimatedAge)) {
        return {
          estimatedAge: null,
          looksUnderage: true,
          confidence: Math.min(1, Math.max(faceScore, 0.7)),
          status: 'underage',
          gender: genderRaw === 'female' ? 'female' : genderRaw === 'male' ? 'male' : 'unknown',
          genderConfidence: genderProb,
          detail: `apparent age missing < min ${MIN_APPARENT_AGE}`
        }
      }

      if (genderRaw !== 'female' || genderProb < MIN_FEMALE_PROB) {
        return {
          estimatedAge,
          looksUnderage: false,
          confidence: genderProb,
          status: 'unclear',
          gender: genderRaw === 'female' ? 'female' : genderRaw === 'male' ? 'male' : 'unknown',
          genderConfidence: genderProb,
          detail: `ambiguous gender=${genderRaw} conf=${genderProb.toFixed(2)}`
        }
      }

      return {
        estimatedAge,
        looksUnderage: false,
        confidence: Math.min(1, Math.max(faceScore, genderProb)),
        status: 'ok',
        gender: 'female',
        genderConfidence: genderProb,
        detail: `female age≈${estimatedAge} gender=${genderProb.toFixed(2)} ${realism.detail}`
      }
    } finally {
      tensor.dispose()
    }
  } catch (e: any) {
    return {
      estimatedAge: null,
      looksUnderage: false,
      confidence: 0,
      status: 'error',
      gender: 'unknown',
      genderConfidence: 0,
      detail: String(e?.message || e).slice(0, 500)
    }
  }
}

export async function estimateAgeFromPhotoUrl(url: string): Promise<PhotoAgeEstimate> {
  const buf = await fetchImageBuffer(url)
  if (!buf) {
    return {
      estimatedAge: null,
      looksUnderage: false,
      confidence: 0,
      status: 'error',
      gender: 'unknown',
      genderConfidence: 0,
      detail: 'photo download failed'
    }
  }
  return estimateAgeFromImageBuffer(buf)
}
