import SwiftUI

/// The account itself, kept away from everyday settings: editing the profile, signing out and,
/// at the very bottom, deleting the account.
struct AccountView: View {
    @Environment(AppModel.self) private var app
    @State private var confirmsSignOut = false
    @State private var isDeletingAccount = false

    var body: some View {
        Form {
            if let user = app.user {
                Section {
                    LabeledContent("Kullanıcı Adı") {
                        Text(verbatim: "@\(user.username)")
                    }
                    NavigationLink("Profili Düzenle") { ProfileEditor(user: user) }
                }
            }

            Section {
                Button("Çıkış Yap") { confirmsSignOut = true }
            } footer: {
                Text("Masanda oturuyorsan oturumun bir süre daha açık kalır.")
            }

            Section {
                Button("Hesabı Sil", role: .destructive) { isDeletingAccount = true }
            } footer: {
                Text("Oturum geçmişin, kategorilerin, mesajların ve açtığın odalar kalıcı olarak silinir. Bu işlem geri alınamaz.")
            }
        }
        .navigationTitle("Hesap")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Çıkış yapılsın mı?", isPresented: $confirmsSignOut, titleVisibility: .visible) {
            Button("Çıkış Yap", role: .destructive) { Task { await app.signOut() } }
        }
        .sheet(isPresented: $isDeletingAccount) {
            DeleteAccountSheet()
                .presentationDetents([.medium])
        }
    }
}

/// Re-asks for the password before permanently deleting the account.
private struct DeleteAccountSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var password = ""
    @State private var isDeleting = false
    @State private var error: LibraryError?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Şifren", text: $password)
                        .textContentType(.password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } footer: {
                    Text("Bu işlem geri alınamaz. Devam etmek için şifreni gir.")
                }
            }
            .navigationTitle("Hesabı Sil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç", systemImage: "xmark", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .destructiveAction) {
                    if isDeleting {
                        ProgressView()
                    } else {
                        Button("Sil", systemImage: "trash", role: .destructive, action: delete)
                            .disabled(password.count < 8)
                    }
                }
            }
            .errorAlert($error)
        }
    }

    private func delete() {
        isDeleting = true
        Task {
            defer { isDeleting = false }
            do {
                try await app.deleteAccount(password: password)
            } catch {
                self.error = LibraryError(error)
            }
        }
    }
}
