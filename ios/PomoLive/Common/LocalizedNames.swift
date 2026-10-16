import Foundation

// The server names built-in categories and system halls in Turkish. These map them to the
// reader's language by their stable keys; anything readers named themselves is shown as is.

private func builtInCategoryName(_ key: String) -> String? {
    switch key {
    case "software": String(localized: "Yazılım")
    case "study": String(localized: "Ders Çalışma")
    case "reading": String(localized: "Okuma")
    case "writing": String(localized: "Yazı")
    case "design": String(localized: "Tasarım")
    case "language": String(localized: "Dil Öğrenme")
    case "work": String(localized: "İş")
    case "other": String(localized: "Diğer")
    default: nil
    }
}

/// `pixel-hall-3` → "Piksel Salon 3" / "Pixel Hall 3".
func localizedRoomName(id: String?, name: String) -> String {
    guard let id, id.hasPrefix("pixel-hall-"), let number = Int(id.dropFirst("pixel-hall-".count)) else { return name }
    return String(localized: "Piksel Salon \(number)")
}

extension FocusCategory {
    var displayName: String { builtInCategoryName(key) ?? name }
}

extension CategoryTotal {
    var displayName: String { builtInCategoryName(key) ?? name }
}

extension RoomState {
    var displayName: String { localizedRoomName(id: id, name: name) }
}

extension RoomSummary {
    var displayName: String { localizedRoomName(id: id, name: name) }
}

extension DiscoverRoom {
    var displayName: String { localizedRoomName(id: id, name: name) }
}

extension HistoryEntry {
    var roomDisplayName: String { localizedRoomName(id: roomId, name: roomName) }
}

extension TimerMode {
    var displayName: String {
        switch self {
        case .pomodoro: String(localized: "Pomodoro")
        case .stopwatch: String(localized: "Kronometre")
        }
    }
}
