import Foundation

/// "42 dk", "2 sa 15 dk": how long someone focused.
func formattedFocus(_ milliseconds: Int64) -> String {
    let minutes = Int(milliseconds / 60_000)
    guard minutes >= 60 else { return "\(minutes) dk" }
    let hours = minutes / 60
    let rest = minutes % 60
    return rest == 0 ? "\(hours) sa" : "\(hours) sa \(rest) dk"
}
