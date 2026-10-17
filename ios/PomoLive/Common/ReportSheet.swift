import SwiftUI

/// Reporting a reader, or one of their chat messages, with a reason, an optional note and the
/// choice to block them at the same time.
struct ReportSheet: View {
    let user: PublicUser
    var message: ChatMessage?

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var reason: ReportReason?
    @State private var note = ""
    @State private var alsoBlocks = false
    @State private var isSending = false
    @State private var isSent = false
    @State private var error: LibraryError?

    var body: some View {
        NavigationStack {
            Form {
                if let message {
                    Section("Bildirilen Mesaj") {
                        Text(message.body)
                            .foregroundStyle(.secondary)
                            .lineLimit(4)
                    }
                }

                Section {
                    ForEach(ReportReason.allCases) { option in
                        Button {
                            reason = option
                        } label: {
                            HStack {
                                Label(option.title, systemImage: option.symbol)
                                Spacer()
                                if reason == option {
                                    Image(systemName: "checkmark")
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.tint)
                                }
                            }
                            .contentShape(.rect)
                        }
                        .tint(.primary)
                        .accessibilityAddTraits(reason == option ? .isSelected : [])
                    }
                } header: {
                    Text("Neden bildiriyorsun?")
                } footer: {
                    if reason == .selfHarm {
                        Text("Biri şu an tehlikedeyse beklemeden 112'yi ara.")
                    }
                }

                Section {
                    TextField("Eklemek istediğin bir şey (isteğe bağlı)", text: $note, axis: .vertical)
                        .lineLimit(2...5)
                        .onChange(of: note) { _, text in
                            if text.count > 300 { note = String(text.prefix(300)) }
                        }
                } footer: {
                    Text("Raporun gizlidir, \(user.displayName) kimin bildirdiğini görmez. Raporları 24 saat içinde inceleriz.")
                }

                if !app.safety.isBlocked(user.id) {
                    Section {
                        Toggle("\(user.displayName) kişisini engelle", isOn: $alsoBlocks)
                    } footer: {
                        Text("Engellediğin kişinin mesajlarını görmezsin; seni takip edemez ve profilini açamaz.")
                    }
                }
            }
            .navigationTitle(message == nil ? "Kişiyi Bildir" : "Mesajı Bildir")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç", systemImage: "xmark", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSending {
                        ProgressView()
                    } else {
                        Button("Gönder", systemImage: "checkmark") { Task { await send() } }
                            .disabled(reason == nil)
                    }
                }
            }
            .interactiveDismissDisabled(isSending)
            .errorAlert($error)
            .alert("Teşekkürler", isPresented: $isSent) {
                Button("Tamam") { dismiss() }
            } message: {
                Text("Raporun bize ulaştı. Topluluğu güvenli tutmamıza yardım ettiğin için teşekkürler.")
            }
        }
    }

    private func send() async {
        guard let reason else { return }
        isSending = true
        defer { isSending = false }
        do {
            try await app.safety.report(user.id, reason: reason, note: note, messageId: message?.id)
            if alsoBlocks { try await app.block(user) }
            isSent = true
        } catch {
            self.error = LibraryError(error)
        }
    }
}

extension ReportReason {
    var title: LocalizedStringKey {
        switch self {
        case .spam: "Spam ya da reklam"
        case .harassment: "Taciz ya da zorbalık"
        case .hate: "Nefret söylemi"
        case .sexual: "Cinsel içerik"
        case .selfHarm: "Kendine zarar verme"
        case .other: "Başka bir şey"
        }
    }

    var symbol: String {
        switch self {
        case .spam: "megaphone"
        case .harassment: "hand.raised"
        case .hate: "exclamationmark.bubble"
        case .sexual: "eye.slash"
        case .selfHarm: "heart"
        case .other: "ellipsis.circle"
        }
    }
}

extension View {
    /// Asks before blocking someone, explaining what it does.
    func blockConfirmation(_ user: Binding<PublicUser?>, onBlock: @escaping (PublicUser) -> Void) -> some View {
        confirmationDialog(
            user.wrappedValue.map { String(localized: "\($0.displayName) engellensin mi?") } ?? "",
            isPresented: Binding(get: { user.wrappedValue != nil }, set: { if !$0 { user.wrappedValue = nil } }),
            titleVisibility: .visible,
            presenting: user.wrappedValue
        ) { person in
            Button("Engelle", role: .destructive) { onBlock(person) }
        } message: { _ in
            Text("Mesajlarını görmezsin, birbirinizi takip edemezsiniz ve profilini açamaz. Ona haber verilmez.")
        }
    }
}
