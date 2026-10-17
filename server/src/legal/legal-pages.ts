/**
 * The privacy policy, terms of use and support page App Store Connect links to, in Turkish and
 * English on one page each. Plain HTML that reads well on a phone and in both colour schemes.
 */
const UPDATED = '17 Ekim 2026 · 17 October 2026';

function page(title: string, body: string): string {
  return `<!doctype html>
<html lang="tr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${title} · PomoLive</title>
<style>
  :root { color-scheme: light dark; --fg: #1b1a2e; --muted: #5d5b78; --bg: #f6f6fb; --accent: #4b47d6; }
  @media (prefers-color-scheme: dark) { :root { --fg: #e9e8f7; --muted: #a09ebf; --bg: #0f0f1a; --accent: #8c8cff; } }
  body { margin: 0; background: var(--bg); color: var(--fg); font: 16px/1.6 -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; }
  main { max-width: 680px; margin: 0 auto; padding: 40px max(20px, env(safe-area-inset-left)) 64px; }
  h1 { font-size: 30px; line-height: 1.2; margin: 0 0 4px; }
  h2 { font-size: 20px; margin: 32px 0 8px; }
  h3 { font-size: 16px; margin: 20px 0 4px; }
  p, li { color: var(--fg); }
  .muted { color: var(--muted); font-size: 14px; }
  a { color: var(--accent); }
  hr { border: 0; border-top: 1px solid color-mix(in srgb, var(--muted) 30%, transparent); margin: 48px 0; }
</style>
</head>
<body><main>
<h1>${title}</h1>
<p class="muted">PomoLive · ${UPDATED}</p>
${body}
</main></body>
</html>`;
}

function contact(email: string | null, language: 'tr' | 'en'): string {
  if (email) return `<a href="mailto:${email}">${email}</a>`;
  return language === 'tr'
    ? 'uygulamadaki Profil › Destek bölümü'
    : 'Profile › Support in the app';
}

