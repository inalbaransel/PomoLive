import Foundation

extension Locale {
    /// The language the app is actually running in, with the device's region for everything else.
    /// Formatting with `.current` instead would mix languages whenever the device language and
    /// region disagree (English text with "42 dk." or "ÖÖ 1:28" on an English phone set to Turkey).
    static let app: Locale = {
        let language = Bundle.main.preferredLocalizations.first ?? "tr"
        var components = Locale.Components(locale: .current)
        components.languageComponents = Locale.Language.Components(identifier: language)
        return Locale(components: components)
    }()
}
