-- Accounts created through Apple, Google or e-mail codes have no password and can no longer sign in.
DELETE FROM "User";

-- DropIndex
DROP INDEX "User_appleSubject_key";

-- DropIndex
DROP INDEX "User_googleSubject_key";

-- AlterTable
ALTER TABLE "User" DROP COLUMN "appleSubject",
DROP COLUMN "googleSubject",
ADD COLUMN     "passwordHash" TEXT NOT NULL,
ALTER COLUMN "email" SET NOT NULL;

