import SwiftUI

/// The reader's to-do list in the style of Reminders: a quick-add field on top, open tasks with
/// round checkboxes, and today's finished tasks below with a strikethrough.
struct TasksView: View {
    @Environment(AppModel.self) private var app
    @State private var newTitle = ""
    @FocusState private var isAdding: Bool

    var body: some View {
        @Bindable var tasks = app.tasks

        List {
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.accentColor)
                    TextField("Yeni görev", text: $newTitle)
                        .focused($isAdding)
                        .submitLabel(.done)
                        .onSubmit(add)
                }
            }

            if app.tasks.openTasks.isEmpty, app.tasks.doneTasks.isEmpty, app.tasks.hasLoaded {
                Section {
                    ContentUnavailableView(
                        "Görev listen boş",
                        systemImage: "checklist",
                        description: Text("Bu oturumda neyi bitirmek istediğini yaz; tamamladıkça işaretle.")
                    )
                }
            }

            if !app.tasks.openTasks.isEmpty {
                Section {
                    ForEach(app.tasks.openTasks) { task in row(task) }
                } header: {
                    Text("Yapılacaklar · \(app.tasks.openTasks.count)")
                }
            }

            if !app.tasks.doneTasks.isEmpty {
                Section {
                    ForEach(app.tasks.doneTasks) { task in row(task) }
                } header: {
                    Text("Tamamlananlar · \(app.tasks.doneTasks.count)")
                } footer: {
                    Text("Tamamlanan görevler bir gün sonra listeden kalkar.")
                }
            }
        }
        .animation(.smooth, value: app.tasks.tasks)
        .navigationTitle("Görevler")
        .toolbar {
            if isAdding {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ekle", systemImage: "checkmark", action: add)
                        .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .refreshable { await app.tasks.refresh() }
        .task(id: app.connection) {
            if app.connection == .online { await app.tasks.refresh() }
        }
        .errorAlert($tasks.error)
    }

    private func row(_ task: FocusTask) -> some View {
        Button {
            Task { await app.tasks.toggle(task) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.isDone ? Color.accentColor : .secondary)
                    .contentTransition(.symbolEffect(.replace))
                Text(task.title)
                    .strikethrough(task.isDone)
                    .foregroundStyle(task.isDone ? .secondary : .primary)
                Spacer(minLength: 0)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.success, trigger: task.isDone) { _, done in done }
        .swipeActions {
            Button("Sil", systemImage: "trash", role: .destructive) {
                Task { await app.tasks.delete(task) }
            }
        }
        .accessibilityAddTraits(task.isDone ? .isSelected : [])
    }

    private func add() {
        let title = newTitle
        newTitle = ""
        Task { await app.tasks.add(title) }
    }
}
