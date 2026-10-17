import StoreKit
import SwiftUI

/// The PomoLive Plus sheet. It shows what Plus actually looks like (the themes, the characters,
/// the year map) rather than describing it, compares it with the free tier, and sells the two
/// plans with their real local prices, the monthly equivalent and the free trial spelled out.
struct PlusPaywall: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var selectedId = PlusStore.productIds[0]
    @State private var isPurchasing = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    PlusHero(layouts: app.rooms.themeLayouts)
                    plans
                    showcase
                    comparison
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .safeAreaBar(edge: .bottom) { purchaseBar }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Kapat", systemImage: "xmark", role: .close) { dismiss() }
                }
            }
            .alert("Satın alma tamamlanamadı", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("Tamam", role: .cancel) {}
            } message: {
                Text(error ?? "")
            }
        }
        .task { await app.plus.loadProducts() }
        .onChange(of: app.plus.isActive) { _, isActive in
            if isActive { dismiss() }
        }
        .sensoryFeedback(.success, trigger: app.plus.isActive)
    }

    // MARK: What Plus looks like

    private var showcase: some View {
        VStack(spacing: 12) {
            ShowcaseCard(title: "Tüm Oda Temaları", detail: "Orman, Sahil ve Uzay; 10 odaya kadar.") {
                HStack(spacing: 8) {
                    ForEach([RoomTheme.forest, .beach, .space]) { theme in
                        if let layout = app.rooms.themeLayouts[theme.rawValue] {
                            RoomPreview(layout: layout, occupants: [])
                                .clipShape(.rect(cornerRadius: 8))
                        }
                    }
                }
            }
            ShowcaseCard(title: "Plus Karakterleri", detail: "Kedi, büyücü ve yeni karakterler.") {
                HStack(spacing: 6) {
                    ForEach(AvatarSprite.allCases.filter(PlusCatalog.avatars.contains)) { sprite in
                        Image(decorative: SpriteCache.shared.avatar(sprite), scale: 1)
                            .resizable()
                            .interpolation(.none)
                            .aspectRatio(1, contentMode: .fit)
                            .padding(4)
                            .background(.fill.tertiary, in: .rect(cornerRadius: 8))
                    }
                }
            }
            ShowcaseCard(title: "Gelişmiş İstatistik", detail: "Yıllık ısı haritası, aylık trendler, en verimli saatin ve CSV dışa aktarma.") {
                SampleHeatmap()
            }
            ShowcaseCard(title: "Sesler ve Odak Modu", detail: "Dalgalar, şömine ve pembe gürültü; halka ve kadran saatler, renkler ve gece haritası.") {
                HStack(spacing: 8) {
                    ForEach(AmbientSound.allCases.filter(PlusCatalog.sounds.contains)) { sound in
                        Label(sound.title, systemImage: sound.symbol)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(sound.color)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(sound.color.opacity(0.14), in: .capsule)
                    }
                }
            }
        }
    }

    // MARK: Free vs Plus

    private var comparison: some View {
        let themes = RoomTheme.allCases.count
        let avatars = AvatarSprite.allCases.count
        let sounds = AmbientSound.allCases.count
        let faces = ClockFace.allCases.count
        return VStack(spacing: 0) {
            HStack {
                Text("Karşılaştır")
                    .font(.headline)
                Spacer()
                Text("Ücretsiz")
                    .frame(width: 72)
                Text("Plus")
                    .frame(width: 72)
                    .foregroundStyle(Color.accentColor)
            }
            .font(.subheadline.weight(.semibold))
            .padding(.vertical, 12)
            Divider()
            row("Kendi odaların", free: "\(PlusCatalog.freeRoomLimit)", plus: "10")
            row("Oda temaları", free: "\(themes - PlusCatalog.themes.count)", plus: "\(themes)")
            row("Karakterler", free: "\(avatars - PlusCatalog.avatars.count)", plus: "\(avatars)")
            row("Odak sesleri", free: "\(sounds - PlusCatalog.sounds.count)", plus: "\(sounds)")
            row("Saat yüzleri", free: "1", plus: "\(faces)")
            row("İstatistik geçmişi", free: String(localized: "7 gün"), plus: String(localized: "1 yıl"))
            row("CSV dışa aktarma", free: nil, plus: "✓", isLast: true)
        }
        .padding(.horizontal, 16)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20))
    }

    private func row(_ title: LocalizedStringKey, free: String?, plus: String, isLast: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.subheadline)
                Spacer()
                Group {
                    if let free {
                        Text(verbatim: free)
                    } else {
                        Image(systemName: "minus")
                    }
                }
                .foregroundStyle(.secondary)
                .frame(width: 72)
                Text(verbatim: plus)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 72)
            }
            .font(.subheadline)
            .monospacedDigit()
            .padding(.vertical, 11)
            if !isLast { Divider() }
        }
    }

    // MARK: Plans

    @ViewBuilder
    private var plans: some View {
        let products = app.plus.products
        if products.isEmpty {
            VStack(spacing: 10) {
                if app.plus.productsFailed {
                    Label("App Store'a ulaşılamadı", systemImage: "wifi.exclamationmark")
                        .font(.subheadline.weight(.medium))
                    Button("Tekrar Dene") { Task { await app.plus.loadProducts() } }
                        .buttonStyle(.bordered)
                } else {
                    ProgressView()
                }
            }
            .frame(maxWidth: .infinity, minHeight: 140)
        } else {
            let monthly = products.first { $0.subscription?.subscriptionPeriod.unit == .month }
            VStack(spacing: 12) {
                ForEach(products) { product in
                    PlanCard(
                        product: product,
                        monthly: monthly,
                        isSelected: product.id == selectedId,
                        showsTrial: app.plus.isEligibleForTrial
                    )
                    .onTapGesture { withAnimation(.snappy) { selectedId = product.id } }
                }
            }
            .sensoryFeedback(.selection, trigger: selectedId)
        }
    }

    // MARK: Buying

    private var selected: Product? {
        app.plus.products.first { $0.id == selectedId }
    }

    private var purchaseBar: some View {
        VStack(spacing: 10) {
            Button {
                Task { await purchase() }
            } label: {
                Group {
                    if isPurchasing {
                        ProgressView()
                    } else {
                        Text(callToAction)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.extraLarge)
            .fontWeight(.semibold)
            .disabled(selected == nil || isPurchasing)

            if let selected {
                Text(renewalNote(for: selected))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 16) {
                Button("Geri Yükle") { Task { try? await app.plus.restore() } }
                Link("Kullanım Şartları", destination: app.website.appending(path: "terms"))
                Link("Gizlilik", destination: app.website.appending(path: "privacy"))
            }
            .font(.caption.weight(.medium))
            .tint(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    private var callToAction: String {
        guard let selected else { return String(localized: "Devam Et") }
        if let days = selected.freeTrialDays, app.plus.isEligibleForTrial {
            return String(localized: "\(days) Gün Ücretsiz Başla")
        }
        return String(localized: "Abone Ol · \(selected.pricePerPeriod)")
    }

    private func renewalNote(for product: Product) -> String {
        let renewal = String(localized: "Dönem bitmeden en az 24 saat önce iptal etmezsen otomatik yenilenir. Apple Hesabı ayarlarından istediğin zaman yönetebilirsin.")
        if let days = product.freeTrialDays, app.plus.isEligibleForTrial {
            return String(localized: "\(days) gün ücretsiz, sonra \(product.pricePerPeriod).") + " " + renewal
        }
        return renewal
    }

    private func purchase() async {
        guard let selected else { return }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            _ = try await app.plus.purchase(selected)
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - Pieces

/// The three Plus room looks, cross-fading one after another, above the name.
private struct PlusHero: View {
    let layouts: [String: LibraryLayout]

    private static let themes: [RoomTheme] = [.forest, .beach, .space]

    var body: some View {
        VStack(spacing: 16) {
            TimelineView(.periodic(from: .now, by: 3)) { context in
                let index = Int(context.date.timeIntervalSinceReferenceDate / 3) % Self.themes.count
                let theme = Self.themes[index]
                ZStack {
                    if let layout = layouts[theme.rawValue] {
                        RoomPreview(layout: layout, occupants: [])
                            .id(theme)
                            .transition(.opacity)
                    } else {
                        Color(.secondarySystemGroupedBackground)
                            .aspectRatio(18 / 8, contentMode: .fit)
                    }
                }
                .clipShape(.rect(cornerRadius: 22))
                .animation(.easeInOut(duration: 0.8), value: theme)
            }

            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    PlusEmblem(size: 38)
                    Text("PomoLive Plus")
                        .font(.largeTitle.weight(.bold))
                }
                Text("Kütüphaneni kendine göre kur, ilerlemeni yakından izle.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 8)
    }
}

/// One Plus feature with a real look at it.
private struct ShowcaseCard<Visual: View>: View {
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    @ViewBuilder let visual: Visual

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            visual
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20))
    }
}

/// A made-up but believable year of focus, so the heat map can be seen before buying.
private struct SampleHeatmap: View {
    var body: some View {
        Canvas { context, size in
            let columns = 26
            let gap: CGFloat = 2
            let cell = (size.width - gap * CGFloat(columns - 1)) / CGFloat(columns)
            for column in 0..<columns {
                for row in 0..<7 {
                    let seed = (column * 7 + row) * 2_654_435_761 % 97
                    let level = row >= 5 ? Double(seed % 3) / 6 : Double(seed % 5) / 4
                    let rect = CGRect(x: CGFloat(column) * (cell + gap), y: CGFloat(row) * (cell + gap), width: cell, height: cell)
                    context.fill(
                        Path(roundedRect: rect, cornerRadius: cell * 0.25),
                        with: .color(level == 0 ? Color.secondary.opacity(0.15) : Color.accentColor.opacity(0.25 + 0.75 * level))
                    )
                }
            }
        }
        .aspectRatio(26 / 7, contentMode: .fit)
        .accessibilityLabel("Örnek odak haritası")
    }
}

/// A plan with its local price, what it costs per month and, for the yearly one, the saving.
private struct PlanCard: View {
    let product: Product
    let monthly: Product?
    let isSelected: Bool
    let showsTrial: Bool

    private var isYearly: Bool { product.subscription?.subscriptionPeriod.unit == .year }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary.opacity(0.5))
                .contentTransition(.symbolEffect(.replace))
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(isYearly ? "Yıllık" : "Aylık")
                        .font(.headline)
                    if isYearly {
                        Text("EN AVANTAJLI")
                            .font(.caption2.weight(.heavy))
                            .tracking(0.4)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.accentColor, in: .capsule)
                    }
                }
                if isYearly {
                    Text("Ayda \(product.monthlyEquivalent)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let days = product.freeTrialDays, showsTrial {
                        Label("\(days) gün ücretsiz dene", systemImage: "gift.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.green)
                    }
                } else {
                    Text("İstediğin zaman iptal et")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 4) {
                Text(product.displayPrice)
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                Text(isYearly ? "yıllık" : "aylık")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if isYearly, let saving = saving {
                    Text("%\(saving) tasarruf")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2)
        }
        .contentShape(.rect(cornerRadius: 20))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }

    /// How much cheaper a year is than twelve months, in whole percent.
    private var saving: Int? {
        guard let monthly, monthly.price > 0 else { return nil }
        let twelveMonths = monthly.price * 12
        let percent = (1 - product.price / twelveMonths) * 100
        let value = Int(NSDecimalNumber(decimal: percent).doubleValue.rounded())
        return value > 0 ? value : nil
    }
}

private extension Product {
    /// "₺299,99/yıl" or "₺39,99/ay".
    var pricePerPeriod: String {
        subscription?.subscriptionPeriod.unit == .year
            ? String(localized: "\(displayPrice)/yıl")
            : String(localized: "\(displayPrice)/ay")
    }

    /// A yearly price spread over twelve months, in the store's currency.
    var monthlyEquivalent: String {
        (price / 12).formatted(priceFormatStyle)
    }

    var freeTrialDays: Int? {
        guard let offer = subscription?.introductoryOffer, offer.paymentMode == .freeTrial else { return nil }
        let value = offer.period.value
        switch offer.period.unit {
        case .day: return value
        case .week: return value * 7
        case .month: return value * 30
        case .year: return value * 365
        @unknown default: return nil
        }
    }
}

/// A small "PLUS" tag for locked choices.
struct PlusBadge: View {
    var body: some View {
        Text("PLUS")
            .font(.caption2.weight(.heavy))
            .tracking(0.5)
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.accentColor.gradient, in: .capsule)
            .accessibilityLabel("Plus gerekli")
    }
}

extension View {
    /// Presents the Plus sheet while `isPresented` is true.
    func plusPaywall(isPresented: Binding<Bool>) -> some View {
        sheet(isPresented: isPresented) {
            PlusPaywall()
        }
    }
}
