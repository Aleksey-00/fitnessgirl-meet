-- AlterTable
ALTER TABLE "Profile" ADD COLUMN     "photoAgeCheckedAt" TIMESTAMP(3),
ADD COLUMN     "photoAgeConfidence" DOUBLE PRECISION,
ADD COLUMN     "photoAgeStatus" TEXT,
ADD COLUMN     "photoEstimatedAge" INTEGER;

-- CreateIndex
CREATE INDEX "Profile_photoAgeStatus_idx" ON "Profile"("photoAgeStatus");
