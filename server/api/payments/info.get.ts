export default defineEventHandler(async () => {
  const config = useRuntimeConfig()
  return {
    priceRub: Number(config.subscriptionPriceRub) || 990,
    days: Number(config.subscriptionDays) || 30,
    bank: config.paymentBank || 'Сбербанк',
    card: config.paymentCard || '',
    phone: config.paymentPhone || '',
    holder: config.paymentHolder || ''
  }
})
