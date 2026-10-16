-- CreateTable
CREATE TABLE "FocusTask" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "title" VARCHAR(120) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "completedAt" TIMESTAMP(3),

    CONSTRAINT "FocusTask_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "FocusTask_userId_createdAt_idx" ON "FocusTask"("userId", "createdAt");

-- AddForeignKey
ALTER TABLE "FocusTask" ADD CONSTRAINT "FocusTask_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

