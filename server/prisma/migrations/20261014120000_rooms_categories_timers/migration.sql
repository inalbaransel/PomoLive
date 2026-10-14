-- CreateEnum
CREATE TYPE "RoomVisibility" AS ENUM ('PUBLIC', 'PRIVATE');

-- CreateEnum
CREATE TYPE "TimerMode" AS ENUM ('POMODORO', 'STOPWATCH');

-- AlterTable
-- Existing sessions predate categories and timer modes: backfill them as "Diğer" stopwatch sessions.
ALTER TABLE "FocusSession" DROP COLUMN "taskLabel",
ADD COLUMN     "categoryEmoji" VARCHAR(16) NOT NULL DEFAULT '✨',
ADD COLUMN     "categoryKey" VARCHAR(64) NOT NULL DEFAULT 'other',
ADD COLUMN     "categoryName" VARCHAR(24) NOT NULL DEFAULT 'Diğer',
ADD COLUMN     "mode" "TimerMode" NOT NULL DEFAULT 'STOPWATCH',
ADD COLUMN     "note" VARCHAR(48),
ADD COLUMN     "roomName" VARCHAR(32) NOT NULL DEFAULT 'Piksel Salon';

ALTER TABLE "FocusSession" ALTER COLUMN "categoryEmoji" DROP DEFAULT,
ALTER COLUMN "categoryKey" DROP DEFAULT,
ALTER COLUMN "categoryName" DROP DEFAULT,
ALTER COLUMN "mode" DROP DEFAULT,
ALTER COLUMN "roomName" DROP DEFAULT;

-- CreateTable
CREATE TABLE "Room" (
    "id" UUID NOT NULL,
    "code" VARCHAR(6) NOT NULL,
    "name" VARCHAR(32) NOT NULL,
    "emoji" VARCHAR(16) NOT NULL,
    "visibility" "RoomVisibility" NOT NULL,
    "ownerId" UUID NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Room_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "RoomMembership" (
    "userId" UUID NOT NULL,
    "roomId" UUID NOT NULL,
    "lastVisitedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "RoomMembership_pkey" PRIMARY KEY ("userId","roomId")
);

-- CreateTable
CREATE TABLE "Category" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "name" VARCHAR(24) NOT NULL,
    "emoji" VARCHAR(16) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Category_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "Room_code_key" ON "Room"("code");

-- CreateIndex
CREATE INDEX "Room_visibility_createdAt_idx" ON "Room"("visibility", "createdAt");

-- CreateIndex
CREATE INDEX "RoomMembership_userId_lastVisitedAt_idx" ON "RoomMembership"("userId", "lastVisitedAt");

-- CreateIndex
CREATE UNIQUE INDEX "Category_userId_name_key" ON "Category"("userId", "name");

-- AddForeignKey
ALTER TABLE "Room" ADD CONSTRAINT "Room_ownerId_fkey" FOREIGN KEY ("ownerId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "RoomMembership" ADD CONSTRAINT "RoomMembership_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "RoomMembership" ADD CONSTRAINT "RoomMembership_roomId_fkey" FOREIGN KEY ("roomId") REFERENCES "Room"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Category" ADD CONSTRAINT "Category_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

