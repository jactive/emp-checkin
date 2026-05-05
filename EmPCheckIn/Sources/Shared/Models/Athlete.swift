import Foundation

struct Athlete: Identifiable, Codable, Hashable {
    let id: String
    let firstName: String
    let lastName: String
    let age: Int
    let gender: String
    let events: [String]
    let bibNumber: Int
    let contactName: String
    let contactPhone: String
    let contactWeChat: String
    let contactEmail: String
    let shippingPhone: String

    var fullName: String { "\(firstName) \(lastName)" }

    var searchTokens: [String] {
        [firstName.lowercased(), lastName.lowercased()]
    }

    var phoneLast4: String {
        let digits = shippingPhone.filter(\.isNumber)
        guard digits.count >= 4 else { return digits }
        return String(digits.suffix(4))
    }
}
