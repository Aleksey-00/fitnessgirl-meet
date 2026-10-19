/** Public реквизиты for /contacts and /offer — no auth required. */
export default defineEventHandler(async () => {
  return getLegalRuntime()
})
