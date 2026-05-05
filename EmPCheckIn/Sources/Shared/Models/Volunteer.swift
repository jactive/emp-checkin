import Foundation

struct Volunteer: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let role: String
    let email: String
    let phone: String

    var searchTokens: [String] {
        name.lowercased().split(separator: " ").map(String.init)
    }

    var phoneLast4: String {
        let digits = phone.filter(\.isNumber)
        guard digits.count >= 4 else { return digits }
        return String(digits.suffix(4))
    }
}
