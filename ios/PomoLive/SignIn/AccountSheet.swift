import SwiftUI

/// E-mail and password sign-in or registration. Uses the system password AutoFill content types.
struct AccountSheet: View {
    enum Mode: String, Identifiable {
        case signIn, register
        var id: String { rawValue }
    }

    let mode: Mode

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var error: LibraryError?
    @FocusState private var focusedField: Field?

    private enum Field {
        case displayName, email, password
    }

    private static let minimumPasswordLength = 8

    private var trimmedEmail: String { email.trimmingCharacters(in: .whitespaces).lowercased() }
    private var trimmedName: String { displayName.trimmingCharacters(in: .whitespaces) }

    /// Mirrors the server's check; catches look-alikes such as a dotless `ı` typed on a Turkish keyboard.
    private var isEmailValid: Bool {
        trimmedEmail.wholeMatch(of: /[a-z0-9._%+\-]+@[a-z0-9\-]+(\.[a-z0-9\-]+)*\.[a-z]{2,}/) != nil
    }

    private var canSubmit: Bool {
        isEmailValid
            && password.count >= Self.minimumPasswordLength
            && (mode == .signIn || trimmedName.isEmpty || trimmedName.count >= 2)
    }

    var body: some View {
        NavigationStack {
            Form {
                if mode == .register {
                    Section {
                        TextField("Görünen ad (isteğe bağlı)", text: $displayName)
                            .textContentType(.nickname)
                            .focused($focusedField, equals: .displayName)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .email }
                            .onChange(of: displayName) { displayName = String(displayName.prefix(24)) }
                    } footer: {
                        Text("Salondaki diğer okurlar seni bu adla görür.")
                    }
                }

                Section {
                    TextField("E-posta", text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .email)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .password }

                    SecureField("Şifre", text: $password)
                        .textContentType(mode == .register ? .newPassword : .password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .password)
                        .submitLabel(.go)
                        .onSubmit(submit)
                } footer: {
                    if mode == .register {
                        Text("Şifren en az \(Self.minimumPasswordLength) karakter olmalı.")
                    }
                }
            }
            .navigationTitle(mode == .register ? "Hesap Oluştur" : "Giriş Yap")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç", systemImage: "xmark", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if app.isSigningIn {
                        ProgressView()
                    } else {
                        Button(mode == .register ? "Oluştur" : "Giriş Yap", systemImage: "checkmark", action: submit)
                            .disabled(!canSubmit)
                    }
                }
            }
            .errorAlert($error)
        }
        .onAppear { focusedField = mode == .register ? .displayName : .email }
    }

    private func submit() {
        guard canSubmit, !app.isSigningIn else { return }
        let credential: AuthenticateCommand.Credential = mode == .register
            ? .register(email: trimmedEmail, password: password, displayName: trimmedName.isEmpty ? nil : trimmedName)
            : .password(email: trimmedEmail, password: password)
        Task {
            do {
                try await app.signIn(with: credential)
                dismiss()
            } catch {
                self.error = LibraryError(error)
            }
        }
    }
}
