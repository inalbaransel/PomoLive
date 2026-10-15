import SwiftUI

/// Creates one of the reader's own categories: a name, a color and a symbol.
struct CategoryEditorSheet: View {
    let onCreated: (FocusCategory) -> Void

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var symbol = "music.note"
    @State private var color = GlyphColor.red
    @State private var isSaving = false
    @State private var error: LibraryError?

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 16) {
                        GlyphIcon(symbol: symbol, color: color, size: 84)
                            .contentTransition(.symbolEffect(.replace))
                        TextField("Kategori Adı", text: $name)
                            .font(.title3.weight(.semibold))
                            .multilineTextAlignment(.center)
                            .padding(.vertical, 10)
                            .background(.fill.tertiary, in: .rect(cornerRadius: 12))
                            .onChange(of: name) { name = String(name.prefix(24)) }
                    }
                    .padding(.vertical, 8)
                }

                GlyphPicker(symbol: $symbol, color: $color)
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
                onCreated(try await app.categories.create(name: trimmedName, symbol: symbol, color: color))
                dismiss()
            } catch {
                self.error = LibraryError(error)
            }
        }
    }
}
