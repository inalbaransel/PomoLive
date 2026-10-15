-- Rooms, categories and recorded sessions move from emoji to an SF Symbol plus a palette color.

-- Room
ALTER TABLE "Room" ADD COLUMN "symbol" VARCHAR(48) NOT NULL DEFAULT 'books.vertical.fill',
ADD COLUMN "color" VARCHAR(16) NOT NULL DEFAULT 'indigo';
ALTER TABLE "Room" ALTER COLUMN "symbol" DROP DEFAULT, ALTER COLUMN "color" DROP DEFAULT;
ALTER TABLE "Room" DROP COLUMN "emoji";

-- Category
ALTER TABLE "Category" ADD COLUMN "symbol" VARCHAR(48) NOT NULL DEFAULT 'square.grid.2x2.fill',
ADD COLUMN "color" VARCHAR(16) NOT NULL DEFAULT 'indigo';
ALTER TABLE "Category" ALTER COLUMN "symbol" DROP DEFAULT, ALTER COLUMN "color" DROP DEFAULT;
ALTER TABLE "Category" DROP COLUMN "emoji";

-- FocusSession: built-in categories get their real glyph, everything else the generic one.
ALTER TABLE "FocusSession" ADD COLUMN "categorySymbol" VARCHAR(48),
ADD COLUMN "categoryColor" VARCHAR(16);
UPDATE "FocusSession" SET
  "categorySymbol" = CASE "categoryKey"
    WHEN 'software' THEN 'chevron.left.forwardslash.chevron.right'
    WHEN 'study' THEN 'graduationcap.fill'
    WHEN 'reading' THEN 'book.fill'
    WHEN 'writing' THEN 'pencil.line'
    WHEN 'design' THEN 'paintpalette.fill'
    WHEN 'language' THEN 'character.bubble.fill'
    WHEN 'work' THEN 'briefcase.fill'
    ELSE 'square.grid.2x2.fill' END,
  "categoryColor" = CASE "categoryKey"
    WHEN 'software' THEN 'blue'
    WHEN 'study' THEN 'orange'
    WHEN 'reading' THEN 'brown'
    WHEN 'writing' THEN 'purple'
    WHEN 'design' THEN 'pink'
    WHEN 'language' THEN 'teal'
    WHEN 'work' THEN 'gray'
    ELSE 'indigo' END;
ALTER TABLE "FocusSession" ALTER COLUMN "categorySymbol" SET NOT NULL, ALTER COLUMN "categoryColor" SET NOT NULL;
ALTER TABLE "FocusSession" DROP COLUMN "categoryEmoji";
