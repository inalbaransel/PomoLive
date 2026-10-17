import SwiftUI

/// Someone else's desk, tapped on the map: who they are, what they are working on and for how long,
/// a row of reactions to cheer them on, and the way to their profile.
struct DeskPeekSheet: View {
    let desk: DeskRecord

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var sent: DeskReaction?
    @State private var error: LibraryError?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                HStack(spacing: 14) {
                    Image(decorative: SpriteCache.shared.avatar(AvatarSprite(id: desk.avatarSpriteId)), scale: 1)
                        .resizable()
                        .interpolation(.none)
                        .frame(width: 38, height: 38)
                        .frame(width: 60, height: 60)
                        .background(.fill.tertiary, in: .circle)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(desk.userName)
                            .font(.title3.weight(.bold))
                        TimelineView(.periodic(from: .now, by: 30)) { _ in
                            let now = app.time.clock.now
                            let isFocusing = desk.timer.reading(at: now).phase == .focus
                            Label {
                                Text(isFocusing
                                     ? "\(desk.category.displayName) · \(desk.badgeMinutes(at: now)) dk"
                                     : "Molada · \(desk.badgeMinutes(at: now)) dk")
                            } icon: {
                                Image(systemName: isFocusing ? desk.category.symbol : "cup.and.saucer.fill")
                                    .foregroundStyle(isFocusing ? desk.category.color.color : .brown)
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        }
                        if let note = desk.note {
                            Text(note)
                                .font(.footnote)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                }

                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        ForEach(DeskReaction.allCases) { reaction in
                            Button {
                                send(reaction)
                            } label: {
                                Text(reaction.emoji)
                                    .font(.title2)
                                    .frame(maxWidth: .infinity, minHeight: 52)
                            }
                            .buttonStyle(.glass)
                            .disabled(sent != nil)
                            .scaleEffect(sent == reaction ? 1.15 : 1)
                            .opacity(sent != nil && sent != reaction ? 0.4 : 1)
                        }
                    }
                    Text(sent == nil
                         ? "Sessizce destek ol; masasının üstünde belirir."
                         : "Gönderildi. \(desk.userName) görecek.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .contentTransition(.opacity)
                }
                .animation(.spring(duration: 0.35, bounce: 0.4), value: sent)

                NavigationLink {
                    UserProfileView(userId: desk.userId)
                } label: {
                    Label("Profili Gör", systemImage: "person.crop.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Spacer(minLength: 0)
            }
            .padding(20)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Kapat", systemImage: "xmark", role: .close) { dismiss() }
                }
            }
            .sensoryFeedback(.impact(weight: .light), trigger: sent)
            .errorAlert($error)
        }
    }

    private func send(_ reaction: DeskReaction) {
        sent = reaction
        Task {
            do {
                try await app.hall.react(reaction, to: desk.deskId)
            } catch {
                sent = nil
                self.error = LibraryError(error)
            }
        }
    }
}
