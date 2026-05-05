import Foundation

enum SearchService {
    static func searchAthletes(_ athletes: [Athlete], query: String) -> [Athlete] {
        let tokens = tokenize(query)
        guard !tokens.isEmpty else { return athletes }
        return athletes
            .compactMap { a in matchScore(tokens, a.searchTokens).map { (a, $0) } }
            .sorted { $0.1 > $1.1 }
            .map(\.0)
    }

    static func searchVolunteers(_ volunteers: [Volunteer], query: String) -> [Volunteer] {
        let tokens = tokenize(query)
        guard !tokens.isEmpty else { return volunteers }
        return volunteers
            .compactMap { v in matchScore(tokens, v.searchTokens).map { (v, $0) } }
            .sorted { $0.1 > $1.1 }
            .map(\.0)
    }

    private static func tokenize(_ input: String) -> [String] {
        input.lowercased().split(separator: " ").map(String.init).filter { !$0.isEmpty }
    }

    private static func matchScore(_ query: [String], _ target: [String]) -> Double? {
        var total: Double = 0
        for q in query {
            var best: Double = 0
            for t in target {
                if q == t { best = max(best, 10) }
                else if t.hasPrefix(q) { best = max(best, 5 + Double(q.count) / Double(t.count) * 4) }
                else if q.hasPrefix(t) { best = max(best, 3) }
                else {
                    let d = levenshtein(q, t)
                    let m = max(q.count, t.count)
                    if m > 0 && d <= 2 && d < m / 2 {
                        best = max(best, Double(m - d) / Double(m) * 4)
                    }
                }
            }
            if best == 0 { return nil }
            total += best
        }
        return total
    }

    private static func levenshtein(_ s1: String, _ s2: String) -> Int {
        let a = Array(s1), b = Array(s2)
        let m = a.count, n = b.count
        if m == 0 { return n }; if n == 0 { return m }
        var mat = [[Int]](repeating: [Int](repeating: 0, count: n+1), count: m+1)
        for i in 0...m { mat[i][0] = i }
        for j in 0...n { mat[0][j] = j }
        for i in 1...m { for j in 1...n {
            let c = a[i-1] == b[j-1] ? 0 : 1
            mat[i][j] = min(mat[i-1][j]+1, mat[i][j-1]+1, mat[i-1][j-1]+c)
        }}
        return mat[m][n]
    }
}
