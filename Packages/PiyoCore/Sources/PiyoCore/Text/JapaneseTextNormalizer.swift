import Foundation

/// 幼児の発話や音声認識結果の揺れを吸収するための日本語正規化。
public enum JapaneseTextNormalizer {

    /// フィラー（言いよどみ）。認識結果の先頭に混ざりやすい。
    static let fillers = [
        "えーと", "えっと", "えーっと", "えと", "あのー", "あの", "うーんと",
        "うんと", "んーと", "んと", "ええと", "うーん", "んー"
    ]

    /// 文末表現。判定の邪魔になるので落とす。
    static let trailingExpressions = [
        "だとおもう", "とおもう", "じゃないかな", "じゃない", "だとおもいます",
        "でーす", "です", "ですか", "でした", "ます", "だよ", "だね", "だと",
        "かな", "かも", "だよー", "よー", "よ", "ね", "な"
    ]

    /// 記号・空白を取り除く。
    public static func stripSymbols(_ text: String) -> String {
        let removable: Set<Character> = [
            " ", "\u{3000}", "\n", "\t",
            "、", "。", "，", "．", ",", ".", "!", "?", "！", "？",
            "「", "」", "『", "』", "・", "…", "ー", "－", "〜", "~", "-", "ｰ"
        ]
        return String(text.filter { !removable.contains($0) })
    }

    /// 全角英数字を半角にする。
    public static func toHalfwidthAlphanumerics(_ text: String) -> String {
        var scalars = String.UnicodeScalarView()
        for scalar in text.unicodeScalars {
            switch scalar.value {
            case 0xFF10 ... 0xFF19, // ０-９
                 0xFF21 ... 0xFF3A, // Ａ-Ｚ
                 0xFF41 ... 0xFF5A: // ａ-ｚ
                if let converted = UnicodeScalar(scalar.value - 0xFEE0) {
                    scalars.append(converted)
                } else {
                    scalars.append(scalar)
                }
            default:
                scalars.append(scalar)
            }
        }
        return String(scalars)
    }

    /// カタカナをひらがなにする。
    public static func katakanaToHiragana(_ text: String) -> String {
        var scalars = String.UnicodeScalarView()
        for scalar in text.unicodeScalars {
            // ァ(0x30A1) - ヶ(0x30F6) を 0x60 引いてひらがなに写す。
            if (0x30A1 ... 0x30F6).contains(scalar.value),
               let converted = UnicodeScalar(scalar.value - 0x60) {
                scalars.append(converted)
            } else {
                scalars.append(scalar)
            }
        }
        return String(scalars)
    }

    /// 漢数字をアラビア数字が扱える読みに寄せる（一 → いち など）。
    public static func kanjiDigitsToKana(_ text: String) -> String {
        let map: [Character: String] = [
            "〇": "ぜろ", "零": "ぜろ", "一": "いち", "二": "に", "三": "さん",
            "四": "よん", "五": "ご", "六": "ろく", "七": "なな", "八": "はち",
            "九": "きゅう", "十": "じゅう", "百": "ひゃく",
            "時": "じ", "分": "ふん", "半": "はん", "個": "こ", "本": "ほん", "枚": "まい"
        ]
        var result = ""
        for character in text {
            result += map[character].map { String($0) } ?? String(character)
        }
        return result
    }

    /// フィラーを先頭から取り除く。
    public static func stripFillers(_ text: String) -> String {
        var result = text
        var changed = true
        while changed {
            changed = false
            for filler in fillers where result.hasPrefix(filler) && result.count > filler.count {
                result.removeFirst(filler.count)
                changed = true
                break
            }
        }
        return result
    }

    /// 文末表現を取り除く。
    public static func stripTrailingExpressions(_ text: String) -> String {
        var result = text
        var changed = true
        while changed {
            changed = false
            for expression in trailingExpressions
            where result.hasSuffix(expression) && result.count > expression.count {
                result.removeLast(expression.count)
                changed = true
                break
            }
        }
        return result
    }

    /// 正規化のフルパイプライン。
    public static func normalize(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        result = toHalfwidthAlphanumerics(result)
        result = kanjiDigitsToKana(result)
        result = katakanaToHiragana(result)
        result = stripSymbols(result)
        result = stripFillers(result)
        result = stripTrailingExpressions(result)
        return result
    }

    /// より緩い比較キー。濁点・半濁点・小書き・長音の違いを無視する。
    /// 3〜6歳の発話と音声認識の揺れを吸収するために使う。
    public static func looseKey(_ text: String) -> String {
        let normalized = normalize(text)
        var result = ""
        for character in normalized {
            if let base = JapaneseTextNormalizer.baseKana[character] {
                result.append(base)
            } else if character == "ー" || character == "っ" || character == "ん" {
                // 長音・促音・撥音は落とす（「ろっく」と「ろく」を同一視）
                continue
            } else {
                result.append(character)
            }
        }
        return result
    }

    /// 濁点・半濁点・小書きを取り去った基本形への写像。
    static let baseKana: [Character: Character] = {
        var map: [Character: Character] = [:]
        let pairs: [(String, String)] = [
            ("がぎぐげご", "かきくけこ"),
            ("ざじずぜぞ", "さしすせそ"),
            ("だぢづでど", "たちつてと"),
            ("ばびぶべぼ", "はひふへほ"),
            ("ぱぴぷぺぽ", "はひふへほ"),
            ("ぁぃぅぇぉ", "あいうえお"),
            ("ゃゅょ", "やゆよ"),
            ("ゎ", "わ"),
            ("ゔ", "う")
        ]
        for (from, to) in pairs {
            for (source, target) in zip(from, to) {
                map[source] = target
            }
        }
        return map
    }()
}
