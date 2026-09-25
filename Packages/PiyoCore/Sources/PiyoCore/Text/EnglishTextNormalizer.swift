import Foundation

/// 英語の音声認識結果を比較しやすい形に正規化する。
public enum EnglishTextNormalizer {

    /// 小文字化し、英字とスペースだけを残す。
    public static func normalize(_ text: String) -> String {
        let lowered = text.lowercased()
        var result = ""
        var lastWasSpace = true
        for character in lowered {
            if character.isLetter, character.isASCII {
                result.append(character)
                lastWasSpace = false
            } else if character == " " || character == "-" || character == "_" {
                if !lastWasSpace {
                    result.append(" ")
                    lastWasSpace = true
                }
            }
            // それ以外（数字・記号）は落とす
        }
        return result.trimmingCharacters(in: .whitespaces)
    }

    /// 冠詞と単純な複数形を落とす。
    public static func stripArticlesAndPlural(_ text: String) -> String {
        var words = text.split(separator: " ").map(String.init)
        if let first = words.first, ["a", "an", "the", "its", "it", "is"].contains(first), words.count > 1 {
            words.removeFirst()
        }
        guard var last = words.last else { return text }
        let esEndings = ["ches", "shes", "xes", "zes", "ses"]
        if last.count > 4, last.hasSuffix("ies") {
            last.removeLast(3)
            last.append("y")
        } else if last.count > 4, esEndings.contains(where: { last.hasSuffix($0) }) {
            last.removeLast(2)
        } else if last.count > 2, last.hasSuffix("s"), !last.hasSuffix("ss") {
            last.removeLast()
        }
        words[words.count - 1] = last
        return words.joined(separator: " ")
    }
}
