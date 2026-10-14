import Foundation

enum LibraryError: LocalizedError, Equatable, Sendable {
    case offline
    case timeout
    case malformedResponse
    /// Transport failure (DNS, TLS, no network…) with the system's own localized explanation.
    case connectionFailed(reason: String)
    case server(code: String, message: String)

    init(_ error: any Error) {
        self = error as? LibraryError ?? .connectionFailed(reason: error.localizedDescription)
    }

    var isUnauthorized: Bool {
        if case .server(code: "UNAUTHORIZED", _) = self { true } else { false }
    }

    var errorDescription: String? {
        switch self {
        case .offline: "Sunucuya bağlı değilsin."
        case .timeout: "Sunucu zamanında yanıt vermedi."
        case .malformedResponse: "Sunucudan beklenmeyen bir yanıt geldi."
        case .connectionFailed(let reason): "Sunucuya bağlanılamadı. \(reason)"
        case .server(let code, let message):
            switch code {
            case "DESK_TAKEN": "Bu masaya az önce başka biri oturdu."
            case "ROOM_NOT_FOUND": "Oda bulunamadı. Kodu kontrol et ya da oda kapanmış olabilir."
            case "FORBIDDEN": "Bunu yapmaya yetkin yok. Özel odalara kodla girilir."
            case "LIMIT_REACHED": "Sınıra ulaştın. Kullanmadıklarını silip tekrar dene."
            case "NAME_TAKEN": "Bu adda bir kategorin zaten var."
            case "CATEGORY_NOT_FOUND": "Bu kategori artık yok."
            case "NOT_IN_ROOM": "Önce bir odaya gir."
            case "UNAUTHORIZED": "Oturumun sona erdi, lütfen tekrar giriş yap."
            case "NOT_SEATED": "Şu anda bir masada oturmuyorsun."
            case "INVALID_PAYLOAD": "Girdiğin bilgiler geçersiz."
            case "INVALID_CREDENTIALS": "E-posta ya da şifre hatalı."
            case "EMAIL_TAKEN": "Bu e-posta ile zaten bir hesap var. Giriş yapmayı dene."
            case "RATE_LIMITED": "Çok fazla deneme yapıldı. Biraz sonra tekrar dene."
            default: message
            }
        }
    }
}
