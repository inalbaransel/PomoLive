import SwiftUI

/// Welcome screen in the style of Apple's onboarding: a hero, three features, then the account actions.
struct SignInView: View {
    @Environment(AppModel.self) private var app
    @State private var accountMode: AccountSheet.Mode?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 36) {
                    hero
                    VStack(alignment: .leading, spacing: 24) {
                        feature(
                            "person.3.fill",
                            title: "Birlikte odaklan",
                            text: "Piksel bir kütüphanede masaya otur, diğer okurlarla aynı salonda çalış."
                        )
                        feature(
                            "timer",
                            title: "Pomodoro ya da kronometre",
                            text: "Hazır sürelerle başla ya da süreyi serbest tut; kilit ekranında takip et."
                        )
                        feature(
                            "chart.bar.fill",
                            title: "İlerlemeni gör",
                            text: "Günlük seri, haftalık süre ve kategorilere göre dağılım."
                        )
                    }
                    .padding(.horizontal, 8)
                }
                .padding(.horizontal, 24)
                .padding(.top, 48)
            }
            .scrollBounceBehavior(.basedOnSize)

            VStack(spacing: 12) {
                Button {
                    accountMode = .register
                } label: {
                    Text("Hesap Oluştur")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)

                Button("Zaten hesabım var") {
                    accountMode = .signIn
                }
                .buttonStyle(.borderless)
            }
            .controlSize(.extraLarge)
            .fontWeight(.semibold)
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        }
        .sheet(item: $accountMode) { mode in
            AccountSheet(mode: mode)
                .presentationDetents([.medium, .large])
        }
    }

    private var hero: some View {
        VStack(spacing: 16) {
            Image(decorative: SpriteCache.shared.desk(DeskSprite.Key(avatar: .scholar, phase: .focus, frame: 0)), scale: 1)
                .resizable()
                .interpolation(.none)
                .frame(width: 96, height: 96)
                .padding(14)
                .background(Color.accentColor.opacity(0.12), in: .rect(cornerRadius: 30))
            VStack(spacing: 8) {
                Text("PomoLive")
                    .font(.largeTitle.weight(.bold))
                Text("Sessiz bir kütüphane, her an açık.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
        .multilineTextAlignment(.center)
    }

    private func feature(_ symbol: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(Color.accentColor)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
