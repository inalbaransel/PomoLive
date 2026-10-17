-- CreateTable
CREATE TABLE "PlusSubscription" (
    "originalTransactionId" VARCHAR(64) NOT NULL,
    "userId" UUID NOT NULL,
    "productId" VARCHAR(100) NOT NULL,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "environment" VARCHAR(16) NOT NULL,
    "revoked" BOOLEAN NOT NULL DEFAULT false,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "PlusSubscription_pkey" PRIMARY KEY ("originalTransactionId")
);

-- CreateIndex
CREATE INDEX "PlusSubscription_userId_expiresAt_idx" ON "PlusSubscription"("userId", "expiresAt");

-- AddForeignKey
ALTER TABLE "PlusSubscription" ADD CONSTRAINT "PlusSubscription_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