export function privacyPage(email: string | null): string {
  return page(
    'Gizlilik Politikası · Privacy Policy',
    `
<h2>Türkçe</h2>
<p>PomoLive, başkalarıyla birlikte sessizce odaklanmanı sağlayan bir uygulamadır. Yalnızca uygulamanın çalışması için gereken verileri toplarız. Reklam göstermeyiz, seni uygulamalar ve siteler arasında izlemeyiz, verini kimseye satmayız.</p>
<h3>Topladığımız veriler</h3>
<ul>
  <li><b>Hesap:</b> e-posta adresi, şifrenin geri döndürülemez özeti (scrypt), kullanıcı adı, görünen ad, avatar ve isteğe bağlı kısa biyografi.</li>
  <li><b>Odak verisi:</b> oturduğun masa, seçtiğin kategori ve not, sayaç ayarların, biten oturumların süresi ve zamanı, hedeflerin, görevlerin.</li>
  <li><b>Topluluk:</b> oluşturduğun odalar, oda sohbetine yazdığın mesajlar, takip ettiğin kişiler, etkinlik katılımların, engellediğin kişiler ve gönderdiğin raporlar.</li>
  <li><b>Bildirim:</b> bildirimlere izin verirsen cihazının Apple bildirim anahtarı.</li>
  <li><b>Saat dilimi:</b> günlük istatistikleri doğru hesaplamak için.</li>
</ul>
<p>Konum, kişiler, kamera, mikrofon, fotoğraf ya da reklam kimliği gibi verilere erişmeyiz.</p>
<h3>Kimler görebilir</h3>
<p>Kullanıcı adın, görünen adın, avatarın, biyografin ve masadaki durumun diğer kullanıcılara görünür. Odak sürelerin ve hedeflerin, profilinde gizlemediğin sürece görünür. Sohbet mesajların odadaki kişilere görünür. E-posta adresin kimseye gösterilmez.</p>
<h3>Saklama ve silme</h3>
<p>Verilerin hesabın açık olduğu sürece saklanır. Profil › Hesabı Sil ile hesabını ve ona bağlı tüm verileri (oturumlar, mesajlar, odalar, takipler, cihaz anahtarları) kalıcı olarak silebilirsin. Topluluğu korumak için incelenen raporlar en fazla 12 ay saklanır.</p>
<h3>Altyapı</h3>
<p>Veriler, şifreli bağlantı (TLS) üzerinden erişilen kendi sunucularımızda tutulur. Bildirimler Apple Push Notification service aracılığıyla iletilir.</p>
<h3>Hakların</h3>
<p>6698 sayılı KVKK ve GDPR kapsamında verilerine erişme, düzeltme, silme ve itiraz etme hakkın var. Bunların çoğunu uygulama içinden yapabilirsin; diğer talepler için: ${contact(email, 'tr')}.</p>
<p>PomoLive 13 yaşından küçükler için tasarlanmamıştır.</p>

<hr>

<h2>English</h2>
<p>PomoLive lets you focus quietly alongside other people. We collect only what the app needs to work. We show no ads, do not track you across apps and websites, and never sell your data.</p>
<h3>What we collect</h3>
<ul>
  <li><b>Account:</b> e-mail address, a one-way hash of your password (scrypt), username, display name, avatar and an optional short bio.</li>
  <li><b>Focus data:</b> the desk you take, your category and note, timer settings, the length and time of finished sessions, your goals and tasks.</li>
  <li><b>Community:</b> rooms you create, messages you write in room chats, people you follow, event RSVPs, people you block and reports you send.</li>
  <li><b>Notifications:</b> your device's Apple push token, if you allow notifications.</li>
  <li><b>Time zone:</b> to compute daily statistics correctly.</li>
</ul>
<p>We do not access your location, contacts, camera, microphone, photos or advertising identifier.</p>
<h3>Who can see it</h3>
<p>Your username, display name, avatar, bio and desk status are visible to other readers. Your focus time and goals are visible unless you hide them on your profile. Chat messages are visible to people in the room. Your e-mail address is never shown.</p>
<h3>Retention and deletion</h3>
<p>Data is kept while your account exists. Profile › Delete Account permanently removes your account and everything linked to it (sessions, messages, rooms, follows, device tokens). Reviewed reports are kept for up to 12 months to protect the community.</p>
<h3>Infrastructure</h3>
<p>Data is stored on our own servers and reached over encrypted connections (TLS). Notifications are delivered through Apple Push Notification service.</p>
<h3>Your rights</h3>
<p>Under GDPR and Turkish law (KVKK) you may access, correct, delete and object to the processing of your data. Most of this is available in the app; for anything else: ${contact(email, 'en')}.</p>
<p>PomoLive is not directed at children under 13.</p>
`,
  );
}

