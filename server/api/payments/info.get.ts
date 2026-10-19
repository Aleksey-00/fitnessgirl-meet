export default defineEventHandler(async () => {
  return { ...getPaymentRuntime(), robokassaEnabled: robokassaEnabled() }
})
