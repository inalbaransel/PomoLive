# PomoLive'ı canlıya çıkarma rehberi

Sırayla git. Her adımın sonunda "✅ Bitti mi?" kontrolü var.

---

## 0. Ayrı bir web sitesi gerekmiyor

App Store'un istediği sayfalar sunucuda hazır:

| Apple'ın istediği | Adres |
|---|---|
| Gizlilik Politikası (zorunlu) | `https://api.pomolive.harbidigital.com/privacy` |
| Destek sayfası (zorunlu) | `https://api.pomolive.harbidigital.com/support` |
| Kullanım Şartları (abonelik için zorunlu) | `https://api.pomolive.harbidigital.com/terms` |

Tanıtım sitesi (Marketing URL) isteğe bağlı; sonra yapılabilir.

---

## 1. Apple Developer hesabı · 1–2 gün · yıllık 99 $

1. https://developer.apple.com/programs/enroll adresinden kaydol.
   - **Bireysel:** en kolayı. Mağazada satıcı olarak adın görünür.
   - **Şirket:** D-U-N-S numarası gerekir, 1–2 hafta sürer. Mağazada şirket adı görünür.
2. Ödeme yap ve onay e-postasını bekle.
3. developer.apple.com → **Account → Membership details** sayfasındaki **Team ID**'yi not al. 10 karakterlidir, örneğin `AB12CD34EF`.

✅ Team ID elinde mi?

---

## 2. Kimlikler: App ID ve App Group · 15 dk

developer.apple.com → **Certificates, Identifiers & Profiles → Identifiers**

1. **App Groups** sekmesi → **+** → `group.com.baransel.pomolive`
2. **App IDs** → **+** → App → Bundle ID: `com.baransel.pomolive`
   - Capabilities: **App Groups** (az önceki grubu seç) ve **Push Notifications**
3. Bir App ID daha: `com.baransel.pomolive.widgets`
   - Capabilities: **App Groups** (aynı grup)

Sertifika ve provisioning profile ile uğraşmana gerek yok; Xcode "Automatically manage signing" ile bunları kendisi yapar.

✅ İki App ID ve bir App Group oluştu mu?

---

## 3. Bildirim anahtarı (APNs .p8) · 5 dk

developer.apple.com → **Keys** → **+**

1. Ad: `PomoLive Push`, **Apple Push Notifications service (APNs)** kutusunu işaretle → Continue → Register.
2. **Download** ile `.p8` dosyasını indir. **Sadece bir kez indirilebilir**, güvenli bir yere sakla.
3. Sayfada yazan **Key ID**'yi not al (10 karakter).

Coolify'a girilecek üç değer:

| Değişken | Değer |
|---|---|
| `APNS_KEY_ID` | Key ID |
| `APNS_TEAM_ID` | 1. adımdaki Team ID |
| `APNS_PRIVATE_KEY` | `.p8` dosyasının tüm içeriği (`-----BEGIN PRIVATE KEY-----` dahil) |

✅ `.p8` dosyası saklandı mı, üç değer elinde mi?

---

## 4. Sunucu (Coolify) · 10 dk

1. Coolify → PomoLive → **Environment Variables**:
   - 3. adımdaki üç APNs değişkeni
   - `SUPPORT_EMAIL`: destek e-postan (sayfalarda görünür)
   - `ALLOW_XCODE_TRANSACTIONS`: **ekleme** (canlıda kapalı kalmalı)
2. **Redeploy**. Veritabanı değişiklikleri açılışta otomatik uygulanır.
3. Kontrol: `https://api.pomolive.harbidigital.com/health` adresi `{"status":"ok"}` dönmeli.
4. **Apple kök sertifikasını doğrula.** Plus satın almalarının doğrulanması buna bağlı. Terminalde:
   ```bash
   curl -sO https://www.apple.com/certificateauthority/AppleRootCA-G3.cer
   openssl x509 -inform der -in AppleRootCA-G3.cer -noout -fingerprint -sha256
   ```
   Çıkan değer `63:34:3A:BF:B8:9A:6A:03:EB:B5:7E:9B:3F:5F:A7:BE:7C:4F:5C:75:6F:30:17:B3:A8:C4:88:C3:65:3E:91:79` olmalı. Farklıysa Coolify'a `APPLE_ROOT_CA_SHA256` olarak doğrusunu gir.

✅ Health ok mu, parmak izi tuttu mu?

---

## 5. Banka ve vergi (abonelik satmak için zorunlu) · 30 dk + Apple onayı 1–3 gün

App Store Connect → **Business (İş)**

