import Foundation

/// 日本語の数の読み（ひらがな）と数値を相互変換する。0 〜 999 に対応。
public enum JapaneseNumberParser {

    /// 位取りのマーカー。長いものから照合する。
    private static let hundredMarkers = ["ひゃく", "びゃく", "ぴゃく"]
    private static let tenMarkers = ["じゅう", "じゅっ", "じっ", "じゅ"]

    /// 数詞。長いものから照合するため、照合時に長さ降順に並べ替える。
    private static let digitWords: [(String, Int)] = [
        ("ぜろ", 0), ("れい", 0), ("まる", 0),
        ("いち", 1), ("いっ", 1),
        ("に", 2),
        ("さん", 3),
        ("よん", 4), ("よ", 4), ("し", 4),
        ("ご", 5),
        ("ろく", 6), ("ろっ", 6),
        ("なな", 7), ("しち", 7),
        ("はち", 8), ("はっ", 8),
        ("きゅう", 9), ("きゅ", 9), ("く", 9)
    ]

    private static let sortedDigitWords: [(String, Int)] = digitWords.sorted { $0.0.count > $1.0.count }

    /// 正規化済み（ひらがな or 数字）のテキストから数値を取り出す。
    /// 数値として解釈できなければ nil。
    public static func parse(_ text: String) -> Int? {
        let normalized = JapaneseTextNormalizer.normalize(text)
        guard !normalized.isEmpty else { return nil }

        // アラビア数字が含まれていれば最初の連続した数字列を使う。
        if let digits = firstDigitRun(in: normalized) {
            return digits
        }
        return parseKana(normalized)
    }

    /// 文字列中の最初の連続した半角数字を整数として返す。
    public static func firstDigitRun(in text: String) -> Int? {
        var buffer = ""
        for character in text {
            if character.isASCII, character.isNumber {
                buffer.append(character)
            } else if !buffer.isEmpty {
                break
            }
        }
        guard !buffer.isEmpty else { return nil }
        return Int(buffer)
    }

    /// ひらがなの数詞を解析する。解釈できる部分がなければ nil。
    public static func parseKana(_ text: String) -> Int? {
        var remaining = Substring(text)
        var total = 0
        var current = 0
        var matchedAnything = false

        while !remaining.isEmpty {
            if let marker = hundredMarkers.first(where: { remaining.hasPrefix($0) }) {
                total += (current == 0 ? 1 : current) * 100
                current = 0
                matchedAnything = true
                remaining = remaining.dropFirst(marker.count)
                continue
            }
            if let marker = tenMarkers.first(where: { remaining.hasPrefix($0) }) {
                total += (current == 0 ? 1 : current) * 10
                current = 0
                matchedAnything = true
                remaining = remaining.dropFirst(marker.count)
                continue
            }
            if let (word, value) = sortedDigitWords.first(where: { remaining.hasPrefix($0.0) }) {
                current = value
                matchedAnything = true
                remaining = remaining.dropFirst(word.count)
                continue
            }
            // 解釈できない文字はここで打ち切る（末尾の助数詞など）。
            break
        }

        guard matchedAnything else { return nil }
        return total + current
    }

    /// 数値の代表的な読み（ひらがな）。
    public static func reading(for value: Int) -> String {
        readings(for: value).first ?? String(value)
    }

    /// 数値に対して受け入れる読みの候補（先頭が代表的な読み）。
    public static func readings(for value: Int) -> [String] {
        guard value >= 0, value <= 999 else { return [String(value)] }
        if value == 0 { return ["ぜろ", "れい", "まる"] }

        if value < 10 { return onesReadings(value) }

        if value < 100 {
            let tens = value / 10
            let ones = value % 10
            let tensParts: [String] = tens == 1 ? ["じゅう", "じゅっ"] : onesReadings(tens).map { "\($0)じゅう" }
            if ones == 0 { return tensParts }
            var result: [String] = []
            for tensPart in tensParts {
                for onesPart in onesReadings(ones) {
                    result.append("\(tensPart)\(onesPart)")
                }
            }
            return result
        }

        let hundreds = value / 100
        let rest = value % 100
        let hundredParts = hundredReadings(hundreds)
        if rest == 0 { return hundredParts }
        var result: [String] = []
        for hundredPart in hundredParts {
            for restPart in readings(for: rest) {
                result.append("\(hundredPart)\(restPart)")
            }
        }
        return result
    }

    private static func onesReadings(_ value: Int) -> [String] {
        switch value {
        case 1: return ["いち"]
        case 2: return ["に"]
        case 3: return ["さん"]
        case 4: return ["よん", "し", "よ"]
        case 5: return ["ご"]
        case 6: return ["ろく"]
        case 7: return ["なな", "しち"]
        case 8: return ["はち"]
        case 9: return ["きゅう", "く"]
        default: return [String(value)]
        }
    }

    private static func hundredReadings(_ hundreds: Int) -> [String] {
        switch hundreds {
        case 1: return ["ひゃく"]
        case 3: return ["さんびゃく", "さんひゃく"]
        case 6: return ["ろっぴゃく", "ろくひゃく"]
        case 8: return ["はっぴゃく", "はちひゃく"]
        default:
            return onesReadings(hundreds).map { "\($0)ひゃく" }
        }
    }
}
