import SwiftUI

/// What to do at this desk: pomodoro or stopwatch, which category, and an optional note.
/// Remembers the last choices so sitting down again is one tap.
struct SessionSetupSheet: View {
    let desk: LayoutDesk
    let onStart: (TimerSetup, FocusCategory, String?) async -> Bool

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Preferences.defaultMode) private var modeRawValue = TimerMode.pomodoro.rawValue
    @AppStorage(Preferences.pomodoroFocusMinutes) private var focusMinutes = 25
    @AppStorage(Preferences.pomodoroBreakMinutes) private var breakMinutes = 5
    @AppStorage(Preferences.lastCategoryKey) private var categoryKey = "software"
    @State private var note = ""
    @State private var isStarting = false
    @State private var isCreatingCategory = false

    private static let presets: [(focus: Int, rest: Int)] = [(25, 5), (50, 10), (90, 15)]

    private var mode: TimerMode { TimerMode(rawValue: modeRawValue) ?? .pomodoro }
    private var selectedCategory: FocusCategory? { app.categories.all.first { $0.key == categoryKey } ?? app.categories.all.first }
    private var trimmedNote: String { note.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Mod", selection: $modeRawValue) {
                        Label("Pomodoro", systemImage: "timer").tag(TimerMode.pomodoro.rawValue)
                        Label("Kronometre", systemImage: "stopwatch").tag(TimerMode.stopwatch.rawValue)
                    }
                    .pickerStyle(.segmented)
                } footer: {
                    Text(mode == .pomodoro
                        ? "Odak ve mola sırayla döner; molalar kendiliğinden başlar."
                        : "Süre sen durdurana kadar işler; istediğinde ara verirsin.")
                }

                if mode == .pomodoro {
                    Section("Süre") {
                        HStack(spacing: 8) {
                            ForEach(Self.presets, id: \.focus) { preset in
                                let isSelected = preset.focus == focusMinutes && preset.rest == breakMinutes
                                Button {
                                    focusMinutes = preset.focus
                                    breakMinutes = preset.rest
                                } label: {
                                    Text("\(preset.focus)/\(preset.rest)")
                                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .selectableBackground(isSelected, in: .capsule)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("\(preset.focus) dakika odak, \(preset.rest) dakika mola")
                                .accessibilityAddTraits(isSelected ? .isSelected : [])
                            }
                        }
                        Stepper("Odak: \(focusMinutes) dk", value: $focusMinutes, in: 5...180, step: 5)
                        Stepper("Mola: \(breakMinutes) dk", value: $breakMinutes, in: 1...60)
                    }
                }

                Section("Kategori") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], spacing: 8) {
                        ForEach(app.categories.all) { category in
                            CategoryChip(category: category, isSelected: category.key == selectedCategory?.key) {
                                categoryKey = category.key
                            }
                        }
                        Button { isCreatingCategory = true } label: {
                            Label("Yeni", systemImage: "plus")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .selectableBackground(false, in: .capsule)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 4)
                    .animation(.spring(duration: 0.3), value: categoryKey)
                }

                Section("Not") {
                    TextField("Ne üzerinde çalışacaksın? (isteğe bağlı)", text: $note)
                        .onChange(of: note) { note = String(note.prefix(48)) }
                }
            }
            .animation(.smooth, value: mode)
            .navigationTitle("Masa \(desk.number)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç", systemImage: "xmark", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isStarting {
                        ProgressView()
                    } else {
                        Button("Başla", systemImage: "play.fill", action: start)
                            .disabled(selectedCategory == nil)
                    }
                }
            }
            .sheet(isPresented: $isCreatingCategory) {
                CategoryEditorSheet { created in categoryKey = created.key }
                    .presentationDetents([.medium, .large])
            }
            .task { if app.categories.all.isEmpty { await app.categories.refresh() } }
        }
    }

    private func start() {
        guard let category = selectedCategory else { return }
        isStarting = true
        let setup: TimerSetup = mode == .pomodoro ? .pomodoro(focusMinutes: focusMinutes, breakMinutes: breakMinutes) : .stopwatch
        Task {
            defer { isStarting = false }
            if await onStart(setup, category, trimmedNote.isEmpty ? nil : trimmedNote) { dismiss() }
        }
    }
}

struct CategoryChip: View {
    let category: FocusCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: category.symbol)
                    .foregroundStyle(category.color.color)
                Text(category.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 6)
            .selectableBackground(isSelected, in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