1. **Paid Apps Agreement**'ı kabul et.
2. **Banka hesabı:** TL ya da döviz IBAN'ı.
3. **Vergi formları:** ABD için **W-8BEN** (bireysel). Türkiye–ABD vergi anlaşması sayesinde stopaj genelde %0 olur.
4. Durum **Active** olana kadar abonelik satılamaz, TestFlight'ta bile ürünler görünmez.

**Türkiye'de vergi:** Mobil uygulama geliştiricileri için GVK 20/B kapsamında, gelirin bu iş için açılan özel bir banka hesabına gelmesi şartıyla %15 stopajlı bir istisna var. Yine de kesin durumu bir **muhasebeciye** danış.

✅ Paid Apps Agreement **Active** mi?

---

## 6. App Store Connect'te uygulama · 1 saat

https://appstoreconnect.apple.com → **Apps → +**

1. Platform iOS. Ad: **PomoLive** (alınmışsa "PomoLive: Odak Kütüphanesi" gibi bir ad dene). Birincil dil Türkçe. Bundle ID `com.baransel.pomolive`. SKU: `pomolive-ios`.
2. **App Information:** kategori **Productivity** (Verimlilik), ikinci kategori **Education** (Eğitim). Yaş derecesi formunda kullanıcı içeriği/sohbet için "Evet" de; muhtemelen 12+ çıkar.
3. **App Privacy:** cevaplar `docs/app-store.md`'de hazır.
4. **Abonelikler:** `docs/premium.md`'deki adımlar: grup, iki ürün, fiyatlar, 7 günlük deneme.
5. **Sürüm sayfası (1.0):**
   - Metinler, anahtar kelimeler, Support ve Privacy URL'leri `docs/app-store.md`'den kopyala.
   - **Ekran görüntüleri:** 6.9" iPhone için 3–10 tane (1320×2868). Ben simülatörden çekebilirim.
   - **App Review Information:** demo hesap aç (kullanıcı adı ve şifre), inceleme notunu `docs/app-store.md`'den kopyala.

✅ Uygulama kaydı, abonelikler ve sürüm sayfası dolu mu?

---

## 7. Build alma ve yükleme · 30 dk

1. `ios/project.yml` → `DEVELOPMENT_TEAM: "TEAMID"`. Bana Team ID'yi verirsen ben ayarlarım.
2. Terminal: `cd ios && xcodegen && git checkout -- PomoLive.xcodeproj/xcshareddata`
3. Xcode → `PomoLive.xcodeproj` aç → üstte cihaz olarak **Any iOS Device (arm64)** seç.
4. **Product → Archive**. Bittiğinde Organizer açılır.
5. **Distribute App → App Store Connect → Upload**. Signing ve push ortamını (production) Xcode kendisi ayarlar.
6. 10–30 dk sonra build App Store Connect → **TestFlight**'ta görünür. "Export compliance" sorusu çıkmaz, projede ayarlı.

Her yeni yüklemede `CURRENT_PROJECT_VERSION`'ı bir artır (1 → 2 → 3).

✅ Build TestFlight'ta mı?

---

## 8. TestFlight denemesi · 1–3 gün

1. TestFlight → **Internal Testing** → kendini ekle. iPhone'a TestFlight uygulamasını kur ve yükle.
2. Kontrol listesi:
   - [ ] Kayıt ve giriş
   - [ ] Masaya otur; kilit ekranında ve Dynamic Island'da sayaç görünüyor
   - [ ] Widget ekle, veri geliyor
   - [ ] İkinci bir hesapla takip et; uygulama kapalıyken "çalışmaya başladı" bildirimi geliyor
   - [ ] Plus: Ayarlar → Geliştirici → Sandbox hesabıyla satın al. Ekranda fiyatlar görünüyor, satın alınca Plus açılıyor
   - [ ] Geri yükleme, çıkış yapma, hesap silme
3. Arkadaşlarına açmak için **External Testing**: ilk sefer kısa bir Apple incelemesinden geçer, en fazla 10.000 kişi.

✅ Hepsi çalışıyor mu?

---

## 9. İncelemeye gönder · Apple 1–2 gün

1. Sürüm sayfasında build'i seç, abonelikleri de bu gönderime ekle.
2. **Submit for Review**.
3. Reddedilirse sebebi Resolution Center'da yazar. Bana getir, düzeltelim.
4. Onaylanınca **Release** de (ya da otomatik yayın seç).

---

## Toplam

| Kalem | Maliyet | Süre |
|---|---|---|
| Apple Developer | 99 $/yıl | 1–2 gün |
| Sunucu (Coolify) | mevcut | – |
| Banka ve vergi onayı | – | 1–3 gün |
| İnceleme | – | 1–2 gün |

Gerçekçi takvim: hesap açıldıktan sonra **1 hafta** içinde mağazada.
