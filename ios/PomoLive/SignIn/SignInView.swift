import SwiftUI

struct SignInView: View {
    @Environment(AppModel.self) private var app
    @State private var accountMode: AccountSheet.Mode?

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            HStack(spacing: 4) {
                ForEach(AvatarSprite.allCases) { sprite in
                    Image(decorative: SpriteCache.shared.avatar(sprite), scale: 1)
                        .resizable()
                        .interpolation(.none)
                        .frame(width: 52, height: 52)
                }
            }
            .accessibilityHidden(true)

            VStack(spacing: 12) {
                Text("PomoLive")
                    .font(.system(size: 46, weight: .black, design: .monospaced))
                Text("Piksel bir kütüphanede bir masaya otur,\nbaşkalarıyla birlikte sessizce odaklan.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(spacing: 12) {
                Button {
                    accountMode = .signIn
                } label: {
                    Text("Giriş Yap")
                        .frame(maxWidth: .infinity)
                        // White on the lamp-gold accent fails contrast; dark text reads in both themes.
                        .foregroundStyle(.black)
                }
                .buttonStyle(.glassProminent)

                Button {
                    accountMode = .register
                } label: {
                    Text("Hesap Oluştur")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
            }
            .controlSize(.extraLarge)
        }
        .padding(24)
        .sheet(item: $accountMode) { mode in
            AccountSheet(mode: mode)
                .presentationDetents([.medium, .large])
        }
    }
}
