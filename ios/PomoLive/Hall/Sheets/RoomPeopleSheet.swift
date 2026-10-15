import SwiftUI

/// Who is in the room now and who belongs to it, ranked by this week's focus here.
/// The owner can remove people and let removed people back in.
struct RoomPeopleSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var members: RoomMembers?
    @State private var loadError: LibraryError?
    @State private var actionError: LibraryError?
    @State private var personToRemove: RoomPerson?

    private static let refreshInterval = Duration.seconds(30)

    /// Reloads whenever someone sits, stands, arrives or leaves.
    private var refreshKey: [String] {
        app.hall.desks.keys.sorted() + ["\(app.hall.room?.presenceCount ?? 0)"]
    }

    var body: some View {
        NavigationStack {
            List {
                if let members {
                    content(members)
                } else if let loadError {
                    ContentUnavailableView(
                        "Kişiler yüklenemedi",
                        systemImage: "person.2.slash",
                        description: Text(loadError.errorDescription ?? "")
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
            .navigationTitle("Kişiler")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: PublicUser.self) { user in
                UserProfileView(userId: user.id)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Kapat", systemImage: "xmark", role: .close) { dismiss() }
                }
            }
            .animation(.smooth, value: members?.people)
            .refreshable { await load() }
            .task(id: refreshKey) { await load() }
            .task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: Self.refreshInterval)
                    await load()
                }
            }
            .confirmationDialog(
                "@\(personToRemove?.user.username ?? "") odadan çıkarılsın mı?",
                isPresented: Binding(get: { personToRemove != nil }, set: { if !$0 { personToRemove = nil } }),
                titleVisibility: .visible
            ) {
                Button("Odadan Çıkar", role: .destructive) {
                    guard let person = personToRemove else { return }
                    perform { try await app.hall.remove(person.user.id) }
                }
            } message: {
                Text("Masası boşaltılır ve sen engeli kaldırana kadar odaya giremez.")
            }
            .errorAlert($actionError)
        }
    }

    @ViewBuilder
    private func content(_ members: RoomMembers) -> some View {
        let here = members.people.filter(\.isHere)
        let away = members.people.filter { !$0.isHere }
        let ranks = Self.ranks(of: members.people)

        Section {
            if here.isEmpty {
                Text("Şu an odada kimse yok.")
                    .foregroundStyle(.secondary)
            }
            ForEach(here) { person in row(person, rank: ranks[person.id]) }
        } header: {
            Text("Burada · \(here.count)")
        } footer: {
            Text("Bu haftaki odak süresine göre sıralı. Süresini gizleyenler en sonda.")
        }

        if !away.isEmpty {
            Section("Üyeler · \(away.count)") {
                ForEach(away) { person in row(person, rank: ranks[person.id]) }
            }
        }

        if let banned = members.banned, !banned.isEmpty {
            Section {
                ForEach(banned) { user in
                    PersonLabel(user: user) {
                        Text(verbatim: "@\(user.username)")
                    }
                    .swipeActions {
                        Button("Engeli Kaldır", systemImage: "person.crop.circle.badge.checkmark") {
                            perform { try await app.hall.unban(user.id) }
                        }
                        .tint(.blue)
                    }
                }
            } header: {
                Text("Çıkarılanlar")
            } footer: {
                Text("Çıkardığın kişiler sen engeli kaldırana kadar odaya giremez. Kaldırmak için sola kaydır.")
            }
        }
    }

    private func row(_ person: RoomPerson, rank: Int?) -> some View {
        NavigationLink(value: person.user) {
            PersonRow(person: person, rank: rank, isMe: person.id == app.user?.id)
        }
        .swipeActions {
            if app.hall.isOwner, person.role != .owner {
                Button("Çıkar", systemImage: "person.fill.xmark", role: .destructive) { personToRemove = person }
            }
        }
    }

    private func load() async {
        do {
            members = try await app.hall.members()
            loadError = nil
        } catch {
            if members == nil { loadError = LibraryError(error) }
        }
    }

    private func perform(_ action: @escaping () async throws -> Void) {
        Task {
            do {
                try await action()
                await load()
            } catch {
                actionError = LibraryError(error)
            }
        }
    }

    /// Podium places 1–3 for people who focused here this week.
    private static func ranks(of people: [RoomPerson]) -> [String: Int] {
        let ranked = people.filter { ($0.weekFocusMs ?? 0) > 0 }.prefix(3)
        return Dictionary(uniqueKeysWithValues: ranked.enumerated().map { ($1.id, $0 + 1) })
    }
}

/// Name, handle, role and what the person is doing, with their week's focus on the trailing edge.
private struct PersonRow: View {
    let person: RoomPerson
    let rank: Int?
    let isMe: Bool

    var body: some View {
        PersonLabel(user: person.user) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(verbatim: "@\(person.user.username)")
                    if person.role == .owner {
                        Text("Yönetici")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.tint)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(.tint.opacity(0.15), in: .capsule)
                    }
                    if isMe {
                        Text("Sen")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(.fill.tertiary, in: .capsule)
                    }
                }
                if let desk = person.desk {
                    if desk.resting {
                        Label("Molada", systemImage: "cup.and.saucer.fill")
                            .foregroundStyle(.mint)
                    } else {
                        Label {
                            Text("\(desk.category.displayName) çalışıyor")
                        } icon: {
                            Image(systemName: desk.category.symbol)
                                .foregroundStyle(desk.category.color.color)
                        }
                    }
                }
            }
        } trailing: {
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 4) {
                    if let rank {
                        Image(systemName: "medal.fill")
                            .foregroundStyle(Self.podiumColor(rank))
                            .accessibilityLabel("\(rank). sıra")
                    }
                    if let weekFocusMs = person.weekFocusMs {
                        Text(formattedFocus(weekFocusMs))
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                    } else {
                        Image(systemName: "eye.slash")
                            .foregroundStyle(.tertiary)
                            .accessibilityLabel("Süresini gizliyor")
                    }
                }
                if person.weekFocusMs != nil {
                    Text("bu hafta")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private static func podiumColor(_ rank: Int) -> Color {
        switch rank {
        case 1: .yellow
        case 2: .gray
        default: .brown
        }
    }
}

/// Avatar and display name over a detail line, the building block of every people row.
private struct PersonLabel<Detail: View, Trailing: View>: View {
    let user: PublicUser
    @ViewBuilder let detail: Detail
    @ViewBuilder let trailing: Trailing

    init(user: PublicUser, @ViewBuilder detail: () -> Detail, @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.user = user
        self.detail = detail()
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(decorative: SpriteCache.shared.avatar(AvatarSprite(id: user.avatarSpriteId)), scale: 1)
                .resizable()
                .interpolation(.none)
                .frame(width: 30, height: 30)
                .frame(width: 42, height: 42)
                .background(.fill.tertiary, in: .circle)
            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .font(.body.weight(.semibold))
                detail
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
            Spacer(minLength: 8)
            trailing
        }
        .accessibilityElement(children: .combine)
    }
}
