-- AlterTable
ALTER TABLE "PaymentClaim" ADD COLUMN     "invId" SERIAL NOT NULL;

-- CreateIndex
CREATE UNIQUE INDEX "PaymentClaim_invId_key" ON "PaymentClaim"("invId");
