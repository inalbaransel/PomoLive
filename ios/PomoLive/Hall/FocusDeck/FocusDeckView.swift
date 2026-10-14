import SwiftUI

/// The reader's control panel while seated: a Clock-style progress ring, the phase and its actions.
/// Swipe down to melt it into a capsule so the hall can be explored full-screen.
struct FocusDeckView: View {
    let desk: DeskRecord
    let clock: ServerClock
    @Binding var isExpanded: Bool
    let onChangeTimer: (ChangeTimerCommand.Action) -> Void
    let onFinish: () -> Void

    @Namespace private var glassNamespace
    @State private var confirmsFinish = false

    var body: some View {
        GlassEffectContainer(spacing: 24) {
            if isExpanded {
                expandedDeck
                    .glassEffect(.regular, in: .rect(cornerRadius: 34))
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
        .confirmationDialog("Oturum bitsin mi?", isPresented: $confirmsFinish, titleVisibility: .visible) {
            Button("Oturumu Bitir", role: .destructive, action: onFinish)
        } message: {
            Text("Masadan kalkarsın; odak süren geçmişine kaydedilir.")
        }
    }

    private var expandedDeck: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            let reading = desk.timer.reading(at: clock.now)
            VStack(spacing: 18) {
                header
                ProgressRing(reading: reading, timer: desk.timer, clock: clock)
                actions(for: reading)
            }
            .padding(20)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(decorative: SpriteCache.shared.avatar(AvatarSprite(id: desk.avatarSpriteId)), scale: 1)
                .resizable()
                .interpolation(.none)
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(desk.category.emoji) \(desk.category.name)")
                    .font(.headline)
                Text(desk.note ?? "Masa \(desk.number) · \(desk.sessionNumber). seans")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
            Spacer(minLength: 0)
            Button("Küçült", systemImage: "chevron.down") { isExpanded = false }
                .labelStyle(.iconOnly)
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
        }
    }

    private func actions(for reading: TimerReading) -> some View {
        let (title, symbol, action): (String, String, ChangeTimerCommand.Action) = switch (desk.timer.mode, reading.phase) {
        case (.pomodoro, .focus): ("Molaya Geç", "cup.and.saucer.fill", .rest)
        case (.pomodoro, .rest): ("Molayı Atla", "forward.fill", .resume)
        case (.stopwatch, .focus): ("Duraklat", "pause.fill", .rest)
        case (.stopwatch, .rest): ("Devam Et", "play.fill", .resume)
        }
        return HStack(spacing: 12) {
            Button { onChangeTimer(action) } label: {
                Label(title, systemImage: symbol)
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(.black)
            }
            .buttonStyle(.glassProminent)
            .contentTransition(.symbolEffect(.replace))

            Button(role: .destructive) { confirmsFinish = true } label: {
                Label("Bitir", systemImage: "stop.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .controlSize(.large)
    }

    private var compactCapsule: some View {
        Button { isExpanded = true } label: {
            HStack(spacing: 10) {
                Image(decorative: SpriteCache.shared.avatar(AvatarSprite(id: desk.avatarSpriteId)), scale: 1)
                    .resizable()
                    .interpolation(.none)
                    .frame(width: 26, height: 26)
                Text(desk.category.emoji)
                TimerText(timer: desk.timer, clock: clock)
                    .font(.system(.headline, design: .monospaced))
                Text(desk.category.name)
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
}

/// Clock-app style ring: fills through the pomodoro phase, or once per hour for a stopwatch.
private struct ProgressRing: View {
    let reading: TimerReading
    let timer: DeskTimer
    let clock: ServerClock

    private var progress: Double {
        let now = clock.now
        if let end = reading.phaseEndsAt {
            let length = Double(end - reading.phaseStartedAt)
            return length > 0 ? Double(now - reading.phaseStartedAt) / length : 0
        }
        return Double(reading.focusedMs % 3_600_000) / 3_600_000
    }

    private var tint: Color { reading.phase == .focus ? .accentColor : .mint }

    private var phaseTitle: String {
        switch (timer.mode, reading.phase) {
        case (.pomodoro, .focus): "Odak"
        case (.pomodoro, .rest): "Mola"
        case (.stopwatch, .focus): "Çalışıyor"
        case (.stopwatch, .rest): "Duraklatıldı"
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.2), lineWidth: 12)
            Circle()
                .trim(from: 0, to: min(max(progress, 0.001), 1))
                .stroke(tint, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: progress)
            VStack(spacing: 4) {
                Text(phaseTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                TimerText(timer: timer, clock: clock)
                    .font(.system(size: 42, weight: .bold, design: .monospaced))
                Text("Toplam \(formattedFocus(reading.focusedMs)) odak")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 196, height: 196)
        .accessibilityElement(children: .combine)
    }
}
