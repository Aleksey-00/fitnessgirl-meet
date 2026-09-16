import { indexerAvailable, isIndexerRunning } from '../../utils/indexerRunner'

export default defineEventHandler(async (event) => {
  await requireAdmin(event)
  const avail = indexerAvailable()
  return {
    available: avail.ok,
    reason: avail.reason || null,
    running: isIndexerRunning()
  }
})
