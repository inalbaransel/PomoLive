# PomoLive

16-bit piksel bir kütüphane salonunda, başkalarıyla birlikte eşzamanlı odaklanma uygulaması.
Native iOS 26 (SwiftUI, Liquid Glass) + NestJS WebSocket backend.

```
server/   NestJS 12 · ws · Redis · PostgreSQL/Prisma 7
ios/      SwiftUI · Swift 6 strict concurrency · ActivityKit · CoreHaptics (XcodeGen)
docker-compose.yml   Coolify için production stack (server + postgres + redis)
```

## Mimari

**Her şey tek bir WebSocket üzerinden** (`/ws`). HTTP'de yalnızca `GET /health` (Coolify healthcheck) var.

- Çerçeve: `{ "event": string, "data": object }`. İstemci komutları `data.ref` taşır, sunucu her birine
  aynı `ref` ile bir `reply` döner (`ok: true, result` veya `ok: false, error: { code, message }`).
  Oda değişiklikleri `ref`'siz yayın olarak gelir: `desk:occupied`, `desk:updated`, `desk:vacated`, `room:presence`.
- Kontrat: [`server/src/realtime/protocol.ts`](server/src/realtime/protocol.ts) ↔ [`ios/PomoLive/Networking`](ios/PomoLive/Networking).
- **Zaman damgası senkronu:** Sunucu tick göndermez. Salonun pomodoro döngüsü `cycleAnchorAt`'ten deterministik
  hesaplanır (sunucu `cycle.ts`, iOS `HallCycle.swift`). İstemci saat farkını her heartbeat'te NTP tarzı ölçer.
- **Masa durumu Redis'te, atomik Lua script'leriyle** (`desk-store.ts`): masa kaydı, kullanıcının koltuk
  işaretçisi ve lease her zaman tutarlıdır. Çoklu instance'ta yayın Redis pub/sub ile yapılır.
- **Lease:** ön planda 90 sn, arka plana geçerken 45 dk (kilitli telefon masasını kaybetmez). `LeaseReaper`
  süresi dolan masaları boşaltır ve seansı Postgres'e yazar (Redis kilidiyle tek instance çalışır).
- **Auto-sharding:** Genel salon 25 kişiye (`SHARD_THRESHOLD`) ulaşınca yeni `pixel-hall-N` açılır.
  Özel salonlar 6 haneli kodla (`room:create` / `room:join { code }`).
- **Kimlik:** Sign in with Apple (nonce doğrulamalı) → sunucu 30 günlük session JWT verir, cihaz Keychain'de saklar.
  Debug build'lerde simülatör için "Geliştirici olarak devam et" (`DEV_AUTH_ENABLED`, production'da reddedilir).
- **Harita veri odaklı:** Salon planı (`library-layout.ts`) her snapshot'la gelir. iOS zemin ve dekoru
  tek bir bitmap'e basar (16 px/tile, nearest-neighbour), masalar animasyonlu sprite'lardır. Tüm piksel
  sanat kodla üretilir (`ios/Shared/PixelArt`, `ios/PomoLive/PixelArt`).

## Yerel geliştirme

Gerekenler: Node 24, Redis, PostgreSQL, Xcode 27, XcodeGen.

```bash
cd server
cp .env.example .env          # DATABASE_URL / REDIS_URL'i kendi servislerine göre düzenle
npm install
npx prisma generate
npx prisma migrate deploy
npm run start:dev             # ws://localhost:3000/ws
```

```bash
cd ios
xcodegen generate             # yalnızca project.yml değişince gerekir; klasörler senkronize
open PomoLive.xcodeproj
```

Debug build `ws://localhost:3000/ws`'e, Release build `POMOLIVE_SERVER_URL`'e bağlanır (`ios/project.yml`).
Gerçek cihazda Sign in with Apple için `DEVELOPMENT_TEAM`'i ayarla ve App ID'de capability'yi aç.

### Testler

```bash
cd server
npm test                      # birim testler
npm run test:e2e              # gerçek Redis + Postgres ile WebSocket protokol testleri
npm run lint
```

## Deploy (Coolify / Hetzner)

Coolify'da "Docker Compose" build pack ile repo kökündeki `docker-compose.yml`'ı kullan ve şu değişkenleri tanımla:
`POSTGRES_PASSWORD`, `SESSION_SECRET` (`openssl rand -base64 48`), `APPLE_BUNDLE_ID`.
Container açılışta `prisma migrate deploy` çalıştırır. Domain'i `server:3000`'e yönlendir; WebSocket upgrade Coolify proxy'sinde varsayılan olarak açıktır.
