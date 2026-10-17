import StoreKit
import SwiftUI

/// The PomoLive Plus sheet, built on StoreKit's own subscription view so prices, the free trial,
/// family sharing and restoring all follow Apple's conventions in every country.
struct PlusPaywall: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        SubscriptionStoreView(productIDs: PlusStore.productIds) {
            PlusMarketing()
        }
        .subscriptionStoreControlStyle(.prominentPicker)
        .subscriptionStoreButtonLabel(.multiline)
        .storeButton(.visible, for: .restorePurchases)
        .storeButton(.hidden, for: .cancellation)
        .subscriptionStorePolicyDestination(url: app.website.appending(path: "terms"), for: .termsOfService)
        .subscriptionStorePolicyDestination(url: app.website.appending(path: "privacy"), for: .privacyPolicy)
        .onInAppPurchaseCompletion { _, result in
            if case .success(.success) = result { dismiss() }
        }
        .tint(.accentColor)
        .overlay(alignment: .topLeading) {
            Button("Kapat", systemImage: "xmark", role: .close) { dismiss() }
                .labelStyle(.iconOnly)
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .padding(16)
        }
        .onChange(of: app.plus.isActive) { _, isActive in
            if isActive { dismiss() }
        }
    }
}

private struct PlusMarketing: View {
    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "sparkles")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(Color.accentColor.gradient)
                .symbolEffect(.bounce, options: .nonRepeating)
                .padding(.top, 36)
            VStack(spacing: 6) {
                Text("PomoLive Plus")
                    .font(.largeTitle.weight(.bold))
                Text("Kütüphaneni kendine göre kur, ilerlemeni yakından izle.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            VStack(alignment: .leading, spacing: 14) {
                feature("chart.bar.xaxis", .indigo, "Gelişmiş İstatistik", "Yıllık ısı haritası, aylık trendler, en verimli saatin ve CSV dışa aktarma.")
                feature("paintpalette.fill", .green, "Tüm Oda Temaları", "Orman, Sahil ve Uzay; 10 odaya kadar.")
                feature("person.crop.circle.badge.plus", .pink, "Plus Karakterleri", "Kedi, büyücü ve yeni karakterler.")
                feature("waveform", .teal, "Tüm Odak Sesleri", "Dalgalar, şömine ve pembe gürültü.")
                feature("moon.stars.fill", .orange, "Tam Odak Modu", "Halka ve kadran saatler, renkler ve gece haritası.")
            }
            .padding(.horizontal, 8)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    private func feature(_ symbol: String, _ color: Color, _ title: LocalizedStringKey, _ detail: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
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
