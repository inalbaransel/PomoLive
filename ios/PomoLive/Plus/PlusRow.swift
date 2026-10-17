import StoreKit
import SwiftUI

/// The Plus entry in Profile and Settings: an invitation without Plus, the renewal date and
/// Apple's subscription management with it.
struct PlusRow: View {
    @Environment(AppModel.self) private var app
    @State private var showsPaywall = false
    @State private var managesSubscription = false

    var body: some View {
        Button {
            if app.plus.isActive { managesSubscription = true } else { showsPaywall = true }
        } label: {
            HStack(spacing: 14) {
                PlusEmblem(size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.plus.isActive ? "PomoLive Plus" : "PomoLive Plus'a Geç")
                        .font(.headline)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if app.plus.isActive {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Color.accentColor)
                } else {
                    Image(systemName: "chevron.forward")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .plusPaywall(isPresented: $showsPaywall)
        .manageSubscriptionsSheet(isPresented: $managesSubscription)
    }

    private var subtitle: String {
        guard app.plus.isActive else { return String(localized: "Temalar, gelişmiş istatistik ve daha fazlası") }
        guard let expiresAt = app.plus.status.expiresAt else { return String(localized: "Aktif") }
        let date = Date(timeIntervalSince1970: Double(expiresAt) / 1000)
        return String(localized: "Yenilenme: \(date.formatted(.dateTime.day().month(.wide).year().locale(.app)))")
    }
}
