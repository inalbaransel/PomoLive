import SwiftUI

extension View {
    /// Presents a native alert whenever `error` is non-nil and clears it on dismissal.
    func errorAlert(_ error: Binding<LibraryError?>) -> some View {
        alert(
            isPresented: Binding(get: { error.wrappedValue != nil }, set: { if !$0 { error.wrappedValue = nil } }),
            error: error.wrappedValue
        ) { _ in
            Button("Tamam", role: .cancel) {}
        } message: { error in
            Text(error.errorDescription ?? "")
        }
    }
}
