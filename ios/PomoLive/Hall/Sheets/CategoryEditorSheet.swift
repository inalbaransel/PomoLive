import SwiftUI

/// Creates one of the reader's own categories: a name and an emoji.
struct CategoryEditorSheet: View {
    let onCreated: (FocusCategory) -> Void

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var emoji = Self.emojis[0]
    @State private var isSaving = false
    @State private var error: LibraryError?

    static let emojis = [
        "🎸", "🎹", "🏃", "🧘", "🍳", "📷", "🧮", "🔬", "🧩", "🎬", "📝", "📐",
        "🌍", "🎮", "🧵", "🪴", "🏋️", "♟️", "🎤", "🧑‍💻", "📊", "🗂️", "💡", "❤️",
    ]

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        EmojiTile(emoji: emoji, size: 56)
                        TextField("Kategori adı", text: $name)
                            .font(.title3.weight(.semibold))
                            .onChange(of: name) { name = String(name.prefix(24)) }
                    }
                }
                Section("Simge") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 10) {
                        ForEach(Self.emojis, id: \.self) { option in
                            Button { emoji = option } label: {
                                Text(option)
                                    .font(.title3)
                                    .frame(width: 36, height: 36)
                                    .selectableBackground(emoji == option, in: .circle)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            .navigationTitle("Yeni Kategori")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç", systemImage: "xmark", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Kaydet", systemImage: "checkmark", action: save)
                            .disabled(trimmedName.count < 2)
                    }
                }
            }
            .errorAlert($error)
        }
    }

    private func save() {
        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                onCreated(try await app.categories.create(name: trimmedName, emoji: emoji))
                dismiss()
            } catch {
                self.error = LibraryError(error)
            }
        }
    }
}
