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
                    PixelAvatar(id: context.attributes.avatarSpriteId, status: context.state.mode, size: 40)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    HallCountdown(state: context.state)
                        .font(.system(.title2, design: .monospaced, weight: .bold))
                        .frame(maxWidth: 96)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.taskLabel)
                        .font(.headline)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(statusLine(context))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                PixelAvatar(id: context.attributes.avatarSpriteId, status: context.state.mode, size: 22)
            } compactTrailing: {
                HallCountdown(state: context.state)
                    .font(.system(.caption, design: .monospaced, weight: .semibold))
                    .frame(maxWidth: 52)
            } minimal: {
                PixelAvatar(id: context.attributes.avatarSpriteId, status: context.state.mode, size: 20)
            }
            .keylineTint(.orange)
        }
    }

    private func statusLine(_ context: ActivityViewContext<FocusActivityAttributes>) -> String {
        let mode = context.state.mode == .focus ? "Odaktasın" : "Moladasın"
        return "\(mode) · \(context.state.sessionFocusMinutes) dk · \(context.attributes.hallName)"
    }
}

private struct LockScreenFocusView: View {
    let context: ActivityViewContext<FocusActivityAttributes>

    var body: some View {
        HStack(spacing: 14) {
            PixelAvatar(id: context.attributes.avatarSpriteId, status: context.state.mode, size: 48)
            VStack(alignment: .leading, spacing: 4) {
                Text(context.attributes.taskLabel)
                    .font(.headline)
                    .lineLimit(1)
                Text("\(context.state.mode == .focus ? "🟢 Odakta" : "☕ Molada") · \(context.state.sessionFocusMinutes) dk")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 2) {
                Text(context.state.hallPhase == .focus ? "SALON ODAKTA" : "SALON MOLADA")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                HallCountdown(state: context.state)
                    .font(.system(.title2, design: .monospaced, weight: .bold))
            }
        }
    }
}

private struct HallCountdown: View {
    let state: FocusActivityAttributes.ContentState

    var body: some View {
        Text(timerInterval: Date.now...max(state.hallPhaseEndsAt, .now), countsDown: true)
            .monospacedDigit()
            .multilineTextAlignment(.trailing)
    }
}

private struct PixelAvatar: View {
    let id: String
    let status: FocusActivityAttributes.ContentState.Mode
    let size: CGFloat

    var body: some View {
        Image(decorative: AvatarSprite(id: id).image(status == .focus ? .typing(frame: 0) : .sipping(frame: 0)), scale: 1)
            .resizable()
            .interpolation(.none)
            .frame(width: size, height: size)
    }
}
