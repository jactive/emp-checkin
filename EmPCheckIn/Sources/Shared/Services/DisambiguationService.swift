import Foundation

enum DisambiguationService {
    /// Find duplicate groups by name only (regardless of age/gender).
    /// Returns groups of athletes with the same full name who have DIFFERENT phone numbers.
    /// This handles cases like "Ethan Li" appearing in ages 3, 6, 7, 9 — all different kids.
    static func findDuplicateGroups(_ athletes: [Athlete]) -> [[Athlete]] {
        // Group by name only (case-insensitive)
        Dictionary(grouping: athletes) {
            "\($0.firstName.lowercased())|\($0.lastName.lowercased())"
        }.values.filter { group in
            guard group.count > 1 else { return false }
            // Check if they have different phone last 4 digits — only then do we need disambiguation
            let phones = Set(group.map { $0.phoneLast4 })
            return phones.count > 1
        }
    }

    static func resolve(input: String, candidates: [Athlete]) -> Athlete? {
        let digits = input.filter(\.isNumber)
        guard digits.count == 4 else { return nil }
        return candidates.first(where: { $0.phoneLast4 == digits })
    }
}
