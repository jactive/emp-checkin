import Foundation

struct CheckInEvent: Codable, Identifiable {
    let id: UUID
    let personId: String
    let action: Action
    let operatorName: String
    let device: String
    let timestamp: Date

    enum Action: String, Codable {
        case checkIn
        case undo
    }

    enum CodingKeys: String, CodingKey {
        case id, personId, action
        case operatorName = "operator"
        case device, timestamp
    }
}

struct CheckInState {
    var isCheckedIn: Bool = false
    var checkedInAt: Date?
    var checkedInBy: String?
}
