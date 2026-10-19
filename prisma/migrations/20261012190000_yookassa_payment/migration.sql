-- AlterTable
ALTER TABLE "PaymentClaim" ADD COLUMN     "provider" TEXT NOT NULL DEFAULT 'manual',
ADD COLUMN     "yookassaPaymentId" TEXT,
ADD COLUMN     "paidAt" TIMESTAMP(3);

-- CreateIndex
CREATE UNIQUE INDEX "PaymentClaim_yookassaPaymentId_key" ON "PaymentClaim"("yookassaPaymentId");
