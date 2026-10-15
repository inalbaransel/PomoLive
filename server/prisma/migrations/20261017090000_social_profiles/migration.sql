-- AlterTable
ALTER TABLE "User" ADD COLUMN     "bio" VARCHAR(80),
ADD COLUMN     "statsVisible" BOOLEAN NOT NULL DEFAULT true,
ADD COLUMN     "username" VARCHAR(20);

-- Backfill: existing readers get a handle from their e-mail's local part, numbered on clashes.
WITH "candidate" AS (
    SELECT "id", "createdAt",
           left(coalesce(nullif(regexp_replace(lower(split_part("email", '@', 1)), '[^a-z0-9_]', '', 'g'), ''), 'okur'), 15) AS "base"
    FROM "User"
), "padded" AS (
    SELECT "id", "createdAt", CASE WHEN length("base") < 3 THEN 'okur_' || "base" ELSE "base" END AS "base"
    FROM "candidate"
), "numbered" AS (
    SELECT "id", "base", row_number() OVER (PARTITION BY "base" ORDER BY "createdAt", "id") AS "n"
    FROM "padded"
)
UPDATE "User" SET "username" = CASE WHEN "numbered"."n" = 1 THEN "numbered"."base" ELSE "numbered"."base" || '_' || "numbered"."n" END
FROM "numbered"
WHERE "numbered"."id" = "User"."id";

ALTER TABLE "User" ALTER COLUMN "username" SET NOT NULL;

-- CreateTable
CREATE TABLE "RoomBan" (
    "roomId" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "RoomBan_pkey" PRIMARY KEY ("roomId","userId")
);

-- CreateIndex
CREATE UNIQUE INDEX "User_username_key" ON "User"("username");

-- AddForeignKey
ALTER TABLE "RoomBan" ADD CONSTRAINT "RoomBan_roomId_fkey" FOREIGN KEY ("roomId") REFERENCES "Room"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "RoomBan" ADD CONSTRAINT "RoomBan_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
