import SwiftUI

/// Built-in categories for reference, plus the reader's own ones to add or delete.
struct CategoriesView: View {
    @Environment(AppModel.self) private var app
    @State private var isAdding = false
    @State private var error: LibraryError?

    var body: some View {
        List {
            Section {
                ForEach(app.categories.custom) { category in
                    Label { Text(category.name) } icon: { EmojiTile(emoji: category.emoji, size: 30) }
                }
                .onDelete { offsets in
                    let doomed = offsets.map { app.categories.custom[$0] }
                    Task {
                        for category in doomed {
                            do { try await app.categories.delete(category) } catch { self.error = LibraryError(error) }
                        }
                    }
                }
                Button("Kategori Ekle", systemImage: "plus") { isAdding = true }
            } header: {
                Text("Benim kategorilerim")
            } footer: {
                Text("Silinen kategoriler geçmiş oturumlarında adıyla görünmeye devam eder.")
            }

            Section("Hazır kategoriler") {
                ForEach(app.categories.builtIn) { category in
                    Label { Text(category.name) } icon: { EmojiTile(emoji: category.emoji, size: 30) }
                }
            }
        }
        .navigationTitle("Kategoriler")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { EditButton().disabled(app.categories.custom.isEmpty) }
        .sheet(isPresented: $isAdding) {
            CategoryEditorSheet { _ in }
                .presentationDetents([.medium, .large])
        }
        .task(id: app.connection) {
            if app.connection == .online { await app.categories.refresh() }
        }
        .errorAlert($error)
    }
}
