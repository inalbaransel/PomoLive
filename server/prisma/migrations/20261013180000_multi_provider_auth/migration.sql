-- DropIndex
DROP INDEX "User_devSubject_key";

-- AlterTable
ALTER TABLE "User" DROP COLUMN "devSubject",
ADD COLUMN     "email" TEXT,
ADD COLUMN     "googleSubject" TEXT;

-- CreateIndex
CREATE UNIQUE INDEX "User_googleSubject_key" ON "User"("googleSubject");

-- CreateIndex
CREATE UNIQUE INDEX "User_email_key" ON "User"("email");

