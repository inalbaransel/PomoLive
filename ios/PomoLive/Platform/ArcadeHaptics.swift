import CoreHaptics

/// Short, sharp "button-click" patterns that feel like an arcade cabinet rather than a phone.
@MainActor
final class ArcadeHaptics {
    enum Pattern {
        case sitDown, standUp, toggleBreak, phaseChange, denied
    }

    private let engine: CHHapticEngine?

    init() {
        engine = CHHapticEngine.capabilitiesForHardware().supportsHaptics ? try? CHHapticEngine() : nil
        engine?.isAutoShutdownEnabled = true
    }

    func play(_ pattern: Pattern) {
        guard let engine, let haptic = try? CHHapticPattern(events: events(for: pattern), parameters: []) else { return }
        // Starting is cheap when already running and also recovers from a system reset.
        try? engine.start()
        try? engine.makePlayer(with: haptic).start(atTime: CHHapticTimeImmediate)
    }

    private func events(for pattern: Pattern) -> [CHHapticEvent] {
        switch pattern {
        case .sitDown: [tick(at: 0, sharpness: 0.9), tick(at: 0.08, intensity: 1, sharpness: 1)]
        case .standUp: [tick(at: 0, intensity: 1, sharpness: 1), tick(at: 0.09, intensity: 0.5, sharpness: 0.6)]
        case .toggleBreak: [tick(at: 0, sharpness: 0.7)]
        case .phaseChange: [0, 0.12, 0.24].map { tick(at: $0, intensity: 0.9, sharpness: 1) }
        case .denied: [tick(at: 0, intensity: 1, sharpness: 0.2), tick(at: 0.1, intensity: 1, sharpness: 0.2)]
        }
    }

    private func tick(at time: TimeInterval, intensity: Float = 0.8, sharpness: Float) -> CHHapticEvent {
        CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
            ],
            relativeTime: time
        )
    }
}
