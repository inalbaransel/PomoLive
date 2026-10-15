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
        case .offline: String(localized: "Sunucuya bağlı değilsin.")
        case .timeout: String(localized: "Sunucu zamanında yanıt vermedi.")
        case .malformedResponse: String(localized: "Sunucudan beklenmeyen bir yanıt geldi.")
        case .connectionFailed(let reason): String(localized: "Sunucuya bağlanılamadı. \(reason)")
        case .server(let code, let message):
            switch code {
            case "DESK_TAKEN": String(localized: "Bu masaya az önce başka biri oturdu.")
            case "ROOM_NOT_FOUND": String(localized: "Oda bulunamadı. Kodu kontrol et ya da oda kapanmış olabilir.")
            case "FORBIDDEN": String(localized: "Bunu yapmaya yetkin yok. Özel odalara kodla girilir.")
            case "MESSAGE_NOT_FOUND": String(localized: "Bu mesaj artık yok.")
            case "BANNED": String(localized: "Oda sahibi seni bu odadan çıkardı.")
            case "USER_NOT_FOUND": String(localized: "Bu kişinin hesabı artık yok.")
            case "USERNAME_TAKEN": String(localized: "Bu kullanıcı adı alınmış. Başka bir tane dene.")
            case "LIMIT_REACHED": String(localized: "Sınıra ulaştın. Kullanmadıklarını silip tekrar dene.")
            case "NAME_TAKEN": String(localized: "Bu adda bir kategorin zaten var.")
            case "CATEGORY_NOT_FOUND": String(localized: "Bu kategori artık yok.")
            case "NOT_IN_ROOM": String(localized: "Önce bir odaya gir.")
            case "UNAUTHORIZED": String(localized: "Oturumun sona erdi, lütfen tekrar giriş yap.")
            case "NOT_SEATED": String(localized: "Şu anda bir masada oturmuyorsun.")
            case "INVALID_PAYLOAD": String(localized: "Girdiğin bilgiler geçersiz.")
            case "INVALID_CREDENTIALS": String(localized: "E-posta, kullanıcı adı ya da şifre hatalı.")
            case "EMAIL_TAKEN": String(localized: "Bu e-posta ile zaten bir hesap var. Giriş yapmayı dene.")
            case "RATE_LIMITED": String(localized: "Çok fazla deneme yapıldı. Biraz sonra tekrar dene.")
            default: message
            }
        }
    }
}
