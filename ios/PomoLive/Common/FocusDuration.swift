import Foundation

/// "42 dk", "2 sa 15 dk" / "42 min", "2 hr, 15 min": how long someone focused, in the reader's language.
func formattedFocus(_ milliseconds: Int64) -> String {
    let minutes = Int64(milliseconds / 60_000) * 60
    return Duration.seconds(minutes).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated).locale(.app))
}
