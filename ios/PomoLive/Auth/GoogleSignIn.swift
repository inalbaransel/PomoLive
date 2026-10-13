import AuthenticationServices
import CryptoKit
import Foundation
import SwiftUI

/// Sign in with Google without an SDK: OAuth 2.0 authorization code + PKCE in a system
/// `WebAuthenticationSession`, as Google recommends for native apps. Yields an OpenID ID token.
struct GoogleSignIn {
    enum Failure: Error {
        case invalidCallback, stateMismatch, tokenExchangeFailed
    }

    private let clientId: String

    /// `nil` when no iOS OAuth client is configured (`GOOGLE_IOS_CLIENT_ID` in `project.yml`).
    init?() {
        guard
            let clientId = Bundle.main.object(forInfoDictionaryKey: "GoogleClientID") as? String,
            clientId.hasSuffix(".apps.googleusercontent.com")
        else { return nil }
        self.clientId = clientId
    }

    /// Google's iOS clients redirect to the reversed client ID scheme.
    private var callbackScheme: String {
        "com.googleusercontent.apps." + clientId.replacingOccurrences(of: ".apps.googleusercontent.com", with: "")
    }

    private var redirectURI: String { "\(callbackScheme):/oauth2redirect" }

    @MainActor
    func identityToken(
        using session: WebAuthenticationSession,
        nonce: SignInNonce
    ) async throws -> String {
        let verifier = SignInNonce.randomHex(byteCount: 32)
        let state = SignInNonce.randomHex(byteCount: 16)

        var authorization = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        authorization.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "openid email profile"),
            URLQueryItem(name: "code_challenge", value: Self.base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "nonce", value: nonce.hashed),
            URLQueryItem(name: "prompt", value: "select_account"),
        ]

        let callback = try await session.authenticate(
            using: authorization.url!,
            callback: .customScheme(callbackScheme),
            additionalHeaderFields: [:]
        )
        let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
        guard items.first(where: { $0.name == "state" })?.value == state else { throw Failure.stateMismatch }
        guard let code = items.first(where: { $0.name == "code" })?.value else { throw Failure.invalidCallback }
        return try await exchange(code: code, verifier: verifier)
    }

    private func exchange(code: String, verifier: String) async throws -> String {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var form = URLComponents()
        form.queryItems = [
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "code_verifier", value: verifier),
        ]
        request.httpBody = Data((form.percentEncodedQuery ?? "").utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard
            (response as? HTTPURLResponse)?.statusCode == 200,
            let token = try? JSONDecoder().decode(TokenResponse.self, from: data)
        else { throw Failure.tokenExchangeFailed }
        return token.idToken
    }

    private struct TokenResponse: Decodable {
        let idToken: String

        enum CodingKeys: String, CodingKey { case idToken = "id_token" }
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
