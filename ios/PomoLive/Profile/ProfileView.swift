import SwiftUI

/// The Profil tab: who you are, your categories, session defaults and account actions.
struct ProfileView: View {
    @Environment(AppModel.self) private var app
    @AppStorage(Preferences.defaultMode) private var modeRawValue = TimerMode.pomodoro.rawValue
    @AppStorage(Preferences.pomodoroFocusMinutes) private var focusMinutes = 25
    @AppStorage(Preferences.pomodoroBreakMinutes) private var breakMinutes = 5
    @AppStorage(Preferences.phaseNotifications) private var phaseNotifications = true
    @AppStorage(Preferences.haptics) private var haptics = true
    @State private var confirmsSignOut = false
    @State private var isDeletingAccount = false

    var body: some View {
        NavigationStack {
            Form {
                if let user = app.user {
                    Section {
                        NavigationLink {
                            ProfileEditor(user: user)
                        } label: {
                            HStack(spacing: 16) {
                                Image(decorative: SpriteCache.shared.avatar(AvatarSprite(id: user.avatarSpriteId)), scale: 1)
                                    .resizable()
                                    .interpolation(.none)
                                    .frame(width: 64, height: 64)
                                    .padding(6)
                                    .glassEffect(.regular.tint(.accentColor.opacity(0.25)), in: .rect(cornerRadius: 18))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(user.displayName)
                                        .font(.title2.weight(.bold))
                                    Text(AvatarSprite(id: user.avatarSpriteId).displayName)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }

                Section {
                    NavigationLink {
                        CategoriesView()
                    } label: {
                        LabeledContent {
                            Text("\(app.categories.custom.count)")
                        } label: {
                            Label("Kategorilerim", systemImage: "square.grid.2x2.fill")
                        }
                    }
                }

                Section {
                    Picker(selection: $modeRawValue) {
                        Text("Pomodoro").tag(TimerMode.pomodoro.rawValue)
                        Text("Kronometre").tag(TimerMode.stopwatch.rawValue)
                    } label: {
                        Label("Varsayılan mod", systemImage: "timer")
                    }
                    Stepper(value: $focusMinutes, in: 5...180, step: 5) {
                        LabeledContent("Odak süresi", value: "\(focusMinutes) dk")
                    }
                    Stepper(value: $breakMinutes, in: 1...60) {
                        LabeledContent("Mola süresi", value: "\(breakMinutes) dk")
                    }
                } header: {
                    Text("Oturum")
                } footer: {
                    Text("Masaya otururken bunlar hazır seçili gelir; her oturumda değiştirebilirsin.")
                }

                Section("Bildirimler ve Dokunuş") {
                    Toggle(isOn: $phaseNotifications) {
                        Label("Mola ve odak bildirimleri", systemImage: "bell.badge.fill")
                    }
                    Toggle(isOn: $haptics) {
                        Label("Titreşim", systemImage: "waveform")
                    }
                }
                .onChange(of: phaseNotifications) { app.seat.preferencesChanged() }

                Section {
                    Button("Çıkış Yap", role: .destructive) { confirmsSignOut = true }
                    Button("Hesabı Sil", role: .destructive) { isDeletingAccount = true }
                } footer: {
                    Text("Hesabını silmek oturum geçmişini, kategorilerini ve açtığın odaları kalıcı olarak siler.")
                }
            }
            .navigationTitle("Profil")
            .confirmationDialog("Çıkış yapılsın mı?", isPresented: $confirmsSignOut, titleVisibility: .visible) {
                Button("Çıkış Yap", role: .destructive) { Task { await app.signOut() } }
            } message: {
                Text("Masanda oturuyorsan oturumun bir süre daha açık kalır.")
            }
            .sheet(isPresented: $isDeletingAccount) {
                DeleteAccountSheet()
                    .presentationDetents([.medium])
            }
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
