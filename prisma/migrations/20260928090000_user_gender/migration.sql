-- AlterEnum
CREATE TYPE "Gender" AS ENUM ('male', 'female');

-- AlterTable
ALTER TABLE "User" ADD COLUMN "gender" "Gender" NOT NULL DEFAULT 'male';

-- Backfill legacy catalog rows so gender filter works
UPDATE "Profile"
SET "photoGender" = 'female'
WHERE "photoAgeStatus" = 'ok'
  AND ("photoGender" IS NULL OR "photoGender" = '');

-- CreateIndex
CREATE INDEX "Profile_isHidden_photoGender_score_idx" ON "Profile"("isHidden", "photoGender", "score");
