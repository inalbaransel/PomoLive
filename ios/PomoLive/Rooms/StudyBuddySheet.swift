import SwiftUI

/// "Çalışma Arkadaşı Bul": pick a pomodoro length and what you will work on, wait a moment for
/// someone asking for the same, and both of you are seated side by side to start together.
struct StudyBuddySheet: View {
    let onMatched: (MatchFound) -> Void
    let onSitAnyway: () -> Void

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Preferences.lastCategoryKey) private var categoryKey = "study"
    @State private var focusMinutes = 25

    var body: some View {
        @Bindable var match = app.match

        NavigationStack {
            VStack(spacing: 24) {
                switch app.match.state {
                case .idle: setup
                case .waiting(let since): waiting(since: since)
                case .found(let match): matched(match)
                case .timedOut: timedOut
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .animation(.smooth, value: app.match.state)
            .navigationTitle("Çalışma Arkadaşı")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Kapat", systemImage: "xmark", role: .close) {
                        app.match.cancel()
                        dismiss()
                    }
                }
            }
            .errorAlert($match.error)
        }
        .interactiveDismissDisabled(app.match.state != .idle)
        .sensoryFeedback(.success, trigger: app.match.state) { _, new in
            if case .found = new { true } else { false }
        }
        .onDisappear { if case .waiting = app.match.state { app.match.cancel() } }
    }

    private var setup: some View {
        VStack(spacing: 24) {
            Text("Seninle aynı anda başlayacak biriyle eşleş. Konuşmanız gerekmez; yan yana oturup birlikte odaklanırsınız.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Picker("Süre", selection: $focusMinutes) {
                Text("25 dk odak").tag(25)
                Text("50 dk odak").tag(50)
            }
            .pickerStyle(.segmented)

            Picker(selection: $categoryKey) {
                ForEach(app.categories.all) { category in
                    Label(category.displayName, systemImage: category.symbol).tag(category.key)
                }
            } label: {
                Text("Ne çalışacaksın?")
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 14))

            Button {
                Task { await app.match.search(focusMinutes: focusMinutes, categoryKey: categoryKey) }
            } label: {
                Label("Arkadaş Ara", systemImage: "person.2.wave.2.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.extraLarge)
            .fontWeight(.semibold)
        }
    }

    private func waiting(since: Date) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "person.2.wave.2.fill")
                .font(.system(size: 52))
                .foregroundStyle(Color.accentColor)
                .symbolEffect(.variableColor.iterative, options: .repeat(.continuous))
                .padding(.top, 12)
            Text("Arkadaş aranıyor…")
                .font(.title3.weight(.semibold))
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let left = max(0, 120 - Int(context.date.timeIntervalSince(since)))
                Text("En fazla \(Duration.seconds(left), format: .time(pattern: .minuteSecond)) sürer")
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Button("Vazgeç", role: .cancel) { app.match.cancel() }
                .buttonStyle(.bordered)
        }
    }

    private func matched(_ match: MatchFound) -> some View {
        VStack(spacing: 16) {
            Image(decorative: SpriteCache.shared.avatar(AvatarSprite(id: match.partner.avatarSpriteId)), scale: 1)
                .resizable()
                .interpolation(.none)
                .frame(width: 56, height: 56)
                .frame(width: 92, height: 92)
                .background(.fill.tertiary, in: .circle)
                .padding(.top, 8)
            Text("\(match.partner.displayName) ile eşleştin!")
                .font(.title3.weight(.bold))
                .multilineTextAlignment(.center)
            Text("Yan yana iki masa ayrıldı. \(match.focusMinutes) dakikalık odak birlikte başlıyor.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .task {
            try? await Task.sleep(for: .seconds(1.6))
            app.match.reset()
            onMatched(match)
            dismiss()
        }
    }

    private var timedOut: some View {
        VStack(spacing: 16) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
                .padding(.top, 12)
            Text("Şu an eşleşecek kimse yok")
                .font(.title3.weight(.semibold))
            Text("Biraz sonra tekrar deneyebilir ya da genel salonda bir masaya oturup başkalarıyla çalışabilirsin.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 12) {
                Button("Tekrar Dene") {
                    Task { await app.match.search(focusMinutes: focusMinutes, categoryKey: categoryKey) }
                }
                .buttonStyle(.bordered)
                Button("Salona Otur") {
                    app.match.reset()
                    onSitAnyway()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .controlSize(.large)
        }
    }
}
