import Foundation

enum DisambiguationService {
    /// Find duplicate groups that actually need disambiguation.
    /// Only returns groups where members have DIFFERENT contact info (genuinely different people).
    /// If all members share the same contact + phone (duplicate registration), no challenge needed.
    static func findDuplicateGroups(_ athletes: [Athlete]) -> [[Athlete]] {
        Dictionary(grouping: athletes) {
            "\($0.firstName.lowercased())|\($0.lastName.lowercased())|\($0.age)|\($0.gender.lowercased())"
        }.values.filter { group in
            guard group.count > 1 else { return false }
            // Check if they have different contacts — only then do we need disambiguation
            let contacts = Set(group.map { "\($0.contactName.lowercased())|\($0.phoneLast4)" })
            return contacts.count > 1
        }
    }

    static func resolve(input: String, candidates: [Athlete]) -> Athlete? {
        let digits = input.filter(\.isNumber)
        guard digits.count == 4 else { return nil }
        return candidates.first(where: { $0.phoneLast4 == digits })
    }
}
