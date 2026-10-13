import SwiftUI

/// The label floating over a reader: `Alp 🟢 42dk`. Tapping the desk expands it into a tooltip.
struct DeskBadgeView: View {
    let desk: DeskRecord
    let isMine: Bool
    let isExpanded: Bool
    let clock: ServerClock

    var body: some View {
        TimelineView(.everyMinute) { _ in
            VStack(spacing: 2) {
                Text("\(desk.userName) \(desk.status == .focus ? "🟢" : "☕") \(desk.badgeMinutes(at: clock.now))dk")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                if isExpanded {
                    Text("\(desk.taskLabel) • \(desk.sessionNumber). Seans")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .transition(.blurReplace)
                }
            }
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .glassEffect(isMine ? .regular.tint(.accentColor.opacity(0.45)) : .regular, in: .capsule)
        }
        .fixedSize()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
