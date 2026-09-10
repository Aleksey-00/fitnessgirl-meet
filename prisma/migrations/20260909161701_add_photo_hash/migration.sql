-- AlterTable
ALTER TABLE "Profile" ADD COLUMN     "photoHash" TEXT;

-- CreateIndex
CREATE INDEX "Profile_photoHash_idx" ON "Profile"("photoHash");
