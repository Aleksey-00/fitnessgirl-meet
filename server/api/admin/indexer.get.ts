import { getVkTokenStatus } from '../../utils/indexerRunner'

export default defineEventHandler(async (event) => {
  await requireAdmin(event)
  return getVkTokenStatus()
})
