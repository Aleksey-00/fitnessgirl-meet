import sharp from 'sharp'

/**
 * Difference hash (dHash), 64 bits as hex string.
 * Robust to resize/compression; similar photos have small Hamming distance.
 */
export async function computePhotoDHash(buffer: Buffer): Promise<string> {
  const raw = await sharp(buffer)
    .greyscale()
    .resize(9, 8, { fit: 'fill' })
    .raw()
    .toBuffer()

  let bits = ''
  for (let row = 0; row < 8; row++) {
    for (let col = 0; col < 8; col++) {
      const left = raw[row * 9 + col]
      const right = raw[row * 9 + col + 1]
      bits += left < right ? '1' : '0'
    }
  }

  let hex = ''
  for (let i = 0; i < 64; i += 4) {
    hex += Number.parseInt(bits.slice(i, i + 4), 2).toString(16)
  }
  return hex
}

export function hammingDistanceHex(a: string, b: string): number {
  if (!a || !b || a.length !== b.length) return 64
  let dist = 0
  for (let i = 0; i < a.length; i++) {
    const x = Number.parseInt(a[i], 16) ^ Number.parseInt(b[i], 16)
    dist += popcount4(x)
  }
  return dist
}

function popcount4(n: number): number {
  let c = 0
  let v = n
  while (v) {
    c += v & 1
    v >>= 1
  }
  return c
}

export async function fetchImageBuffer(url: string): Promise<Buffer | null> {
  try {
    const res = await fetch(url, {
      headers: {
        'User-Agent':
          'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
        Referer: 'https://vk.com/',
        Accept: 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8'
      },
      signal: AbortSignal.timeout(20000)
    })
    if (!res.ok) return null
    const ab = await res.arrayBuffer()
    if (!ab.byteLength) return null
    return Buffer.from(ab)
  } catch {
    return null
  }
}
