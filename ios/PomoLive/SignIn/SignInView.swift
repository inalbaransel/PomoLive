import AuthenticationServices
import SwiftUI

struct SignInView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.webAuthenticationSession) private var webAuthenticationSession
    @State private var appleNonce = SignInNonce()
    @State private var isEmailSheetPresented = false
    @State private var error: LibraryError?

    private let google = GoogleSignIn()

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

            if app.isSigningIn {
                ProgressView()
                    .controlSize(.large)
                    .frame(height: 52)
            } else {
                signInButtons
            }
        }
        .padding(24)
        .sheet(isPresented: $isEmailSheetPresented) {
            EmailSignInSheet()
                .presentationDetents([.medium])
        }
        .errorAlert($error)
    }

    private var signInButtons: some View {
        VStack(spacing: 12) {
            SignInWithAppleButton(.continue) { request in
                appleNonce = SignInNonce()
                request.requestedScopes = [.fullName, .email]
                request.nonce = appleNonce.hashed
            } onCompletion: { result in
                handleApple(result)
            }
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 52)
            .clipShape(.capsule)

            if let google {
                Button {
                    signInWithGoogle(google)
                } label: {
                    Label("Google ile devam et", systemImage: "g.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
            }

            Button {
                isEmailSheetPresented = true
            } label: {
                Label("E-posta ile devam et", systemImage: "envelope.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
        }
        .controlSize(.extraLarge)
    }

    private func handleApple(_ result: Result<ASAuthorization, any Error>) {
        guard
            case .success(let authorization) = result,
            let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
            let tokenData = credential.identityToken
        else { return }

        let credentialToSend = AuthenticateCommand.Credential.apple(
            identityToken: String(decoding: tokenData, as: UTF8.self),
            rawNonce: appleNonce.raw,
            displayName: credential.fullName?.givenName
        )
        Task { await signIn(with: credentialToSend) }
    }

    private func signInWithGoogle(_ google: GoogleSignIn) {
        Task {
            let nonce = SignInNonce()
            do {
                let token = try await google.identityToken(using: webAuthenticationSession, nonce: nonce)
                await signIn(with: .google(identityToken: token, rawNonce: nonce.raw))
            } catch ASWebAuthenticationSessionError.canceledLogin {
                return
            } catch {
                self.error = .server(code: "UNAVAILABLE", message: "")
            }
        }
    }

    private func signIn(with credential: AuthenticateCommand.Credential) async {
        do {
            try await app.signIn(with: credential)
        } catch {
            self.error = error as? LibraryError ?? .offline
        }
    }
}
