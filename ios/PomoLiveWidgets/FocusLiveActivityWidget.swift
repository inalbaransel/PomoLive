import ActivityKit
import SwiftUI
import WidgetKit

/// Lock Screen banner and Dynamic Island for a reader sitting at a desk.
struct FocusLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusActivityAttributes.self) { context in
            LockScreenFocusView(context: context)
                .padding(16)
                .activityBackgroundTint(nil)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    PixelAvatar(id: context.attributes.avatarSpriteId, phase: context.state.phase, size: 40)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    SessionClock(state: context.state)
                        .font(.system(.title2, design: .monospaced, weight: .bold))
                        .frame(maxWidth: 110)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text("\(context.attributes.categoryEmoji) \(context.attributes.categoryName)")
                        .font(.headline)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("\(phaseTitle(context)) · \(context.state.focusedMinutes) dk odak · \(context.attributes.roomName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            } compactLeading: {
                Text(context.state.phase == .focus ? context.attributes.categoryEmoji : "☕")
            } compactTrailing: {
                SessionClock(state: context.state)
                    .font(.system(.caption, design: .monospaced, weight: .semibold))
                    .frame(maxWidth: 56)
            } minimal: {
                PixelAvatar(id: context.attributes.avatarSpriteId, phase: context.state.phase, size: 20)
            }
            .keylineTint(.orange)
        }
    }
}

private func phaseTitle(_ context: ActivityViewContext<FocusActivityAttributes>) -> String {
    switch (context.attributes.isPomodoro, context.state.phase) {
    case (true, .focus): "Odak"
    case (true, .rest): "Mola"
    case (false, .focus): "Çalışıyor"
    case (false, .rest): "Duraklatıldı"
    }
}

private struct LockScreenFocusView: View {
    let context: ActivityViewContext<FocusActivityAttributes>

    var body: some View {
        HStack(spacing: 14) {
            PixelAvatar(id: context.attributes.avatarSpriteId, phase: context.state.phase, size: 48)
            VStack(alignment: .leading, spacing: 4) {
                Text("\(context.attributes.categoryEmoji) \(context.attributes.categoryName)")
                    .font(.headline)
                    .lineLimit(1)
                Text("\(context.attributes.roomName) · \(context.state.focusedMinutes) dk odak")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 2) {
                Text(phaseTitle(context).uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                SessionClock(state: context.state)
                    .font(.system(.title2, design: .monospaced, weight: .bold))
            }
        }
    }
}

/// Counts down a pomodoro phase, counts up a running stopwatch, or shows the frozen total while paused.
private struct SessionClock: View {
    let state: FocusActivityAttributes.ContentState

    var body: some View {
        Group {
            if let end = state.phaseEndsAt {
                Text(timerInterval: Date.now...max(end, .now), countsDown: true)
            } else if let start = state.countUpFrom {
                Text(timerInterval: start...Date.distantFuture, countsDown: false)
            } else {
                Text("\(state.focusedMinutes) dk")
            }
        }
        .monospacedDigit()
        .multilineTextAlignment(.trailing)
    }
}

private struct PixelAvatar: View {
    let id: String
    let phase: FocusActivityAttributes.ContentState.Phase
    let size: CGFloat

    var body: some View {
        Image(decorative: AvatarSprite(id: id).image(phase == .focus ? .typing(frame: 0) : .sipping(frame: 0)), scale: 1)
            .resizable()
            .interpolation(.none)
            .frame(width: size, height: size)
    }
}
