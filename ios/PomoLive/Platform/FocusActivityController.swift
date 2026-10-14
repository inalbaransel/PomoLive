import ActivityKit
import Foundation

/// Mirrors the reader's running session on the Lock Screen and in the Dynamic Island.
///
/// `Activity` is not `Sendable`, so no reference is kept: each change is queued and applied off the
/// main actor against `Activity.activities`, which also cleans up activities left by a killed launch.
@MainActor
final class FocusActivityController {
    private typealias Content = ActivityContent<FocusActivityAttributes.ContentState>

    private var lastApplied: (attributes: FocusActivityAttributes, state: FocusActivityAttributes.ContentState)?
    private var queue: Task<Void, Never>?

    func sync(attributes: FocusActivityAttributes, state: FocusActivityAttributes.ContentState) {
        guard lastApplied?.attributes != attributes || lastApplied?.state != state else { return }
        lastApplied = (attributes, state)
        let content = Content(state: state, staleDate: state.phaseEndsAt?.addingTimeInterval(60))
        enqueue { await Self.show(attributes, content) }
    }

    func end() {
        lastApplied = nil
        enqueue { await Self.endAll(except: nil) }
    }

    private func enqueue(_ operation: @escaping @Sendable () async -> Void) {
        let previous = queue
        queue = Task {
            await previous?.value
            await operation()
        }
    }

    private nonisolated static func show(_ attributes: FocusActivityAttributes, _ content: Content) async {
        let running = Activity<FocusActivityAttributes>.activities.first {
            $0.attributes == attributes && $0.activityState == .active
        }
        await endAll(except: running?.id)
        if let running {
            await running.update(content)
        } else if ActivityAuthorizationInfo().areActivitiesEnabled {
            _ = try? Activity.request(attributes: attributes, content: content)
        }
    }

    private nonisolated static func endAll(except keptId: String?) async {
        for activity in Activity<FocusActivityAttributes>.activities where activity.id != keptId {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
