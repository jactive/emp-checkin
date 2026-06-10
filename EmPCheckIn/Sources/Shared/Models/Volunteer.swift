import Foundation

struct Volunteer: Identifiable, Codable, Hashable {
    let id: String
    let volunteerNumber: Int  // Volunteer No. from roster
    let name: String
    let role: String          // Task from main sheet Column A
    let otherRoles: String    // Other roles from main sheet Column D
    let groupName: String     // Group name (from tab name in other sheets)
    let groupInfo: [String]   // Additional info from group sheet ("Header: Value" format)
    let email: String
    let phone: String
    let wechat: String
    
    // For backward compatibility with existing data without group fields
    enum CodingKeys: String, CodingKey {
        case id, volunteerNumber, name, role, otherRoles
        case groupName, groupInfo
        case email, phone, wechat
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        volunteerNumber = try container.decode(Int.self, forKey: .volunteerNumber)
        name = try container.decode(String.self, forKey: .name)
        role = try container.decode(String.self, forKey: .role)
        otherRoles = try container.decode(String.self, forKey: .otherRoles)
        groupName = try container.decodeIfPresent(String.self, forKey: .groupName) ?? ""
        groupInfo = try container.decodeIfPresent([String].self, forKey: .groupInfo) ?? []
        email = try container.decode(String.self, forKey: .email)
        phone = try container.decode(String.self, forKey: .phone)
        wechat = try container.decode(String.self, forKey: .wechat)
    }

    var searchTokens: [String] {
        var tokens = name.lowercased().split(separator: " ").map(String.init)
        // Also searchable by volunteer number
        tokens.append(String(volunteerNumber))
        return tokens
    }

    var phoneLast4: String {
        let digits = phone.filter(\.isNumber)
        guard digits.count >= 4 else { return digits }
        return String(digits.suffix(4))
    }
}
