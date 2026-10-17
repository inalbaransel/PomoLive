import SwiftUI

/// The readers this one blocked, with a way to unblock each.
struct BlockedUsersView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        @Bindable var safety = app.safety

        List {
            if app.safety.blocked.isEmpty {
                ContentUnavailableView(
                    "Kimseyi engellemedin",
                    systemImage: "hand.raised",
                    description: Text("Bir kişiyi profilinden ya da sohbette mesajına basılı tutarak engelleyebilirsin.")
                )
                .listRowBackground(Color.clear)
            }
            ForEach(app.safety.blocked) { user in
                HStack(spacing: 12) {
                    Image(decorative: SpriteCache.shared.avatar(AvatarSprite(id: user.avatarSpriteId)), scale: 1)
                        .resizable()
                        .interpolation(.none)
                        .frame(width: 28, height: 28)
                        .frame(width: 40, height: 40)
                        .background(.fill.tertiary, in: .circle)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(user.displayName)
                            .font(.body.weight(.medium))
                        Text(verbatim: "@\(user.username)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Engeli Kaldır") { unblock(user) }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
                .swipeActions {
                    Button("Engeli Kaldır") { unblock(user) }
                        .tint(.blue)
                }
            }
        }
        .navigationTitle("Engellenenler")
        .animation(.smooth, value: app.safety.blocked)
        .task { await app.safety.refresh() }
        .refreshable { await app.safety.refresh() }
        .errorAlert($safety.error)
    }

    private func unblock(_ user: PublicUser) {
        Task {
            do {
                try await app.safety.unblock(user.id)
            } catch {
                app.safety.error = LibraryError(error)
            }
        }
    }
}
