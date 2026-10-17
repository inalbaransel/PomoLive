# App Store hazırlığı

## Bağlantılar (App Store Connect › App Information)
- Privacy Policy URL: `https://<sunucu-alan-adı>/privacy`
- Support URL: `https://<sunucu-alan-adı>/support`
- Terms of Use (EULA, isteğe bağlı): `https://<sunucu-alan-adı>/terms`

`SUPPORT_EMAIL` ortam değişkeni ayarlanınca bu sayfalarda iletişim adresi görünür.

## Mağaza metinleri

**Ad:** PomoLive
**Alt başlık (TR):** Birlikte sessizce odaklan
**Subtitle (EN):** Focus quietly, together

**Anahtar kelimeler (TR):** pomodoro,odak,ders çalışma,kütüphane,sayaç,verimlilik,study with me,yks,kpss,zamanlayıcı
**Keywords (EN):** pomodoro,focus,study,library,timer,productivity,study with me,deep work,coworking,habit

**Açıklama (TR):**
PomoLive, telefonundaki sessiz kütüphane. Piksel bir okuma salonunda bir masaya otur, lamban yansın ve aynı anda odaklanan başkalarıyla çalış. Kamera yok, konuşma zorunluluğu yok; sadece birlikte çalışmanın verdiği güç.

• Gerçek zamanlı salonlar ve kendi odaların: özel kodla arkadaşlarını davet et
• Pomodoro ya da kronometre; kilit ekranında, Dynamic Island'da ve widget'larda
• OLED odak modu, yağmur ve şömine gibi odak sesleri
• Günlük ve haftalık hedefler, seri, rozetler ve ayrıntılı istatistik
• Arkadaşlarını takip et, çalışmaya başladıklarında haberin olsun
• Oda etkinlikleri ve hatırlatmalar
• Haftanı hikâye kartı olarak paylaş

**Description (EN):**
PomoLive is a quiet library in your pocket. Take a desk in a pixel reading room, your lamp lights up, and you focus alongside everyone else who is working right now. No camera, no need to talk; just the push of working together.

• Live halls and your own rooms, shared with a private code
• Pomodoro or stopwatch, on the Lock Screen, in the Dynamic Island and in widgets
• OLED focus mode and focus sounds like rain and a fireplace
• Daily and weekly goals, streaks, badges and detailed stats
• Follow friends and hear when they start focusing
• Room events with reminders
• Share your week as a Stories card

## App Privacy (Uygulama Gizliliği) yanıtları
Takip (tracking): **Hayır**. Toplanan veriler, hepsi kimliğe bağlı ve yalnızca "App Functionality" amaçlı:
- Contact Info › Email Address
- Contact Info › Name (görünen ad)
- Identifiers › User ID, Device ID (push anahtarı)
- User Content › Other User Content (sohbet, biyografi, oda adları)
- Usage Data › Product Interaction (odak oturumları)

Uygulamadaki `PrivacyInfo.xcprivacy` ile birebir aynıdır.

## İnceleme notları (App Review Information)
- Demo hesap: inceleme için ayrı bir hesap aç ve kullanıcı adı ile şifresini buraya yaz.
- Kullanıcı içeriği (Guideline 1.2): uygunsuz kelimeler sohbette otomatik gizlenir, adlarda reddedilir. Her mesaj basılı tutularak, her profil ••• menüsünden bildirilebilir ve engellenebilir. Üç ayrı kişinin bildirdiği mesaj otomatik kaldırılır. Raporlar sunucudaki `Report` tablosunda tutulur ve 24 saat içinde incelenir. Kullanım şartları kuralları açıkça yazar.
- Hesap silme (Guideline 5.1.1(v)): Profil › Hesabı Sil.
- Arka plan ses modu: odak sesleri (yağmur, dalga vb.) telefon kilitliyken çalmaya devam eder.

## Yayın öncesi kontrol listesi
1. Apple Developer › Identifiers: `com.baransel.pomolive` ve `.widgets` için App Groups (`group.com.baransel.pomolive`) ve Push Notifications yeteneklerini aç.
2. Apple Developer › Keys: APNs anahtarı (.p8) oluştur; `APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_PRIVATE_KEY` değerlerini Coolify'a gir.
3. Coolify'da yeniden dağıt (yeni migration'lar otomatik uygulanır).
4. Archive al, TestFlight'a yükle; `ITSAppUsesNonExemptEncryption = NO` olduğu için şifreleme sorusu çıkmaz.
