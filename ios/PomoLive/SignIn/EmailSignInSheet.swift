import SwiftUI

/// Passwordless e-mail sign-in: enter the address, then the 6-digit code the server mails.
struct EmailSignInSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var code = ""
    @State private var isCodeSent = false
    @State private var isWorking = false
    @State private var resendAvailableAt = Date.distantPast
    @State private var error: LibraryError?
    @FocusState private var focusedField: Field?

    private enum Field {
        case email, code
    }

    private var trimmedEmail: String { email.trimmingCharacters(in: .whitespaces).lowercased() }
    /// Mirrors the server's check; catches look-alikes such as a dotless `ı` typed on a Turkish keyboard.
    private var isEmailValid: Bool {
        trimmedEmail.wholeMatch(of: /[a-z0-9._%+\-]+@[a-z0-9\-]+(\.[a-z0-9\-]+)*\.[a-z]{2,}/) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("ornek@posta.com", text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .email)
                        .submitLabel(.send)
                        .onSubmit(sendCode)
                        .disabled(isCodeSent)
                } footer: {
                    Text("Şifre yok: bu adrese 6 haneli bir giriş kodu göndereceğiz.")
                }

                if isCodeSent {
                    Section {
                        TextField("6 haneli kod", text: $code)
                            .font(.system(.title2, design: .monospaced, weight: .semibold))
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                            .focused($focusedField, equals: .code)
                            .onChange(of: code) { _, newValue in
                                let digits = String(newValue.filter(\.isNumber).prefix(6))
                                if digits != newValue {
                                    code = digits
                                } else if digits.count == 6 {
                                    verify()
                                }
                            }
                    } footer: {
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            let remaining = Int(resendAvailableAt.timeIntervalSince(context.date).rounded(.up))
                            HStack {
                                Text("Kod \(trimmedEmail) adresine gitti.")
                                Spacer()
                                if remaining > 0 {
                                    Text("\(remaining) sn").monospacedDigit()
                                } else {
                                    Button("Tekrar gönder", action: sendCode)
                                        .font(.footnote.weight(.semibold))
                                }
                            }
                        }
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.spring(duration: 0.4), value: isCodeSent)
            .navigationTitle("E-posta ile Giriş")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç", systemImage: "xmark", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isWorking {
                        ProgressView()
                    } else if isCodeSent {
                        Button("Giriş Yap", systemImage: "checkmark", action: verify)
                            .disabled(code.count != 6)
                    } else {
                        Button("Kod Gönder", systemImage: "paperplane.fill", action: sendCode)
                            .disabled(!isEmailValid)
                    }
                }
            }
            .errorAlert($error)
        }
        .onAppear { focusedField = .email }
    }

    private func sendCode() {
        guard isEmailValid, !isWorking else { return }
        run {
            let cooldown = try await app.requestEmailCode(for: trimmedEmail)
            resendAvailableAt = .now.addingTimeInterval(TimeInterval(cooldown))
            isCodeSent = true
            focusedField = .code
        }
    }

    private func verify() {
        guard code.count == 6, !isWorking else { return }
        run {
            try await app.signIn(with: .email(address: trimmedEmail, code: code))
            dismiss()
        } onFailure: {
            code = ""
        }
    }

    private func run(_ operation: @escaping () async throws -> Void, onFailure: @escaping () -> Void = {}) {
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                try await operation()
            } catch {
                self.error = error as? LibraryError ?? .offline
                onFailure()
            }
        }
    }
}
