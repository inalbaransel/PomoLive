import SwiftUI

/// Asks what the reader will work on before taking a free desk.
struct SitDownSheet: View {
    let desk: LayoutDesk
    let onSit: (String) async -> Void

    @Environment(\.dismiss) private var dismiss
    @AppStorage("recentTaskLabels") private var recentLabels = ""
    @State private var taskLabel = ""
    @State private var isSitting = false
    @FocusState private var isFieldFocused: Bool

    private var trimmedLabel: String { taskLabel.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var recents: [String] { recentLabels.split(separator: "\n").map(String.init) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Ne üzerinde çalışacaksın?", text: $taskLabel)
                        .focused($isFieldFocused)
                        .submitLabel(.go)
                        .onSubmit(sit)
                        .onChange(of: taskLabel) { taskLabel = String(taskLabel.prefix(48)) }
                } footer: {
                    Text("Görev etiketin masanın üstünde diğer okurlara görünür.")
                }

                if !recents.isEmpty {
                    Section("Son görevler") {
                        ForEach(recents, id: \.self) { recent in
                            Button(recent) { taskLabel = recent }
                        }
                    }
                }
            }
            .navigationTitle("Masa \(desk.number)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç", systemImage: "xmark", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Otur", systemImage: "checkmark", action: sit)
                        .disabled(trimmedLabel.isEmpty || isSitting)
                }
            }
        }
        .onAppear { isFieldFocused = true }
    }

    private func sit() {
        guard !trimmedLabel.isEmpty, !isSitting else { return }
        isSitting = true
        let label = trimmedLabel
        recentLabels = ([label] + recents.filter { $0 != label }).prefix(4).joined(separator: "\n")
        Task {
            await onSit(label)
            dismiss()
        }
    }
}
