import SwiftUI

/// The label floating over a reader: `Alp 💻 42dk`, or `☕` on a break. Tapping the desk expands it.
struct DeskBadgeView: View {
    let desk: DeskRecord
    let isMine: Bool
    let isExpanded: Bool
    let clock: ServerClock

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { _ in
            let now = clock.now
            let isFocusing = desk.timer.reading(at: now).phase == .focus
            VStack(spacing: 2) {
                Text("\(desk.userName) \(isFocusing ? desk.category.emoji : "☕") \(desk.badgeMinutes(at: now))dk")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                if isExpanded {
                    Text([desk.category.name, desk.note, "\(desk.sessionNumber). Seans"].compactMap(\.self).joined(separator: " • "))
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
