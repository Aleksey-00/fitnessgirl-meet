export default defineEventHandler(async (event) => {
  let db = false
  try {
    await prisma.$queryRaw`SELECT 1`
    db = true
  } catch {
    db = false
  }
  const ok = db
  setResponseStatus(event, ok ? 200 : 503)
  return {
    ok,
    db,
    time: new Date().toISOString()
  }
})
