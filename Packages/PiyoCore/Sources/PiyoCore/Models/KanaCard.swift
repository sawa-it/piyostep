import Foundation

/// かな 1 文字の学習カード。ひらがな・カタカナ両方の情報を持つ。
public struct KanaCard: Hashable, Codable, Sendable, Identifiable {
    /// 五十音の行（あ行 = 0, か行 = 1, ...）
    public let rowIndex: Int
    /// 行内の位置（あ = 0, い = 1, ...）
    public let columnIndex: Int
    public let hiragana: String
    public let katakana: String
    public let romaji: String
    /// ひらがな学習で使う例語（ひらがな表記）
    public let hiraganaWord: String
    /// カタカナ学習で使う例語（カタカナ表記）
    public let katakanaWord: String
    /// イラスト識別子。アプリ側が図形描画にマッピングする。
    public let illustration: String
    /// 助詞など、語頭に来ない文字は出題頻度を下げる。
    public let isRareInitial: Bool

    public var id: String { hiragana }

    public init(
        rowIndex: Int,
        columnIndex: Int,
        hiragana: String,
        katakana: String,
        romaji: String,
        hiraganaWord: String,
        katakanaWord: String,
        illustration: String,
        isRareInitial: Bool = false
    ) {
        self.rowIndex = rowIndex
        self.columnIndex = columnIndex
        self.hiragana = hiragana
        self.katakana = katakana
        self.romaji = romaji
        self.hiraganaWord = hiraganaWord
        self.katakanaWord = katakanaWord
        self.illustration = illustration
        self.isRareInitial = isRareInitial
    }

    /// 指定の表記系での文字。
    public func character(for subject: Subject) -> String {
        subject == .katakana ? katakana : hiragana
    }

    /// 指定の表記系での例語。
    public func word(for subject: Subject) -> String {
        subject == .katakana ? katakanaWord : hiraganaWord
    }

    /// 五十音順の通し番号。
    public var order: Int { rowIndex * 10 + columnIndex }
}

