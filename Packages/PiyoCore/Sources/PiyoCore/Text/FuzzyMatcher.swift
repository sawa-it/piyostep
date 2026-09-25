import Foundation

/// 表記揺れ・発音の揺れを許容した文字列一致。
public enum FuzzyMatcher {

    /// 一致の強さ。
    public enum MatchStrength: Int, Comparable, Sendable {
        case none = 0
        /// ゆるい一致（距離 1 〜 2）。幼児の発話としては正解扱いにする。
        case approximate = 1
        /// 正規化後に完全一致
        case exact = 2

        public static func < (lhs: MatchStrength, rhs: MatchStrength) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    /// レーベンシュタイン距離。
    public static func levenshteinDistance(_ lhs: String, _ rhs: String) -> Int {
        let source = Array(lhs)
        let target = Array(rhs)
        if source.isEmpty { return target.count }
        if target.isEmpty { return source.count }

        var previous = Array(0 ... target.count)
        var current = [Int](repeating: 0, count: target.count + 1)

        for i in 1 ... source.count {
            current[0] = i
            for j in 1 ... target.count {
                let substitutionCost = source[i - 1] == target[j - 1] ? 0 : 1
                current[j] = min(
                    previous[j] + 1,            // 削除
                    current[j - 1] + 1,         // 挿入
                    previous[j - 1] + substitutionCost // 置換
                )
            }
            previous = current
        }
        return previous[target.count]
    }

    /// 文字列長に応じた許容距離（日本語）。
    public static func allowedDistanceJapanese(for candidateLength: Int) -> Int {
        switch candidateLength {
        case 0 ... 2: return 0
        case 3 ... 4: return 1
        default: return 2
        }
    }

    /// 文字列長に応じた許容距離（英語）。
    public static func allowedDistanceEnglish(for candidateLength: Int) -> Int {
        switch candidateLength {
        case 0 ... 2: return 0
        case 3 ... 4: return 1
        default: return 2
        }
    }

    /// 日本語の候補群に対する一致判定。
    public static func matchJapanese(input: String, candidates: [String]) -> MatchStrength {
        let normalizedInput = JapaneseTextNormalizer.normalize(input)
        guard !normalizedInput.isEmpty else { return .none }

        let looseInput = JapaneseTextNormalizer.looseKey(input)
        var best = MatchStrength.none

        for candidate in candidates {
            let normalizedCandidate = JapaneseTextNormalizer.normalize(candidate)
            if normalizedCandidate.isEmpty { continue }
            if normalizedCandidate == normalizedInput {
                return .exact
            }
            let looseCandidate = JapaneseTextNormalizer.looseKey(candidate)
            if !looseCandidate.isEmpty, looseCandidate == looseInput {
                best = max(best, .exact)
                continue
            }
            // 候補が入力に含まれている場合（「こたえはあです」→「あ」）も一致とみなす。
            if normalizedCandidate.count >= 2, normalizedInput.contains(normalizedCandidate) {
                best = max(best, .approximate)
                continue
            }
            let distance = levenshteinDistance(looseInput, looseCandidate)
            if distance <= allowedDistanceJapanese(for: looseCandidate.count) {
                best = max(best, .approximate)
            }
        }
        return best
    }

    /// 英語の候補群に対する一致判定。
    public static func matchEnglish(input: String, candidates: [String]) -> MatchStrength {
        let normalizedInput = EnglishTextNormalizer.normalize(input)
        guard !normalizedInput.isEmpty else { return .none }

        var best = MatchStrength.none
        for candidate in candidates {
            let normalizedCandidate = EnglishTextNormalizer.normalize(candidate)
            if normalizedCandidate.isEmpty { continue }
            if normalizedCandidate == normalizedInput {
                return .exact
            }
            // 冠詞や複数形を落とした比較
            let strippedInput = EnglishTextNormalizer.stripArticlesAndPlural(normalizedInput)
            let strippedCandidate = EnglishTextNormalizer.stripArticlesAndPlural(normalizedCandidate)
            if strippedInput == strippedCandidate {
                return .exact
            }
            if normalizedInput.split(separator: " ").contains(where: { String($0) == normalizedCandidate }) {
                best = max(best, .approximate)
                continue
            }
            let distance = levenshteinDistance(strippedInput, strippedCandidate)
            if distance <= allowedDistanceEnglish(for: strippedCandidate.count) {
                best = max(best, .approximate)
            }
        }
        return best
    }
}
