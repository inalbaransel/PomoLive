import SwiftUI

/// A reader's profile as others see it: who they are, what they focus on now and, unless they
/// hide it, their focus time in the same layout as the İstatistik tab.
struct UserProfileView: View {
    let userId: String

    @Environment(AppModel.self) private var app
    @State private var profile: PublicProfile?
    @State private var error: LibraryError?
    @State private var isReporting = false
    @State private var blocking: PublicUser?
    @State private var actionError: LibraryError?

    var body: some View {
        List {
            if let profile {
                Section {
                    ProfileHeader(profile: profile)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                if profile.isBlocked == true {
                    Section {
                        Button("Engeli Kaldır", systemImage: "hand.raised.slash") { unblock(profile) }
                    } footer: {
                        Text("\(profile.displayName) kişisini engelledin. Mesajlarını görmüyorsun ve birbirinizi takip edemiyorsunuz.")
                    }
                } else if !profile.isSelf {
                    Section {
                        HStack {
                            Label("\(profile.followerCount ?? 0) takipçi", systemImage: "person.2.fill")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            FollowButton(userId: profile.id)
                        }
                    }
                }

                if let stats = profile.stats, !stats.isUnlocked {
                    Section {
                        ContentUnavailableView(
                            "Henüz yeterli veri yok",
                            systemImage: "chart.bar.xaxis",
                            description: Text("\(profile.displayName) birkaç gün daha çalışınca istatistikleri burada görünür.")
                        )
                    }
                } else if let stats = profile.stats {
                    Section {
                        StatsHeadline(summary: stats, dailyGoalMinutes: profile.dailyGoalMinutes, weeklyGoalMinutes: profile.weeklyGoalMinutes)
                    }
                    if let badges = stats.badges, badges.contains(where: \.earned) {
                        Section("Rozetler") { BadgeShelf(badges: badges.filter(\.earned)) }
                    }
                    Section("Son 7 Gün") {
                        WeekChart(days: stats.last7Days)
                    }
                    if !stats.categories.isEmpty {
                        Section {
                            ForEach(stats.categories.prefix(3)) { category in
                                CategoryRow(category: category, share: CategoryRow.share(of: category, in: stats.categories))
                            }
                        } header: {
                            Text("En Çok Çalıştıkları")
                        } footer: {
                            Text("Son 30 gün")
                        }
                    }
                } else {
                    Section {
                        ContentUnavailableView(
                            "Çalışma süreleri gizli",
                            systemImage: "eye.slash",
                            description: Text("\(profile.displayName) odak sürelerini yalnızca kendisi görüyor.")
                        )
                    }
                }
            } else if let error {
                ContentUnavailableView(
                    "Profil açılamadı",
                    systemImage: "person.crop.circle.badge.exclamationmark",
                    description: Text(error.errorDescription ?? "")
                )
            } else {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle(profile.map { "@\($0.username)" } ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let profile, !profile.isSelf {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu("Seçenekler", systemImage: "ellipsis") {
                        Button("Bildir…", systemImage: "exclamationmark.bubble") { isReporting = true }
                        if profile.isBlocked == true {
                            Button("Engeli Kaldır", systemImage: "hand.raised.slash") { unblock(profile) }
                        } else {
                            Button("Engelle", systemImage: "hand.raised", role: .destructive) {
                                blocking = profile.publicUser
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $isReporting, onDismiss: { Task { await load() } }) {
            if let profile {
                ReportSheet(user: profile.publicUser)
                    .presentationDetents([.large])
            }
        }
        .blockConfirmation($blocking) { user in
            Task {
                do {
                    try await app.block(user)
                    await load()
                } catch {
                    actionError = LibraryError(error)
                }
            }
        }
        .errorAlert($actionError)
        .animation(.smooth, value: profile)
        .refreshable { await load() }
        .task { await load() }
    }

    private func unblock(_ profile: PublicProfile) {
        Task {
            do {
                try await app.safety.unblock(profile.id)
                await load()
            } catch {
                actionError = LibraryError(error)
            }
        }
    }

    private func load() async {
        do {
            profile = try await app.profile(of: userId)
            error = nil
        } catch {
            self.error = LibraryError(error)
        }
    }
}

/// Avatar, names, bio and what the reader is doing right now, centred like a Contacts card.
private struct ProfileHeader: View {
    let profile: PublicProfile

    private var joined: String {
        Date(timeIntervalSince1970: Double(profile.joinedAt) / 1000).formatted(.dateTime.month(.wide).year().locale(.app))
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(decorative: SpriteCache.shared.avatar(AvatarSprite(id: profile.avatarSpriteId)), scale: 1)
                .resizable()
                .interpolation(.none)
                .frame(width: 68, height: 68)
                .frame(width: 96, height: 96)
                .background(.fill.tertiary, in: .circle)

            VStack(spacing: 2) {
                Text(profile.displayName)
                    .font(.title2.weight(.bold))
                Text(verbatim: "@\(profile.username)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let bio = profile.bio {
                Text(bio)
                    .font(.body)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 4) {
                if let category = profile.focusingOn {
                    Label {
                        Text("Şu an \(category.displayName) çalışıyor")
                    } icon: {
                        Circle()
                            .fill(.green)
                            .frame(width: 8, height: 8)
                    }
                    .labelStyle(.titleAndIcon)
                }
                Label("Katılım: \(joined)", systemImage: "calendar")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }
}
