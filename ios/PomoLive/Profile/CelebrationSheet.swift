import SwiftUI

/// A badge just earned, streaks included: confetti, the medal popping in and a success haptic.
struct CelebrationSheet: View {
    let celebration: Celebration

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isRevealed = false

    var body: some View {
        if let style = BadgeStyle(id: celebration.badge.id) {
            VStack(spacing: 20) {
                Spacer(minLength: 8)
                BadgeMedal(badge: celebration.badge, style: style, size: 116)
                    .scaleEffect(isRevealed ? 1 : 0.2)
                    .rotationEffect(.degrees(isRevealed ? 0 : -25))
                VStack(spacing: 8) {
                    Text(celebration.headline)
                        .font(.title.weight(.bold))
                        .multilineTextAlignment(.center)
                    Text(style.title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(style.color)
                    Text(style.detail)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .opacity(isRevealed ? 1 : 0)
                .offset(y: isRevealed ? 0 : 12)
                Spacer(minLength: 8)
                Button {
                    dismiss()
                } label: {
                    Text("Harika")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.extraLarge)
                .fontWeight(.semibold)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                if !reduceMotion { ConfettiView(colors: [style.color, .yellow, .accentColor, .pink, .mint]) }
            }
            .sensoryFeedback(.success, trigger: isRevealed)
            .onAppear {
                withAnimation(.spring(duration: 0.7, bounce: 0.5).delay(0.15)) { isRevealed = true }
            }
        }
    }
}

/// A one-off shower of confetti falling from the top, drawn in a canvas.
private struct ConfettiView: View {
    let colors: [Color]

    private struct Piece {
        let x: Double
        let delay: Double
        let speed: Double
        let drift: Double
        let spin: Double
        let size: CGSize
        let color: Color
    }

    private static let duration = 3.2
    @State private var start = Date.now
    @State private var pieces: [Piece] = []

    var body: some View {
        TimelineView(.animation(paused: Date.now.timeIntervalSince(start) > Self.duration + 1)) { context in
            Canvas { canvas, size in
                let elapsed = context.date.timeIntervalSince(start)
                for piece in pieces {
                    let t = elapsed - piece.delay
                    guard t > 0 else { continue }
                    let y = -20 + t * piece.speed * size.height / Self.duration
                    guard y < size.height + 20 else { continue }
                    let x = piece.x * size.width + sin(t * 3 + piece.drift) * 18
                    var copy = canvas
                    copy.translateBy(x: x, y: y)
                    copy.rotate(by: .degrees(t * piece.spin))
                    copy.opacity = max(0, 1 - t / (Self.duration * 1.1))
                    copy.fill(
                        Path(roundedRect: CGRect(origin: CGPoint(x: -piece.size.width / 2, y: -piece.size.height / 2), size: piece.size), cornerRadius: 1.5),
                        with: .color(piece.color)
                    )
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            start = .now
            pieces = (0..<90).map { _ in
                Piece(
                    x: .random(in: 0...1),
                    delay: .random(in: 0...0.8),
                    speed: .random(in: 0.7...1.3),
                    drift: .random(in: 0...(2 * .pi)),
                    spin: .random(in: -360...360),
                    size: CGSize(width: .random(in: 6...10), height: .random(in: 3...6)),
                    color: colors.randomElement() ?? .accentColor
                )
            }
        }
    }
}

/// A newly earned badge worth celebrating.
struct Celebration: Identifiable, Hashable {
    let badge: Badge

    var id: String { badge.id }

    var headline: LocalizedStringKey {
        switch badge.id {
        case "streak_7": "7 günlük seri! 🔥"
        case "streak_30": "30 gün üst üste! 🔥"
        case "first_session": "İlk adım atıldı!"
        default: "Yeni rozet kazandın!"
        }
    }
}
