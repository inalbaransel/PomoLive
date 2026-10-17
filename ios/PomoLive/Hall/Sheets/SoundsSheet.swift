import SwiftUI

/// Picks a background soundscape and its volume. Tapping the playing sound stops it.
struct SoundsSheet: View {
    let theme: RoomTheme?

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var showsPaywall = false

    var body: some View {
        @Bindable var player = app.sounds

        NavigationStack {
            Form {
                Section {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                        ForEach(AmbientSound.allCases) { sound in tile(sound) }
                    }
                    .padding(.vertical, 6)
                } footer: {
                    if let theme {
                        Text("Bu oda için önerilen: \(Text(AmbientSound.suggested(for: theme).title))")
                    }
                }

                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "speaker.fill").foregroundStyle(.secondary)
                        Slider(value: $player.volume, in: 0...1)
                        Image(systemName: "speaker.wave.3.fill").foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Ses Seviyesi")
                } footer: {
                    Text("Ses, telefon kilitliyken ve diğer uygulamalardaki müzikle birlikte çalmaya devam eder.")
                }
            }
            .navigationTitle("Odak Sesleri")
            .plusPaywall(isPresented: $showsPaywall)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Kapat", systemImage: "xmark", role: .close) { dismiss() }
                }
                if app.sounds.current != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Durdur", systemImage: "stop.fill") { app.sounds.stop() }
                    }
                }
            }
        }
    }

    private func tile(_ sound: AmbientSound) -> some View {
        let isPlaying = app.sounds.current == sound
        let isLocked = !app.plus.isActive && PlusCatalog.sounds.contains(sound)
        return Button {
            if isLocked { return showsPaywall = true }
            app.sounds.toggle(sound)
        } label: {
            VStack(spacing: 8) {
                Image(systemName: sound.symbol)
                    .font(.title2)
                    .foregroundStyle(isPlaying ? .white : sound.color)
                    .symbolEffect(.variableColor.iterative, isActive: isPlaying)
                    .frame(height: 30)
                Text(sound.title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(isPlaying ? .white : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(isPlaying ? AnyShapeStyle(sound.color.gradient) : AnyShapeStyle(.fill.tertiary), in: .rect(cornerRadius: 16))
            .overlay(alignment: .topTrailing) {
                if isLocked { PlusBadge().padding(6) }
            }
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isPlaying)
        .accessibilityAddTraits(isPlaying ? .isSelected : [])
        .animation(.smooth, value: isPlaying)
    }
}
