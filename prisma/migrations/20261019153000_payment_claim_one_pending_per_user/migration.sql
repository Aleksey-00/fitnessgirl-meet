-- Prevent the race where two concurrent requests (e.g. manual claim + Robokassa create) both pass
-- the "no pending claim" check and insert two pending PaymentClaim rows for the same user.
-- Prisma's schema language has no native partial-index syntax, so this is a SQL-only migration
-- (see the comment on the PaymentClaim model in schema.prisma).
CREATE UNIQUE INDEX "PaymentClaim_one_pending_per_user" ON "PaymentClaim"("userId") WHERE "status" = 'pending';
