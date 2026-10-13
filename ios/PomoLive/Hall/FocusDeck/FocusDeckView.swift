import SwiftUI

/// The reader's control panel while seated. Swipe down (or tap the chevron) to melt it into a
/// compact capsule so the hall can be explored full-screen; the countdown keeps running in both.
struct FocusDeckView: View {
    let desk: DeskRecord
    let cycle: HallCycle?
    let clock: ServerClock
    @Binding var isExpanded: Bool
    let onToggleBreak: () -> Void
    let onStand: () -> Void

    @Namespace private var glassNamespace

    private var isOnBreak: Bool { desk.status == .onBreak }

    var body: some View {
        GlassEffectContainer(spacing: 24) {
            if isExpanded {
                expandedDeck
                    .glassEffect(.regular, in: .rect(cornerRadius: 32))
                    .glassEffectID("deck", in: glassNamespace)
            } else {
                compactCapsule
                    .glassEffect(.regular.interactive(), in: .capsule)
                    .glassEffectID("deck", in: glassNamespace)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .gesture(
            DragGesture(minimumDistance: 12).onEnded { value in
                if value.translation.height > 30 { isExpanded = false }
                if value.translation.height < -30 { isExpanded = true }
            }
        )
        .animation(.spring(duration: 0.5, bounce: 0.28), value: isExpanded)
        .sensoryFeedback(.impact(weight: .light), trigger: isExpanded)
    }

    private var expandedDeck: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                avatar(size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(desk.taskLabel)
                        .font(.headline)
                        .lineLimit(1)
                    Text("Masa \(desk.number) · \(desk.sessionNumber). seans")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Button("Küçült", systemImage: "chevron.down") { isExpanded = false }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
            }

            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(cycle?.title ?? "Salon")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    countdown
                        .font(.system(size: 46, weight: .bold, design: .monospaced))
                        .contentTransition(.numericText(countsDown: true))
                }
                Spacer(minLength: 0)
                TimelineView(.everyMinute) { _ in
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(isOnBreak ? "Moladasın" : "Bu seans")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        Text("\(desk.focusedMs(at: clock.now) / 60_000) dk odak")
                            .font(.system(.title3, design: .monospaced, weight: .semibold))
                    }
                }
            }

            HStack(spacing: 12) {
                Button(action: onToggleBreak) {
                    Label(isOnBreak ? "Odaklan" : "Mola Ver", systemImage: isOnBreak ? "bolt.fill" : "cup.and.saucer.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)

                Button(role: .destructive, action: onStand) {
                    Label("Masadan Kalk", systemImage: "figure.walk")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .controlSize(.large)
        }
        .padding(20)
    }

    private var compactCapsule: some View {
        Button { isExpanded = true } label: {
            HStack(spacing: 10) {
                avatar(size: 26)
                Text(isOnBreak ? "☕" : "🟢")
                countdown
                    .font(.system(.headline, design: .monospaced))
                Text(desk.taskLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Odak panelini açar")
    }

    @ViewBuilder
    private var countdown: some View {
        if let cycle {
            let end = clock.localDate(cycle.endsAt)
            Text(timerInterval: Date.now...max(end, .now), countsDown: true)
                .monospacedDigit()
        }
    }

    private func avatar(size: CGFloat) -> some View {
        Image(decorative: SpriteCache.shared.avatar(AvatarSprite(id: desk.avatarSpriteId)), scale: 1)
            .resizable()
            .interpolation(.none)
            .frame(width: size, height: size)
    }
}
