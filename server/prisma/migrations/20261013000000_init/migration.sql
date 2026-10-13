-- CreateSchema
CREATE SCHEMA IF NOT EXISTS "public";

-- CreateEnum
CREATE TYPE "SessionEndReason" AS ENUM ('STOOD_UP', 'LEASE_EXPIRED');

-- CreateTable
CREATE TABLE "User" (
    "id" UUID NOT NULL,
    "appleSubject" TEXT,
    "devSubject" TEXT,
    "displayName" VARCHAR(24) NOT NULL,
    "avatarSpriteId" VARCHAR(32) NOT NULL DEFAULT 'scholar_01',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "User_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "FocusSession" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "roomId" VARCHAR(64) NOT NULL,
    "deskId" VARCHAR(16) NOT NULL,
    "taskLabel" VARCHAR(48) NOT NULL,
    "startedAt" TIMESTAMP(3) NOT NULL,
    "endedAt" TIMESTAMP(3) NOT NULL,
    "focusedMs" INTEGER NOT NULL,
    "endReason" "SessionEndReason" NOT NULL,

    CONSTRAINT "FocusSession_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "User_appleSubject_key" ON "User"("appleSubject");

-- CreateIndex
CREATE UNIQUE INDEX "User_devSubject_key" ON "User"("devSubject");

-- CreateIndex
CREATE INDEX "FocusSession_userId_startedAt_idx" ON "FocusSession"("userId", "startedAt");

-- AddForeignKey
ALTER TABLE "FocusSession" ADD CONSTRAINT "FocusSession_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