export function termsPage(email: string | null): string {
  return page(
    'Kullanım Şartları · Terms of Use',
    `
<h2>Türkçe</h2>
<p>PomoLive'ı kullanarak bu şartları kabul etmiş olursun.</p>
<h3>Topluluk kuralları</h3>
<p>PomoLive sessiz bir kütüphanedir. Aşağıdakilere <b>kesinlikle izin verilmez</b>:</p>
<ul>
  <li>Taciz, tehdit, zorbalık ya da bir kişiyi hedef alan içerik</li>
  <li>Nefret söylemi, ayrımcılık, şiddet çağrısı</li>
  <li>Cinsel içerik, çocukların istismarına dair her türlü içerik</li>
  <li>Spam, reklam, dolandırıcılık ya da başkasının kimliğine bürünme</li>
  <li>Kendine zarar vermeyi özendiren içerik</li>
</ul>
<p>Uygunsuz kelimeler sohbette otomatik olarak gizlenir; adlarda ve oda başlıklarında kabul edilmez. Her mesajı ve kişiyi uygulama içinden <b>bildirebilir</b> ve <b>engelleyebilirsin</b>. Raporları 24 saat içinde inceler, kuralları çiğneyen içeriği kaldırır ve gerekirse hesabı kapatırız. Birden fazla kişinin bildirdiği mesajlar incelemeyi beklemeden kaldırılır. Oda sahipleri kendi odalarından kişi çıkarabilir.</p>
<h3>Hesabın</h3>
<p>Hesabının güvenliğinden sen sorumlusun. Bu şartları çiğneyen hesapları uyarmadan askıya alabilir ya da kapatabiliriz. Hesabını istediğin zaman uygulama içinden silebilirsin.</p>
<h3>Abonelikler</h3>
<p>Ücretli özellikler sunulduğunda satın alma ve iptal işlemleri Apple Kimliğin üzerinden yapılır ve Apple'ın koşullarına tabidir.</p>
<h3>Sorumluluk</h3>
<p>PomoLive "olduğu gibi" sunulur. Hizmetin kesintisiz ya da hatasız olacağını garanti etmeyiz. Diğer kullanıcıların yazdıklarından onlar sorumludur.</p>
<p>İletişim: ${contact(email, 'tr')}.</p>

<hr>

<h2>English</h2>
<p>By using PomoLive you agree to these terms.</p>
<h3>Community rules</h3>
<p>PomoLive is a quiet library. The following are <b>not tolerated</b>:</p>
<ul>
  <li>Harassment, threats, bullying or content targeting a person</li>
  <li>Hate speech, discrimination or calls to violence</li>
  <li>Sexual content, and any content related to the exploitation of children</li>
  <li>Spam, advertising, scams or impersonation</li>
  <li>Content that encourages self-harm</li>
</ul>
<p>Objectionable words are hidden automatically in chat and refused in names and room titles. You can <b>report</b> and <b>block</b> any message or person from inside the app. We review reports within 24 hours, remove content that breaks these rules and close accounts when needed. Messages reported by several people are removed before review. Room owners can remove people from their rooms.</p>
<h3>Your account</h3>
<p>You are responsible for keeping your account secure. We may suspend or close accounts that break these terms without notice. You can delete your account at any time from inside the app.</p>
<h3>Subscriptions</h3>
<p>When paid features are offered, purchases and cancellations go through your Apple Account and follow Apple's terms.</p>
<h3>Liability</h3>
<p>PomoLive is provided "as is". We do not guarantee that the service will be uninterrupted or error-free. Other readers are responsible for what they write.</p>
<p>Contact: ${contact(email, 'en')}.</p>
`,
  );
}

export function supportPage(email: string | null): string {
  return page(
    'Destek · Support',
    `
<h2>Türkçe</h2>
<h3>Masam neden boşaldı?</h3>
<p>Uygulama arka plandayken masan 45 dakika korunur. Bu süre dolarsa ya da bağlantı uzun süre koparsa masa boşalır ve o ana kadarki süren istatistiğine kaydedilir.</p>
<h3>Bildirimler gelmiyor</h3>
<p>Ayarlar › Bildirimler › PomoLive bölümünden izinleri kontrol et. Profil › Ayarlar'da "Arkadaşım çalışmaya başlayınca" seçeneğinin açık olduğundan emin ol.</p>
<h3>Birini bildirmek ya da engellemek</h3>
<p>Sohbette bir mesaja basılı tut ya da kişinin profilinde ••• menüsünü aç. Engellediğin kişileri Profil › Ayarlar › Engellenenler bölümünden yönetebilirsin.</p>
<h3>Hesabımı silmek</h3>
<p>Profil › Ayarlar › Hesabı Sil. Tüm verilerin kalıcı olarak silinir.</p>
<p>Başka bir sorun için: ${contact(email, 'tr')}.</p>

<hr>

<h2>English</h2>
<h3>Why was my desk freed?</h3>
<p>Your desk is kept for 45 minutes while the app is in the background. When that runs out, or the connection drops for a long time, the desk is freed and the time so far is saved to your stats.</p>
<h3>I don't get notifications</h3>
<p>Check Settings › Notifications › PomoLive, and make sure "When a friend starts focusing" is on in Profile › Settings.</p>
<h3>Reporting or blocking someone</h3>
<p>Long-press a chat message, or open the ••• menu on their profile. Manage the people you blocked in Profile › Settings › Blocked.</p>
<h3>Deleting my account</h3>
<p>Profile › Settings › Delete Account. All your data is removed permanently.</p>
<p>Anything else: ${contact(email, 'en')}.</p>
`,
  );
}
