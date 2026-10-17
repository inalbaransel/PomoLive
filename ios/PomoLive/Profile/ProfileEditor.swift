import SwiftUI

/// Pixel character, username, name and bio: everything other readers see on the profile.
struct ProfileEditor: View {
    let user: UserProfile

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var username: String
    @State private var usernameStatus = UsernameStatus.unchanged
    @State private var displayName: String
    @State private var bio: String
    @State private var avatar: AvatarSprite
    @State private var showsPaywall = false
    @State private var isSaving = false
    @State private var error: LibraryError?

    private static let bioLimit = 80

    init(user: UserProfile) {
        self.user = user
        _username = State(initialValue: user.username)
        _displayName = State(initialValue: user.displayName)
        _bio = State(initialValue: user.bio ?? "")
        _avatar = State(initialValue: AvatarSprite(id: user.avatarSpriteId))
    }

    private var trimmedName: String { displayName.trimmingCharacters(in: .whitespaces) }
    private var trimmedBio: String { bio.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var changes: UpdateProfileCommand {
        UpdateProfileCommand(
            username: username == user.username ? nil : username,
            displayName: trimmedName == user.displayName ? nil : trimmedName,
            avatarSpriteId: avatar.rawValue == user.avatarSpriteId ? nil : avatar.rawValue,
            bio: trimmedBio == (user.bio ?? "") ? nil : trimmedBio
        )
    }

    private var hasChanges: Bool {
        changes.username != nil || changes.displayName != nil || changes.avatarSpriteId != nil || changes.bio != nil
    }

    /// A Plus character already worn stays available.
    private func isLocked(_ sprite: AvatarSprite) -> Bool {
        !app.plus.isActive && PlusCatalog.avatars.contains(sprite) && sprite.rawValue != user.avatarSpriteId
    }

    var body: some View {
        Form {
            Section("Karakter") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
                    ForEach(AvatarSprite.allCases) { sprite in
                        Button {
                            if isLocked(sprite) { return showsPaywall = true }
                            avatar = sprite
                        } label: {
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
                            .overlay(alignment: .topTrailing) {
                                if isLocked(sprite) { PlusBadge().padding(4) }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(avatar == sprite ? .isSelected : [])
                    }
                }
                .padding(.vertical, 8)
                .animation(.spring(duration: 0.35), value: avatar)
            }

            Section {
                UsernameField(username: $username, status: $usernameStatus, current: user.username)
            } header: {
                Text("Kullanıcı Adı")
            } footer: {
                UsernameFooter(status: usernameStatus, username: username)
            }

            Section("Görünen ad") {
                TextField("Adın", text: $displayName)
                    .textContentType(.nickname)
                    .onChange(of: displayName) { displayName = String(displayName.prefix(24)) }
            }

            Section {
                TextField("Ne üzerinde çalışıyorsun?", text: $bio, axis: .vertical)
                    .lineLimit(2...4)
                    .onChange(of: bio) { bio = String(bio.prefix(Self.bioLimit)) }
            } header: {
                Text("Hakkında")
            } footer: {
                Text("\(bio.count)/\(Self.bioLimit)")
                    .monospacedDigit()
            }
        }
        .plusPaywall(isPresented: $showsPaywall)
        .navigationTitle("Profili Düzenle")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if isSaving {
                    ProgressView()
                } else {
                    Button("Kaydet", systemImage: "checkmark", action: save)
                        .disabled(!hasChanges || trimmedName.count < 2 || !usernameStatus.allowsSubmit)
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
                try await app.updateProfile(changes)
                dismiss()
            } catch {
                self.error = LibraryError(error)
            }
        }
    }
}
