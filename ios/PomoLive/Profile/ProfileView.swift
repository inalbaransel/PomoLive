import SwiftUI

/// The Profil tab: the reader as others see them, today's progress toward their goals, their
/// badges and their own lists. Settings live behind the gear.
struct ProfileView: View {
    @Environment(AppModel.self) private var app
    @State private var counts: (followers: Int, following: Int)?
    @State private var editsProfile = false

    var body: some View {
        NavigationStack {
            List {
                if let user = app.user {
                    Section {
                        ProfileCard(user: user, counts: counts) { editsProfile = true }
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())

                    Section { PlusRow() }

                    if let summary = app.stats.summary {
                        Section("Bugün") {
                            StatsHeadline(summary: summary, dailyGoalMinutes: user.dailyGoalMinutes, weeklyGoalMinutes: user.weeklyGoalMinutes)
                        }
                        if let badges = summary.badges {
                            Section("Rozetler") { BadgeShelf(badges: badges) }
                        }
                    }
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
                    NavigationLink {
                        HistoryView()
                    } label: {
                        SettingsLabel(title: "Oturum Geçmişi", systemName: "clock.arrow.circlepath", color: .blue)
                    }
                }
            }
            .navigationTitle("Profil")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label("Ayarlar", systemImage: "gearshape")
                    }
                }
            }
            .navigationDestination(isPresented: $editsProfile) {
                if let user = app.user { ProfileEditor(user: user) }
            }
            .refreshable { await load() }
            .task(id: app.connection) {
                if app.connection == .online { await load() }
            }
        }
    }

    private func load() async {
        guard let id = app.user?.id else { return }
        async let stats: Void = app.stats.refresh()
        async let profile = try? app.profile(of: id)
        if let profile = await profile {
            counts = (profile.followerCount ?? 0, profile.followingCount ?? 0)
        }
        await stats
    }
}

/// Avatar, names, bio and follower counts, centred like a Contacts card, with a way to edit.
private struct ProfileCard: View {
    let user: UserProfile
    let counts: (followers: Int, following: Int)?
    let onEdit: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(decorative: SpriteCache.shared.avatar(AvatarSprite(id: user.avatarSpriteId)), scale: 1)
                .resizable()
                .interpolation(.none)
                .frame(width: 68, height: 68)
                .frame(width: 104, height: 104)
                .background(.fill.tertiary, in: .circle)

            VStack(spacing: 2) {
                Text(user.displayName)
                    .font(.title2.weight(.bold))
                Text(verbatim: "@\(user.username)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let bio = user.bio {
                Text(bio)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 28) {
                count(counts?.followers, label: "Takipçi")
                count(counts?.following, label: "Takip")
            }

            Button(action: onEdit) {
                Text("Profili Düzenle")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 8)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private func count(_ value: Int?, label: LocalizedStringKey) -> some View {
        VStack(spacing: 0) {
            Text(value.map(String.init) ?? "–")
                .font(.headline)
                .monospacedDigit()
                .contentTransition(.numericText())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .animation(.smooth, value: value)
        .accessibilityElement(children: .combine)
    }
}
