import SwiftUI

/// People the reader follows: who is focusing right now (with a one-tap join), this week's
/// ranking, and search to follow someone new.
struct FriendsView: View {
    let openRoom: (HallStore.Target) -> Void

    @Environment(AppModel.self) private var app
    @State private var tab = Tab.friends
    @State private var query = ""

    private enum Tab: Hashable {
        case friends, ranking
    }

    var body: some View {
        @Bindable var friends = app.friends

        List {
            if !query.trimmingCharacters(in: .whitespaces).isEmpty {
                searchResults
            } else {
                Section {
                    Picker("Görünüm", selection: $tab) {
                        Text("Arkadaşlar").tag(Tab.friends)
                        Text("Haftalık Sıralama").tag(Tab.ranking)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
                switch tab {
                case .friends: friendList
                case .ranking: ranking
                }
            }
        }
        .navigationTitle("Arkadaşlar")
        .navigationDestination(for: PublicUser.self) { UserProfileView(userId: $0.id) }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Kullanıcı adı veya isim ara")
        .onChange(of: query) { _, text in app.friends.search(text) }
        .refreshable { await app.friends.refresh() }
        .task(id: app.connection) {
            if app.connection == .online { await app.friends.refresh() }
        }
        .animation(.smooth, value: tab)
        .errorAlert($friends.error)
    }

    // MARK: Friends

    @ViewBuilder
    private var friendList: some View {
        let all = app.friends.overview?.friends ?? []
        if all.isEmpty, app.friends.overview != nil {
            ContentUnavailableView {
                Label("Henüz kimseyi takip etmiyorsun", systemImage: "person.2")
            } description: {
                Text("Yukarıdan kullanıcı adıyla ara ya da bir odada birinin profilinden takip et.")
            }
            .listRowBackground(Color.clear)
        } else {
            let focusing = all.filter { $0.activity != nil }
            let others = all.filter { $0.activity == nil }
            if !focusing.isEmpty {
                Section("Şu An Çalışıyor · \(focusing.count)") {
                    ForEach(focusing) { friend in friendRow(friend) }
                }
            }
            if !others.isEmpty {
                Section("Takip Ettiklerin") {
                    ForEach(others) { friend in friendRow(friend) }
                }
            }
        }
    }

    private func friendRow(_ friend: Friend) -> some View {
        NavigationLink(value: friend.user) {
            HStack(spacing: 12) {
                Avatar(user: friend.user, isLive: friend.activity.map { !$0.resting } ?? false)
                VStack(alignment: .leading, spacing: 2) {
                    Text(friend.user.displayName).font(.body.weight(.semibold))
                    if let activity = friend.activity {
                        HStack(spacing: 5) {
                            Image(systemName: activity.resting ? "cup.and.saucer.fill" : activity.category.symbol)
                                .font(.caption)
                                .foregroundStyle(activity.resting ? .mint : activity.category.color.color)
                            Text(activity.resting
                                 ? String(localized: "Molada")
                                 : String(localized: "\(activity.category.displayName) · \(activity.roomName.map { localizedRoomName(id: activity.roomId, name: $0) } ?? String(localized: "özel oda"))"))
                                .foregroundStyle(.secondary)
                        }
                        .font(.subheadline)
                        .lineLimit(1)
                    } else {
                        Text(verbatim: "@\(friend.user.username)").font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
                if let roomId = friend.activity?.roomId {
                    Button("Katıl") { openRoom(.room(id: roomId)) }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
            }
        }
    }

    // MARK: Ranking

    @ViewBuilder
    private var ranking: some View {
        let rows = app.friends.overview?.leaderboard ?? []
        Section {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                HStack(spacing: 12) {
                    Text(verbatim: "\(index + 1)")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(index < 3 ? podium(index) : .secondary)
                        .frame(width: 28)
                    Avatar(user: row.user, isLive: false)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.isSelf ? String(localized: "Sen") : row.user.displayName)
                            .font(.body.weight(row.isSelf ? .bold : .semibold))
                        ProgressView(value: Double(row.weekFocusMs), total: Double(max(rows.first?.weekFocusMs ?? 1, 1)))
                            .tint(row.isSelf ? Color.accentColor : .secondary)
                    }
                    Text(formattedFocus(row.weekFocusMs))
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .frame(minWidth: 64, alignment: .trailing)
                }
                .listRowBackground(row.isSelf ? Color.accentColor.opacity(0.12) : nil)
            }
        } header: {
            Text("Bu Hafta")
        } footer: {
            Text("Odak süresini gizleyenler sıralamada görünmez. Sıralama her pazartesi sıfırlanır.")
        }
    }

    private func podium(_ index: Int) -> Color {
        [Color.yellow, Color.gray, Color.brown][index]
    }

    // MARK: Search

    @ViewBuilder
    private var searchResults: some View {
        Section {
            if app.friends.searchResults.isEmpty {
                Text("Sonuç yok").foregroundStyle(.secondary)
            }
            ForEach(app.friends.searchResults) { user in
                HStack(spacing: 12) {
                    NavigationLink(value: user) {
                        HStack(spacing: 12) {
                            Avatar(user: user, isLive: false)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.displayName).font(.body.weight(.semibold))
                                Text(verbatim: "@\(user.username)").font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                    }
                    FollowButton(userId: user.id)
                }
            }
        }
    }
}

/// Follow / Following toggle used in search and on profiles.
struct FollowButton: View {
    let userId: String

    @Environment(AppModel.self) private var app
    @State private var isWorking = false
    @State private var error: LibraryError?

    var body: some View {
        let following = app.friends.isFollowing(userId)
        Button {
            isWorking = true
            Task {
                defer { isWorking = false }
                do {
                    if following { try await app.friends.unfollow(userId) } else { try await app.friends.follow(userId) }
                } catch {
                    self.error = LibraryError(error)
                }
            }
        } label: {
            Text(following ? "Takiptesin" : "Takip Et")
                .frame(minWidth: 84)
        }
        .buttonStyle(.bordered)
        .tint(following ? .secondary : .accentColor)
        .controlSize(.small)
        .disabled(isWorking)
        .sensoryFeedback(.success, trigger: following)
        .errorAlert($error)
    }
}

private struct Avatar: View {
    let user: PublicUser
    let isLive: Bool

    var body: some View {
        Image(decorative: SpriteCache.shared.avatar(AvatarSprite(id: user.avatarSpriteId)), scale: 1)
            .resizable()
            .interpolation(.none)
            .frame(width: 28, height: 28)
            .frame(width: 42, height: 42)
            .background(.fill.tertiary, in: .circle)
            .overlay(alignment: .bottomTrailing) {
                if isLive {
                    Circle().fill(.green).frame(width: 12, height: 12)
                        .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
                }
            }
    }
}
