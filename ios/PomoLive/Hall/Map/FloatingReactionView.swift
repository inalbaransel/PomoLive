import SwiftUI

/// A reaction emoji that pops out of a desk, drifts up and fades away.
struct FloatingReactionView: View {
    let reaction: DeskReaction
    let tile: CGFloat

    @State private var isRising = false
    @State private var isPopped = false

    var body: some View {
        Text(reaction.emoji)
            .font(.system(size: max(tile * 1.1, 22)))
            .scaleEffect(isPopped ? 1 : 0.3)
            .offset(y: isRising ? -tile * 2.6 : 0)
            .opacity(isRising ? 0 : 1)
            .onAppear {
                withAnimation(.spring(duration: 0.4, bounce: 0.55)) { isPopped = true }
                withAnimation(.easeIn(duration: 2).delay(0.3)) { isRising = true }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
