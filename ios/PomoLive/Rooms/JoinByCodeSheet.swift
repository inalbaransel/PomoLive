import SwiftUI

/// Enter a friend's 6-character room code.
struct JoinByCodeSheet: View {
    let onJoin: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @FocusState private var isFocused: Bool

    private var normalized: String { code.uppercased().filter { $0.isLetter || $0.isNumber } }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("ABC123", text: $code)
                        .font(.system(.title, design: .monospaced, weight: .bold))
                        .multilineTextAlignment(.center)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .focused($isFocused)
                        .submitLabel(.join)
                        .onSubmit(join)
                        .onChange(of: code) { code = String(normalized.prefix(6)) }
                } footer: {
                    Text("Arkadaşının paylaştığı 6 haneli oda kodu.")
                }
            }
            .navigationTitle("Kodla Katıl")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç", systemImage: "xmark", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Katıl", systemImage: "checkmark", action: join)
                        .disabled(normalized.count != 6)
                }
            }
        }
        .onAppear { isFocused = true }
    }

    private func join() {
        guard normalized.count == 6 else { return }
        onJoin(normalized)
        dismiss()
    }
}
