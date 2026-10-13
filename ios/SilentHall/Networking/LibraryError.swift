import Foundation

enum LibraryError: LocalizedError, Equatable, Sendable {
    case offline
    case timeout
    case malformedResponse
    case server(code: String, message: String)

    var isUnauthorized: Bool {
        if case .server(code: "UNAUTHORIZED", _) = self { true } else { false }
    }

    var errorDescription: String? {
        switch self {
        case .offline: "Sunucuya bağlı değilsin."
        case .timeout: "Sunucu zamanında yanıt vermedi."
        case .malformedResponse: "Sunucudan beklenmeyen bir yanıt geldi."
        case .server(let code, let message):
            switch code {
            case "DESK_TAKEN": "Bu masaya az önce başka biri oturdu."
            case "ROOM_NOT_FOUND": "Bu koda sahip bir salon bulunamadı."
            case "UNAUTHORIZED": "Oturumun sona erdi, lütfen tekrar giriş yap."
            case "NOT_SEATED": "Şu anda bir masada oturmuyorsun."
            case "INVALID_PAYLOAD": "Girdiğin bilgiler geçersiz."
            default: message
            }
        }
    }
}
