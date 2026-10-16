import Foundation
import Observation

/// The reader's to-do list. Changes apply locally at once and roll back if the server refuses them.
@MainActor
@Observable
final class TaskStore {
    private(set) var tasks: [FocusTask] = []
    private(set) var hasLoaded = false
    var error: LibraryError?

    @ObservationIgnored private let socket: LibrarySocket

    init(socket: LibrarySocket) {
        self.socket = socket
    }

    var openTasks: [FocusTask] { tasks.filter { !$0.isDone } }
    var doneTasks: [FocusTask] { tasks.filter(\.isDone) }

    func refresh() async {
        do {
            tasks = try await socket.send(ListTasksCommand()).tasks
            hasLoaded = true
        } catch {
            if !hasLoaded { self.error = LibraryError(error) }
        }
    }

    func add(_ title: String) async {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            tasks.append(try await socket.send(CreateTaskCommand(title: String(trimmed.prefix(120)))).task)
        } catch {
            self.error = LibraryError(error)
        }
    }

    func toggle(_ task: FocusTask) async {
        guard let index = tasks.firstIndex(of: task) else { return }
        let original = tasks[index]
        tasks[index].completedAt = task.isDone ? nil : ServerClock.deviceNow()
        do {
            let saved = try await socket.send(SetTaskDoneCommand(id: task.id, done: !task.isDone)).task
            if let current = tasks.firstIndex(where: { $0.id == saved.id }) { tasks[current] = saved }
        } catch {
            if let current = tasks.firstIndex(where: { $0.id == original.id }) { tasks[current] = original }
            self.error = LibraryError(error)
        }
    }

    func delete(_ task: FocusTask) async {
        guard let index = tasks.firstIndex(of: task) else { return }
        tasks.remove(at: index)
        do {
            _ = try await socket.send(DeleteTaskCommand(id: task.id))
        } catch {
            tasks.insert(task, at: min(index, tasks.count))
            self.error = LibraryError(error)
        }
    }

    func reset() {
        tasks = []
        hasLoaded = false
    }
}
