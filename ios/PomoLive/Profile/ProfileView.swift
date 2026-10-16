import SwiftUI

/// The Profil tab: who you are, your categories, privacy, session defaults and account actions.
struct ProfileView: View {
    @Environment(AppModel.self) private var app
    @AppStorage(Preferences.defaultMode) private var modeRawValue = TimerMode.pomodoro.rawValue
    @AppStorage(Preferences.pomodoroFocusMinutes) private var focusMinutes = 25
    @AppStorage(Preferences.pomodoroBreakMinutes) private var breakMinutes = 5
    @AppStorage(Preferences.phaseNotifications) private var phaseNotifications = true
    @AppStorage(Preferences.haptics) private var haptics = true
    @AppStorage(Preferences.appearance) private var appearance = Appearance.system
    @Environment(\.openURL) private var openURL
    @State private var confirmsSignOut = false
    @State private var isDeletingAccount = false

    private static let focusOptions = [15, 20, 25, 30, 45, 50, 60, 90, 120]
    private static let breakOptions = [3, 5, 10, 15, 20, 30]

    var body: some View {
        NavigationStack {
            Form {
                if let user = app.user {
                    Section {
                        NavigationLink {
                            ProfileEditor(user: user)
                        } label: {
                            HStack(spacing: 14) {
                                Image(decorative: SpriteCache.shared.avatar(AvatarSprite(id: user.avatarSpriteId)), scale: 1)
                                    .resizable()
                                    .interpolation(.none)
                                    .frame(width: 44, height: 44)
                                    .frame(width: 60, height: 60)
                                    .background(.fill.tertiary, in: .circle)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(user.displayName)
                                        .font(.title3.weight(.semibold))
                                    Text(verbatim: "@\(user.username)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    if let bio = user.bio {
                                        Text(bio)
                                            .font(.subheadline)
                                            .lineLimit(2)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        NavigationLink {
                            UserProfileView(userId: user.id)
                        } label: {
                            SettingsLabel(title: "Profilimi Gör", systemName: "person.crop.circle.fill", color: .indigo)
                        }
                    }

                    GoalsSection(user: user)
                    PrivacySection(user: user)
                }

                Section {
                    NavigationLink {
                        TasksView()
                    } label: {
                        LabeledContent {
                            Text("\(app.tasks.openTasks.count)")
                        } label: {
                            SettingsLabel(title: "Görevlerim", systemName: "checklist", color: .orange)
                        }
                    }
                    NavigationLink {
                        CategoriesView()
                    } label: {
                        LabeledContent {
                            Text("\(app.categories.custom.count)")
                        } label: {
                            SettingsLabel(title: "Kategorilerim", systemName: "square.grid.2x2.fill", color: .indigo)
                        }
                    }
                }

                Section {
                    Picker(selection: $modeRawValue) {
                        Text("Pomodoro").tag(TimerMode.pomodoro.rawValue)
                        Text("Kronometre").tag(TimerMode.stopwatch.rawValue)
                    } label: {
                        SettingsLabel(title: "Varsayılan Mod", systemName: "timer", color: .orange)
                    }
                    Picker(selection: $focusMinutes) {
                        ForEach(Self.options(Self.focusOptions, including: focusMinutes), id: \.self) { Text("\($0) dk").tag($0) }
                    } label: {
                        SettingsLabel(title: "Odak Süresi", systemName: "brain.head.profile.fill", color: .blue)
                    }
                    Picker(selection: $breakMinutes) {
                        ForEach(Self.options(Self.breakOptions, including: breakMinutes), id: \.self) { Text("\($0) dk").tag($0) }
                    } label: {
                        SettingsLabel(title: "Mola Süresi", systemName: "cup.and.saucer.fill", color: .brown)
                    }
                } header: {
                    Text("Oturum")
                } footer: {
                    Text("Masaya otururken bunlar hazır seçili gelir; her oturumda değiştirebilirsin.")
                }

                Section {
                    Picker(selection: $appearance) {
                        ForEach(Appearance.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    } label: {
                        SettingsLabel(title: "Görünüm", systemName: "circle.lefthalf.filled", color: .gray)
                    }
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    } label: {
                        LabeledContent {
                            Text(currentLanguageName)
                        } label: {
                            SettingsLabel(title: "Dil", systemName: "globe", color: .blue)
                        }
                    }
                    .tint(.primary)
                } header: {
                    Text("Görünüm ve Dil")
                } footer: {
                    Text("Dil, iPhone Ayarlar'ında PomoLive için seçilir.")
                }

                Section("Bildirimler") {
                    Toggle(isOn: $phaseNotifications) {
                        SettingsLabel(title: "Mola ve Odak Hatırlatmaları", systemName: "bell.badge.fill", color: .red)
                    }
                    Toggle(isOn: $haptics) {
                        SettingsLabel(title: "Titreşim", systemName: "iphone.radiowaves.left.and.right", color: .pink)
                    }
                }
                .onChange(of: phaseNotifications) { app.seat.preferencesChanged() }

                Section {
                    Button("Çıkış Yap", role: .destructive) { confirmsSignOut = true }
                        .frame(maxWidth: .infinity)
                }

                Section {
                    Button("Hesabı Sil", role: .destructive) { isDeletingAccount = true }
                        .frame(maxWidth: .infinity)
                } footer: {
                    Text("Oturum geçmişin, kategorilerin ve açtığın odalar kalıcı olarak silinir.")
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

extension ProfileView {
    /// "Türkçe" / "English": the language the app is actually running in.
    fileprivate var currentLanguageName: String {
        let code = Bundle.main.preferredLocalizations.first ?? "tr"
        return Locale(identifier: code).localizedString(forLanguageCode: code)?.localizedCapitalized ?? code
    }

    /// Preset choices plus the current value, so a custom duration picked elsewhere still shows.
    fileprivate static func options(_ presets: [Int], including value: Int) -> [Int] {
        Array(Set(presets + [value])).sorted()
    }
}

/// Daily and weekly focus goals, saved on the server so they follow the reader across devices.
private struct GoalsSection: View {
    let user: UserProfile

    @Environment(AppModel.self) private var app
    @State private var error: LibraryError?

    private static let dailyOptions = [0, 30, 60, 90, 120, 180, 240, 300, 360, 480]
    private static let weeklyOptions = [0, 180, 300, 600, 900, 1200, 1500, 1800, 2400]

    var body: some View {
        Section {
            Picker(selection: binding(\.dailyGoalMinutes, save: { UpdateProfileCommand(dailyGoalMinutes: $0) })) {
                ForEach(Self.dailyOptions, id: \.self) { Text(Self.label($0)).tag($0) }
            } label: {
                SettingsLabel(title: "Günlük Hedef", systemName: "target", color: .indigo)
            }
            Picker(selection: binding(\.weeklyGoalMinutes, save: { UpdateProfileCommand(weeklyGoalMinutes: $0) })) {
                ForEach(Self.weeklyOptions, id: \.self) { Text(Self.label($0)).tag($0) }
            } label: {
                SettingsLabel(title: "Haftalık Hedef", systemName: "calendar", color: .green)
            }
        } header: {
            Text("Hedefler")
        } footer: {
            Text("İstatistik'te halkalar hedefe ne kadar yaklaştığını gösterir.")
        }
        .errorAlert($error)
    }

    private static func label(_ minutes: Int) -> String {
        minutes == 0 ? String(localized: "Yok") : formattedFocus(Int64(minutes) * 60_000)
    }

    private func binding(_ keyPath: KeyPath<UserProfile, Int?>, save: @escaping (Int) -> UpdateProfileCommand) -> Binding<Int> {
        Binding(
            get: { user[keyPath: keyPath] ?? 0 },
            set: { minutes in
                Task {
                    do { try await app.updateProfile(save(minutes)) } catch { self.error = LibraryError(error) }
                }
            }
        )
    }
}

/// Whether other readers see this reader's focus time, saved on the server.
private struct PrivacySection: View {
    let user: UserProfile

    @Environment(AppModel.self) private var app
    @State private var statsVisible: Bool
    @State private var error: LibraryError?

    init(user: UserProfile) {
        self.user = user
        _statsVisible = State(initialValue: user.statsVisible)
    }

    var body: some View {
        Section {
            Toggle(isOn: $statsVisible) {
                SettingsLabel(title: "Odak Sürelerimi Göster", systemName: "chart.bar.fill", color: .green)
            }
        } header: {
            Text("Gizlilik")
        } footer: {
            Text(statsVisible
                ? "Odadaki kişiler ve profiline bakanlar haftalık süreni, serini ve kategorilerini görebilir."
                : "Süren ve istatistiklerin yalnızca sende görünür. Adın ve karakterin yine görünür.")
        }
        .onChange(of: statsVisible) { _, isVisible in
            guard isVisible != user.statsVisible else { return }
            Task {
                do {
                    try await app.updateProfile(UpdateProfileCommand(statsVisible: isVisible))
                } catch {
                    statsVisible = user.statsVisible
                    self.error = LibraryError(error)
                }
            }
        }
        .onChange(of: user.statsVisible) { _, saved in statsVisible = saved }
        .errorAlert($error)
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
