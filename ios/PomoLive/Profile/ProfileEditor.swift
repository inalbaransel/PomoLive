import SwiftUI

/// Name and pixel character shown to other readers.
struct ProfileEditor: View {
    let user: UserProfile

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var displayName: String
    @State private var avatar: AvatarSprite
    @State private var isSaving = false
    @State private var error: LibraryError?

    init(user: UserProfile) {
        self.user = user
        _displayName = State(initialValue: user.displayName)
        _avatar = State(initialValue: AvatarSprite(id: user.avatarSpriteId))
    }

    private var trimmedName: String { displayName.trimmingCharacters(in: .whitespaces) }
    private var hasChanges: Bool { trimmedName != user.displayName || avatar.rawValue != user.avatarSpriteId }

    var body: some View {
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
                            .selectableBackground(avatar == sprite, in: .rect(cornerRadius: 16))
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
        }
        .navigationTitle("Profili Düzenle")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if isSaving {
                    ProgressView()
                } else {
                    Button("Kaydet", systemImage: "checkmark", action: save)
                        .disabled(!hasChanges || trimmedName.count < 2)
                }
            }
        }
        .errorAlert($error)
    }

    private func save() {
        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                try await app.updateProfile(
                    displayName: trimmedName == user.displayName ? nil : trimmedName,
                    avatar: avatar.rawValue == user.avatarSpriteId ? nil : avatar
                )
                dismiss()
            } catch {
                self.error = LibraryError(error)
            }
        }
    }
}
