import SwiftUI

/// The room's chat, in the style of Messages: bubbles grouped by sender, day dividers, a typing
/// indicator, older messages loaded on scroll and a growing input field pinned above the keyboard.
struct RoomChatSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""
    @State private var scrollPosition = ScrollPosition(edge: .bottom)
    @State private var isNearBottom = true
    @FocusState private var isFocused: Bool

    private static let groupingWindowMs: Int64 = 5 * 60_000

    var body: some View {
        @Bindable var chat = app.chat

        NavigationStack {
            messages
                .safeAreaBar(edge: .bottom) { composer }
                .navigationTitle("Sohbet")
                .navigationSubtitle(app.hall.room.map { $0.displayName } ?? "")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Kapat", systemImage: "xmark", role: .close) { dismiss() }
                    }
                }
                .errorAlert($chat.error)
        }
        .onAppear { app.chat.isOpen = true }
        .onDisappear { app.chat.isOpen = false }
    }

    // MARK: - Messages

    @ViewBuilder
    private var messages: some View {
        let entries = app.chat.entries
        if entries.isEmpty, !app.chat.isLoading {
            ContentUnavailableView {
                Label("Henüz mesaj yok", systemImage: "bubble.left.and.bubble.right")
            } description: {
                Text("İlk mesajı sen yaz; odadaki herkes anında görür.")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(.rect)
            .onTapGesture { isFocused = false }
        } else {
            ScrollView {
                LazyVStack(spacing: 2) {
                    if app.chat.hasMore {
                        ProgressView()
                            .padding(.vertical, 12)
                            .task { await app.chat.loadOlder() }
                    }
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        let previous = index > 0 ? entries[index - 1] : nil
                        let next = index + 1 < entries.count ? entries[index + 1] : nil
                        if previous.map({ !Calendar.current.isDate($0.message.date, inSameDayAs: entry.message.date) }) ?? true {
                            DayDivider(date: entry.message.date)
                        }
                        MessageRow(
                            entry: entry,
                            isMine: entry.message.user.id == app.user?.id,
                            startsGroup: !continues(previous, into: entry),
                            endsGroup: !continues(entry, into: next),
                            canDelete: entry.message.user.id == app.user?.id || app.hall.isOwner
                        )
                        .id(entry.id)
                    }
                    if !app.chat.typing.isEmpty {
                        TypingRow(users: app.chat.typing)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .animation(.smooth(duration: 0.3), value: entries)
                .animation(.smooth(duration: 0.3), value: app.chat.typing)
            }
            .defaultScrollAnchor(.bottom)
            .scrollPosition($scrollPosition)
            .scrollDismissesKeyboard(.interactively)
            .onScrollGeometryChange(for: Bool.self) { geometry in
                geometry.contentOffset.y + geometry.containerSize.height >= geometry.contentSize.height - 120
            } action: { _, nearBottom in
                isNearBottom = nearBottom
            }
            .onChange(of: entries.last?.id) { _, _ in
                // Follow new messages while reading the latest ones, and always after sending.
                let isMine = entries.last?.message.user.id == app.user?.id
                guard isNearBottom || isMine else { return }
                withAnimation(.smooth(duration: 0.3)) { scrollPosition.scrollTo(edge: .bottom) }
            }
            .overlay(alignment: .bottomTrailing) {
                if !isNearBottom {
                    Button("En alta git", systemImage: "chevron.down") {
                        withAnimation(.smooth) { scrollPosition.scrollTo(edge: .bottom) }
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .padding(16)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.smooth, value: isNearBottom)
        }
    }

    /// Consecutive messages from one person within a few minutes share a bubble group.
    private func continues(_ first: ChatStore.Entry?, into second: ChatStore.Entry?) -> Bool {
        guard let first, let second else { return false }
        return first.message.user.id == second.message.user.id
            && second.message.createdAt - first.message.createdAt < Self.groupingWindowMs
            && Calendar.current.isDate(first.message.date, inSameDayAs: second.message.date)
    }

    // MARK: - Composer

    private var trimmedDraft: String { draft.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Mesaj", text: $draft, axis: .vertical)
                .lineLimit(1...5)
                .focused($isFocused)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 22))
                .onChange(of: draft) { _, text in
                    if text.count > 500 { draft = String(text.prefix(500)) }
                    if !text.isEmpty { app.chat.userIsTyping() }
                }
            Button("Gönder", systemImage: "arrow.up", action: send)
                .labelStyle(.iconOnly)
                .font(.body.weight(.semibold))
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.circle)
                .controlSize(.large)
                .disabled(trimmedDraft.isEmpty || app.connection != .online)
                .animation(.smooth, value: trimmedDraft.isEmpty)
                .sensoryFeedback(.impact(weight: .light), trigger: app.chat.entries.count)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func send() {
        guard let user = app.user, !trimmedDraft.isEmpty else { return }
        app.chat.send(draft, as: user.publicUser)
        draft = ""
    }
}

private extension ChatMessage {
    var date: Date { Date(timeIntervalSince1970: Double(createdAt) / 1000) }
}

/// One message: others' bubbles on the left with an avatar and name at the start of a group,
/// the reader's own in the accent colour on the right with their delivery state.
private struct MessageRow: View {
    let entry: ChatStore.Entry
    let isMine: Bool
    let startsGroup: Bool
    let endsGroup: Bool
    let canDelete: Bool

    @Environment(AppModel.self) private var app
    @State private var confirmsDelete = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isMine {
                Spacer(minLength: 48)
            } else {
                avatar
            }
            VStack(alignment: isMine ? .trailing : .leading, spacing: 2) {
                if startsGroup, !isMine {
                    Text(entry.message.user.displayName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 12)
                }
                bubble
                if endsGroup || entry.state != .sent {
                    footer
                }
            }
            if !isMine { Spacer(minLength: 48) }
        }
        .padding(.top, startsGroup ? 8 : 0)
        .confirmationDialog("Mesaj silinsin mi?", isPresented: $confirmsDelete, titleVisibility: .visible) {
            Button("Sil", role: .destructive) { Task { await app.chat.delete(entry) } }
        } message: {
            Text("Odadaki herkes için silinir.")
        }
    }

    private var bubble: some View {
        Text(entry.message.body)
            .font(.body)
            .foregroundStyle(isMine ? .white : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                isMine ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(Color(.secondarySystemFill)),
                in: .rect(cornerRadius: 20)
            )
            .opacity(entry.state == .sending ? 0.6 : 1)
            .textSelection(.enabled)
            .contextMenu {
                Button("Kopyala", systemImage: "doc.on.doc") { UIPasteboard.general.string = entry.message.body }
                if entry.state == .failed {
                    Button("Tekrar Gönder", systemImage: "arrow.clockwise") { app.chat.retry(entry) }
                }
                if canDelete {
                    Button("Sil", systemImage: "trash", role: .destructive) {
                        if entry.state == .sent { confirmsDelete = true } else { app.chat.discard(entry) }
                    }
                }
            }
    }

    @ViewBuilder
    private var footer: some View {
        switch entry.state {
        case .sending:
            Text("Gönderiliyor…")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
        case .failed:
            Button {
                app.chat.retry(entry)
            } label: {
                Label("Gönderilemedi · Tekrar dene", systemImage: "exclamationmark.circle.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 6)
        case .sent:
            Text(entry.message.date, format: .dateTime.hour().minute())
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 6)
        }
    }

    @ViewBuilder
    private var avatar: some View {
        if endsGroup {
            Image(decorative: SpriteCache.shared.avatar(AvatarSprite(id: entry.message.user.avatarSpriteId)), scale: 1)
                .resizable()
                .interpolation(.none)
                .frame(width: 22, height: 22)
                .frame(width: 30, height: 30)
                .background(.fill.tertiary, in: .circle)
                .padding(.bottom, 18)
        } else {
            Color.clear.frame(width: 30, height: 1)
        }
    }
}

/// "Bugün", "Dün" or a date, centred between days.
private struct DayDivider: View {
    let date: Date

    private var title: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return String(localized: "Bugün") }
        if calendar.isDateInYesterday(date) { return String(localized: "Dün") }
        return date.formatted(.dateTime.day().month(.wide).weekday(.wide))
    }

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
    }
}

/// Three pulsing dots with who is typing.
private struct TypingRow: View {
    let users: [PublicUser]

    private var label: String {
        switch users.count {
        case 1: String(localized: "\(users[0].displayName) yazıyor")
        case 2: String(localized: "\(users[0].displayName) ve \(users[1].displayName) yazıyor")
        default: String(localized: "\(users.count) kişi yazıyor")
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(.secondary)
                        .frame(width: 7, height: 7)
                        .phaseAnimator([0.35, 1]) { dot, phase in
                            dot.opacity(phase)
                        } animation: { _ in .easeInOut(duration: 0.5).delay(Double(index) * 0.15) }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(.secondarySystemFill), in: .capsule)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.leading, 38)
        .padding(.top, 6)
        .accessibilityElement(children: .combine)
    }
}
