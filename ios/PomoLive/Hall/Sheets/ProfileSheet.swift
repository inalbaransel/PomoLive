import SwiftUI

/// Name and pixel character shown to other readers.
struct ProfileSheet: View {
    let user: UserProfile
    let onSave: (String?, AvatarSprite?) async throws -> Void
    let onSignOut: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var displayName: String
    @State private var avatar: AvatarSprite
    @State private var isSaving = false
    @State private var saveError: LibraryError?
    @State private var confirmsSignOut = false

    init(user: UserProfile, onSave: @escaping (String?, AvatarSprite?) async throws -> Void, onSignOut: @escaping () async -> Void) {
        self.user = user
        self.onSave = onSave
        self.onSignOut = onSignOut
        _displayName = State(initialValue: user.displayName)
        _avatar = State(initialValue: AvatarSprite(id: user.avatarSpriteId))
    }

    private var trimmedName: String { displayName.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var hasChanges: Bool { trimmedName != user.displayName || avatar.rawValue != user.avatarSpriteId }

    var body: some View {
        NavigationStack {
            Form {
                Section("Karakter") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
                        ForEach(AvatarSprite.allCases) { sprite in
                            Button { avatar = sprite } label: {
                                VStack(spacing: 6) {
                                    Image(decorative: SpriteCache.shared.avatar(sprite), scale: 1)
                                        .resizable()
                                        .interpolation(.none)
                                        .frame(width: 56, height: 56)
                                    Text(sprite.displayName)
                                        .font(.caption)
                                        .foregroundStyle(avatar == sprite ? .primary : .secondary)
                                }
                                .padding(8)
                                .frame(maxWidth: .infinity)
                                .glassEffect(avatar == sprite ? .regular.tint(.accentColor.opacity(0.5)) : .identity, in: .rect(cornerRadius: 16))
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(avatar == sprite ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 8)
                    .animation(.spring(duration: 0.35), value: avatar)
                }

                Section("Görünen ad") {
                    TextField("Adın", text: $displayName)
                        .textContentType(.nickname)
                        .onChange(of: displayName) { displayName = String(displayName.prefix(24)) }
                }

                Section {
                    Button("Çıkış Yap", role: .destructive) { confirmsSignOut = true }
                }
            }
            .navigationTitle("Profil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat", systemImage: "xmark", role: .close) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet", systemImage: "checkmark", action: save)
                        .disabled(!hasChanges || trimmedName.count < 2 || isSaving)
                }
            }
            .errorAlert($saveError)
            .confirmationDialog("Çıkış yapılsın mı?", isPresented: $confirmsSignOut, titleVisibility: .visible) {
                Button("Çıkış Yap", role: .destructive) {
                    Task {
                        await onSignOut()
                        dismiss()
                    }
                }
            } message: {
                Text("Oturduğun masadan da kalkmış olursun.")
            }
        }
    }

    private func save() {
        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                try await onSave(
                    trimmedName == user.displayName ? nil : trimmedName,
                    avatar.rawValue == user.avatarSpriteId ? nil : avatar
                )
                dismiss()
            } catch {
                saveError = LibraryError(error)
            }
        }
    }
}
