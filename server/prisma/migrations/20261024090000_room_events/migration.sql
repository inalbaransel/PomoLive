-- CreateTable
CREATE TABLE "RoomEvent" (
    "id" UUID NOT NULL,
    "roomId" UUID NOT NULL,
    "title" VARCHAR(60) NOT NULL,
    "startsAt" TIMESTAMP(3) NOT NULL,
    "durationMinutes" INTEGER NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "RoomEvent_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "RoomEventRsvp" (
    "eventId" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "RoomEventRsvp_pkey" PRIMARY KEY ("eventId","userId")
);

-- CreateIndex
CREATE INDEX "RoomEvent_roomId_startsAt_idx" ON "RoomEvent"("roomId", "startsAt");

-- CreateIndex
CREATE INDEX "RoomEventRsvp_userId_idx" ON "RoomEventRsvp"("userId");

-- AddForeignKey
ALTER TABLE "RoomEvent" ADD CONSTRAINT "RoomEvent_roomId_fkey" FOREIGN KEY ("roomId") REFERENCES "Room"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "RoomEventRsvp" ADD CONSTRAINT "RoomEventRsvp_eventId_fkey" FOREIGN KEY ("eventId") REFERENCES "RoomEvent"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "RoomEventRsvp" ADD CONSTRAINT "RoomEventRsvp_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

