import Foundation

enum RestoreCodeGenerator {
    case email
    case sms
    case backupCode

    func generate() -> String {
        switch self {
        case .email:
            return UUID().uuidString.prefix(6).uppercased()
        case .sms:
            return String(Int.random(in: 100000...999999))
        case .backupCode:
            return UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(8).uppercased()
        }
    }
}
