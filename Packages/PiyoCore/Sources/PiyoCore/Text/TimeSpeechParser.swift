import Foundation

/// 「さんじ」「3じ30ぷん」「くじはん」などの発話から時刻を取り出す。
public enum TimeSpeechParser {

    /// 解析結果。
    public enum Outcome: Equatable, Sendable {
        /// 時刻として解釈できた
        case time(ClockTime)
        /// 数字だけが聞き取れた（「30」だけなど）。文脈次第で使う。
        case bareNumber(Int)
        /// 時刻として解釈できなかった
        case unparsable
    }

    private static let minuteSuffixes = ["ふん", "ぷん"]

    /// 発話テキストから時刻を推定する。
    public static func parse(_ rawText: String) -> Outcome {
        let text = JapaneseTextNormalizer.normalize(rawText)
        guard !text.isEmpty else { return .unparsable }

        guard let hourMarkerIndex = indexOfHourMarker(in: text) else {
            // 「じ」が無い場合は数字だけとみなす。
            if let value = JapaneseNumberParser.parse(text) {
                return .bareNumber(value)
            }
            return .unparsable
        }

        let hourPart = String(text[text.startIndex ..< hourMarkerIndex])
        let minutePart = String(text[text.index(after: hourMarkerIndex)...])

        guard let hour = JapaneseNumberParser.parse(hourPart), (1 ... 12).contains(hour) else {
            return .unparsable
        }

        guard let minute = parseMinutePart(minutePart) else {
            return .unparsable
        }
        return .time(ClockTime(hour: hour, minute: minute))
    }

    /// 「じ」（「じゅう」の一部ではないもの）の位置を返す。
    static func indexOfHourMarker(in text: String) -> String.Index? {
        var index = text.startIndex
        while index < text.endIndex {
            if text[index] == "じ" {
                let next = text.index(after: index)
                if next == text.endIndex {
                    return index
                }
                let nextCharacter = text[next]
                // 「じゅう」「じゃ」「じょ」は拗音なので時刻の「じ」ではない。
                if nextCharacter != "ゅ", nextCharacter != "ゃ", nextCharacter != "ょ" {
                    return index
                }
            }
            index = text.index(after: index)
        }
        return nil
    }

    /// 「じ」より後ろの部分を分に変換する。
    static func parseMinutePart(_ part: String) -> Int? {
        var text = part
        if text.isEmpty { return 0 }
        if text == "ちょうど" || text == "ぴったり" { return 0 }
        if text.hasPrefix("はん") { return 30 }

        for suffix in minuteSuffixes where text.hasSuffix(suffix) {
            text.removeLast(suffix.count)
            break
        }
        // 「ごろ」「くらい」などの曖昧語は落とす。
        for suffix in ["ごろ", "くらい", "ぐらい"] where text.hasSuffix(suffix) {
            text.removeLast(suffix.count)
            break
        }
        if text.isEmpty { return 0 }
        guard let minute = JapaneseNumberParser.parse(text), (0 ... 59).contains(minute) else {
            return nil
        }
        return minute
    }
}
