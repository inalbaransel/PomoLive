import AuthenticationServices
import SwiftUI

struct SignInView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.colorScheme) private var colorScheme
    @State private var nonce = AppleSignInNonce()

    var body: some View {
        @Bindable var app = app

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
                Text("SilentHall")
                    .font(.system(size: 46, weight: .black, design: .monospaced))
                Text("Piksel bir kütüphanede bir masaya otur,\nbaşkalarıyla birlikte sessizce odaklan.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if app.isSigningIn {
                ProgressView()
                    .controlSize(.large)
                    .frame(height: 52)
            } else {
                signInButtons
            }
        }
        .padding(24)
        .errorAlert($app.signInError)
    }

    private var signInButtons: some View {
        VStack(spacing: 12) {
            SignInWithAppleButton(.continue) { request in
                nonce = AppleSignInNonce()
                request.requestedScopes = [.fullName]
                request.nonce = nonce.hashed
            } onCompletion: { result in
                handle(result)
            }
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 52)
            .clipShape(.capsule)

            #if DEBUG
            Button("Geliştirici olarak devam et") {
                Task { await app.signIn(with: .developer(deviceId: DeveloperIdentity.deviceId, displayName: nil)) }
            }
            .buttonStyle(.glass)
            .controlSize(.large)
            #endif
        }
    }

    private func handle(_ result: Result<ASAuthorization, any Error>) {
        guard
            case .success(let authorization) = result,
            let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
            let tokenData = credential.identityToken
        else { return }

        let displayName = credential.fullName?.givenName
        let rawNonce = nonce.raw
        Task {
            await app.signIn(with: .apple(
                identityToken: String(decoding: tokenData, as: UTF8.self),
                rawNonce: rawNonce,
                displayName: displayName
            ))
        }
    }
}