/// 五十音のカタログ。
public enum KanaCatalog {
    /// 五十音 46 文字。
    public static let all: [KanaCard] = {
        // (row, column, ひら, カタ, romaji, ひらがな例語, カタカナ例語, illustration, rare)
        let table: [(Int, Int, String, String, String, String, String, String, Bool)] = [
            (0, 0, "あ", "ア", "a", "あひる", "アイス", "duck", false),
            (0, 1, "い", "イ", "i", "いぬ", "イヌ", "dog", false),
            (0, 2, "う", "ウ", "u", "うま", "ウサギ", "horse", false),
            (0, 3, "え", "エ", "e", "えんぴつ", "エビ", "pencil", false),
            (0, 4, "お", "オ", "o", "おにぎり", "オレンジ", "riceball", false),

            (1, 0, "か", "カ", "ka", "かさ", "カメ", "umbrella", false),
            (1, 1, "き", "キ", "ki", "きりん", "キリン", "giraffe", false),
            (1, 2, "く", "ク", "ku", "くま", "クツ", "bear", false),
            (1, 3, "け", "ケ", "ke", "けむし", "ケーキ", "caterpillar", false),
            (1, 4, "こ", "コ", "ko", "こおり", "コアラ", "ice", false),

            (2, 0, "さ", "サ", "sa", "さかな", "サカナ", "fish", false),
            (2, 1, "し", "シ", "shi", "しまうま", "シマウマ", "zebra", false),
            (2, 2, "す", "ス", "su", "すいか", "スイカ", "watermelon", false),
            (2, 3, "せ", "セ", "se", "せんべい", "セミ", "ricecracker", false),
            (2, 4, "そ", "ソ", "so", "そり", "ソファ", "sled", false),

            (3, 0, "た", "タ", "ta", "たいこ", "タコ", "drum", false),
            (3, 1, "ち", "チ", "chi", "ちょうちょ", "チーズ", "butterfly", false),
            (3, 2, "つ", "ツ", "tsu", "つき", "ツリー", "moon", false),
            (3, 3, "て", "テ", "te", "てぶくろ", "テレビ", "glove", false),
            (3, 4, "と", "ト", "to", "とけい", "トマト", "clock", false),

            (4, 0, "な", "ナ", "na", "なす", "ナイフ", "eggplant", false),
            (4, 1, "に", "ニ", "ni", "にんじん", "ニワトリ", "carrot", false),
            (4, 2, "ぬ", "ヌ", "nu", "ぬいぐるみ", "ヌードル", "teddy", false),
            (4, 3, "ね", "ネ", "ne", "ねこ", "ネコ", "cat", false),
            (4, 4, "の", "ノ", "no", "のりもの", "ノート", "vehicle", false),

            (5, 0, "は", "ハ", "ha", "はな", "ハサミ", "flower", false),
            (5, 1, "ひ", "ヒ", "hi", "ひこうき", "ヒコウキ", "airplane", false),
            (5, 2, "ふ", "フ", "fu", "ふね", "フネ", "ship", false),
            (5, 3, "へ", "ヘ", "he", "へび", "ヘリコプター", "snake", false),
            (5, 4, "ほ", "ホ", "ho", "ほし", "ホシ", "star", false),

            (6, 0, "ま", "マ", "ma", "まめ", "マイク", "beans", false),
            (6, 1, "み", "ミ", "mi", "みかん", "ミルク", "orange", false),
            (6, 2, "む", "ム", "mu", "むし", "ムシ", "bug", false),
            (6, 3, "め", "メ", "me", "めがね", "メガネ", "glasses", false),
            (6, 4, "も", "モ", "mo", "もも", "モモ", "peach", false),

            (7, 0, "や", "ヤ", "ya", "やさい", "ヤサイ", "vegetable", false),
            (7, 2, "ゆ", "ユ", "yu", "ゆき", "ユキ", "snow", false),
            (7, 4, "よ", "ヨ", "yo", "ようふく", "ヨット", "clothes", false),

            (8, 0, "ら", "ラ", "ra", "らいおん", "ライオン", "lion", false),
            (8, 1, "り", "リ", "ri", "りんご", "リンゴ", "apple", false),
            (8, 2, "る", "ル", "ru", "るすばん", "ルーペ", "house", false),
            (8, 3, "れ", "レ", "re", "れっしゃ", "レモン", "train", false),
            (8, 4, "ろ", "ロ", "ro", "ろうそく", "ロケット", "candle", false),

            (9, 0, "わ", "ワ", "wa", "わに", "ワニ", "crocodile", false),
            (9, 3, "を", "ヲ", "wo", "をつける", "ヲ", "particle", true),
            (9, 4, "ん", "ン", "n", "きりん", "パン", "bread", true)
        ]
        return table.map {
            KanaCard(
                rowIndex: $0.0,
                columnIndex: $0.1,
                hiragana: $0.2,
                katakana: $0.3,
                romaji: $0.4,
                hiraganaWord: $0.5,
                katakanaWord: $0.6,
                illustration: $0.7,
                isRareInitial: $0.8
            )
        }
    }()

    /// 出題に使う 44 文字（「を」「ん」を除く）。
    public static let teachable: [KanaCard] = all.filter { !$0.isRareInitial }

    /// 難易度ごとの出題対象。やさしい順に「あ行・か行」から広げる。
    public static func cards(for level: DifficultyLevel) -> [KanaCard] {
        let maxRow: Int
        switch level.raw {
        case 1: maxRow = 1   // あ・か行
        case 2: maxRow = 3   // 〜た行
        case 3: maxRow = 5   // 〜は行
        case 4: maxRow = 7   // 〜や行
        default: maxRow = 9  // すべて
        }
        return teachable.filter { $0.rowIndex <= maxRow }
    }

    public static func card(forHiragana hiragana: String) -> KanaCard? {
        all.first { $0.hiragana == hiragana }
    }

    public static func card(forKatakana katakana: String) -> KanaCard? {
        all.first { $0.katakana == katakana }
    }
}
