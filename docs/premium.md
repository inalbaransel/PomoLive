# PomoLive Plus

## Plan

| Plan | Ürün kimliği | Türkiye | ABD / Avrupa | Not |
|---|---|---|---|---|
| Yıllık | `com.baransel.pomolive.plus.yearly` | ₺299,99 | $49,99 / €49,99 | 7 gün ücretsiz deneme (yeni aboneler) |
| Aylık | `com.baransel.pomolive.plus.monthly` | ₺39,99 | $7,99 / €7,99 | |

Diğer ülkeler ABD fiyatından Apple'ın otomatik çevirisini kullanır. Alım gücü düşük ülkelerde (Hindistan, Brezilya, Endonezya, Mısır…) Türkiye gibi elle düşük fiyat girilir.

**Ücretsiz:** salonlar, masa ve sayaç, sohbet, takip, tepkiler, canlı akış, oda etkinlikleri, çalışma arkadaşı, 2 oda, temel istatistik.
**Plus:** 10 oda, Orman/Sahil/Uzay temaları, Plus karakterleri, gelişmiş istatistik (ısı haritası, trendler, CSV), Plus sesleri, tam odak modu.

Kilit listesi sunucuda `server/src/plus/plus-catalog.ts`, uygulamada `PlusCatalog` (aynı tutulmalı). Zaten kullanılan Plus tema ve karakterleri abonelik bitse de kalır; sadece yeni seçim kilitlidir.

## App Store Connect kurulumu
1. **Uygulama › Abonelikler › Abonelik Grubu oluştur:** "PomoLive Plus".
2. Gruba iki abonelik ekle, kimlikler yukarıdaki gibi. Yıllığı üste koy (1. seviye).
3. **Fiyatlandırma:** ABD fiyatını gir, Türkiye ve düşük alım gücü olan ülkelerde fiyatı elle değiştir.
4. **Yıllık › Tanıtım Teklifi:** Ücretsiz, 1 hafta, tüm ülkeler.
5. Her abonelik için görünen ad ve açıklama (TR ve EN), inceleme ekran görüntüsü (Plus ekranı).
6. **Uygulama bilgileri:** Lisans sözleşmesi olarak `/terms` sayfası, gizlilik politikası `/privacy`.
7. İlk sürümü incelemeye gönderirken abonelikleri de aynı gönderime ekle.

## Nasıl çalışıyor
- Satın alma Apple'ın kendi abonelik ekranıyla yapılır (`SubscriptionStoreView`): fiyatlar, deneme, geri yükleme ve yasal bağlantılar Apple'ın kurallarına göre gösterilir.
- Her işlem (satın alma, yenileme, uygulama açılışı) Apple'ın imzalı makbuzu olarak sunucuya gider. Sunucu, imza zincirini Apple Root CA G3'e kadar doğrular (`APPLE_ROOT_CA_SHA256`), süreyi kaydeder. Plus hesaba bağlıdır, tüm cihazlarda açılır.
- Yerel test: Xcode'da **⌘R** ile çalıştır. Scheme `Config/PomoLivePlus.storekit` dosyasını kullanır; sunucuyu `ALLOW_XCODE_TRANSACTIONS=true` ile başlat. Canlıda bu değişken **kapalı** kalmalı.
- Sandbox (TestFlight) satın almaları gerçek Apple sertifikasıyla imzalanır; ek ayar gerekmez.

## Bilinen sınır
İade ve iptal, uygulama bir sonraki açıldığında öğrenilir. Anında öğrenmek için App Store Server Notifications V2 (sunucuya Apple'dan gelen bildirim) ileride eklenebilir.
