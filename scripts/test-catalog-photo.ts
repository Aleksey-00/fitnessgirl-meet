/**
 * Lightweight asserts for catalog photo helpers.
 *   npx tsx scripts/test-catalog-photo.ts
 */
import assert from 'node:assert/strict'
import {
  catalogPlaceholderUrl,
  isCatalogPlaceholderUrl,
  largestVkPhotoUrl,
  mergePhotoCandidates
} from '../lib/catalogPhoto'

assert.equal(catalogPlaceholderUrl('female'), '/placeholders/catalog-female.svg')
assert.equal(catalogPlaceholderUrl('male'), '/placeholders/catalog-male.svg')
assert.equal(isCatalogPlaceholderUrl('/placeholders/catalog-female.svg'), true)
assert.equal(isCatalogPlaceholderUrl('https://vk.com/x.jpg'), false)

assert.equal(
  largestVkPhotoUrl({
    sizes: [
      { type: 'm', url: 'http://a/m.jpg', width: 130, height: 130 },
      { type: 'z', url: 'http://a/z.jpg', width: 1280, height: 1024 }
    ]
  }),
  'http://a/z.jpg'
)

assert.deepEqual(mergePhotoCandidates(['http://a', 'http://a', null], ['http://b', 'http://a']), [
  'http://a',
  'http://b'
])

console.log('test-catalog-photo: ok')
