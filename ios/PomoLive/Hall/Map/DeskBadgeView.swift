import SwiftUI

/// The label floating over a reader: name, category symbol (a cup on a break) and minutes. Tap to expand.
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
                HStack(spacing: 4) {
                    Text(desk.userName)
                    Image(systemName: isFocusing ? desk.category.symbol : "cup.and.saucer.fill")
                        .foregroundStyle(isFocusing ? desk.category.color.color : .brown)
                    Text("\(desk.badgeMinutes(at: now)) dk")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .font(.system(size: 11, weight: .semibold))
                if isExpanded {
                    Text([desk.category.displayName, desk.note, String(localized: "\(desk.sessionNumber). Seans")].compactMap(\.self).joined(separator: " • "))
                        .font(.system(size: 10, weight: .medium))
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
