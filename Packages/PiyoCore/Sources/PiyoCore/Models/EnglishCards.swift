import Foundation

/// アルファベット 1 文字の学習カード。
public struct AlphabetCard: Hashable, Codable, Sendable, Identifiable {
    public let uppercase: String
    public let lowercase: String
    /// 文字の名前（英語の読み）。音声認識の正解候補にも使う。
    public let letterName: String
    /// 日本語のカタカナ読み（読み上げ補助）。
    public let katakanaName: String
    /// 例となる英単語の ID。
    public let exampleWordID: String

    public var id: String { uppercase }

    public init(
        uppercase: String,
        lowercase: String,
        letterName: String,
        katakanaName: String,
        exampleWordID: String
    ) {
        self.uppercase = uppercase
        self.lowercase = lowercase
        self.letterName = letterName
        self.katakanaName = katakanaName
        self.exampleWordID = exampleWordID
    }

    public func character(isUppercase: Bool) -> String {
        isUppercase ? uppercase : lowercase
    }

    /// 音声認識で許容する表記（英語話者向けの綴り揺れ）。
    public var acceptedSpokenForms: [String] {
        var forms = [uppercase.lowercased(), letterName.lowercased()]
        switch uppercase {
        case "A": forms.append(contentsOf: ["ay", "eh"])
        case "B": forms.append("bee")
        case "C": forms.append(contentsOf: ["see", "sea"])
        case "E": forms.append("ee")
        case "G": forms.append("gee")
        case "I": forms.append(contentsOf: ["eye", "aye"])
        case "J": forms.append("jay")
        case "K": forms.append("kay")
        case "O": forms.append("oh")
        case "P": forms.append("pee")
        case "Q": forms.append(contentsOf: ["cue", "queue"])
        case "R": forms.append("are")
        case "T": forms.append(contentsOf: ["tee", "tea"])
        case "U": forms.append(contentsOf: ["you", "yu"])
        case "V": forms.append("vee")
        case "X": forms.append("ex")
        case "Y": forms.append("why")
        case "Z": forms.append(contentsOf: ["zee", "zed"])
        default: break
        }
        return Array(Set(forms))
    }
}

public enum AlphabetCatalog {
    public static let all: [AlphabetCard] = {
        let table: [(String, String, String, String)] = [
            ("A", "ay", "エー", "apple"),
            ("B", "bee", "ビー", "ball"),
            ("C", "see", "シー", "cat"),
            ("D", "dee", "ディー", "dog"),
            ("E", "ee", "イー", "egg"),
            ("F", "ef", "エフ", "fish"),
            ("G", "gee", "ジー", "grape"),
            ("H", "aitch", "エイチ", "hat"),
            ("I", "eye", "アイ", "ice"),
            ("J", "jay", "ジェー", "juice"),
            ("K", "kay", "ケー", "key"),
            ("L", "el", "エル", "lion"),
            ("M", "em", "エム", "mom"),
            ("N", "en", "エヌ", "nose"),
            ("O", "oh", "オー", "orange"),
            ("P", "pee", "ピー", "pig"),
            ("Q", "cue", "キュー", "queen"),
            ("R", "ar", "アール", "red"),
            ("S", "es", "エス", "sun"),
            ("T", "tee", "ティー", "tree"),
            ("U", "you", "ユー", "umbrella"),
            ("V", "vee", "ブイ", "van"),
            ("W", "double u", "ダブリュー", "water"),
            ("X", "ex", "エックス", "box"),
            ("Y", "why", "ワイ", "yellow"),
            ("Z", "zee", "ゼット", "zebra")
        ]
        return table.map {
            AlphabetCard(
                uppercase: $0.0,
                lowercase: $0.0.lowercased(),
                letterName: $0.1,
                katakanaName: $0.2,
                exampleWordID: $0.3
            )
        }
    }()

    /// 難易度に応じた出題範囲。A から順に広げる。
    public static func cards(for level: DifficultyLevel) -> [AlphabetCard] {
        let count: Int
        switch level.raw {
        case 1: count = 6
        case 2: count = 12
        case 3: count = 18
        case 4: count = 22
        default: count = 26
        }
        return Array(all.prefix(count))
    }

    public static func card(for letter: String) -> AlphabetCard? {
        all.first { $0.uppercase.caseInsensitiveCompare(letter) == .orderedSame }
    }
}

/// 英単語カード。
public struct EnglishWordCard: Hashable, Codable, Sendable, Identifiable {
    public let id: String
    /// 表示する英語（小文字）
    public let english: String
    /// 日本語訳（補助表示）
    public let japanese: String
    /// カタカナでの読み（読み上げ補助）
    public let katakana: String
    /// 音声認識で許容する追加表記
    public let alternativeSpellings: [String]
    public let category: EnglishWordCategory
    /// 3〜6歳向けの出題順（小さいほどやさしい）
    public let tier: Int
    /// イラスト識別子
    public let illustration: String

    public init(
        id: String,
        english: String,
        japanese: String,
        katakana: String,
        alternativeSpellings: [String] = [],
        category: EnglishWordCategory,
        tier: Int,
        illustration: String? = nil
    ) {
        self.id = id
        self.english = english
        self.japanese = japanese
        self.katakana = katakana
        self.alternativeSpellings = alternativeSpellings
        self.category = category
        self.tier = tier
        self.illustration = illustration ?? id
    }

    /// 正解として受け入れる英語表記の一覧（すべて小文字）。
    public var acceptedSpellings: [String] {
        var forms = [english.lowercased()]
        forms.append(contentsOf: alternativeSpellings.map { $0.lowercased() })
        forms.append("a \(english.lowercased())")
        forms.append("an \(english.lowercased())")
        forms.append("the \(english.lowercased())")
        forms.append("\(english.lowercased())s")
        return Array(Set(forms))
    }
}

public enum EnglishWordCategory: String, CaseIterable, Codable, Sendable {
    case animal
    case food
    case color
    case nature
    case family
    case thing

    public var childTitle: String {
        switch self {
        case .animal: return "どうぶつ"
        case .food: return "たべもの"
        case .color: return "いろ"
        case .nature: return "しぜん"
        case .family: return "かぞく"
        case .thing: return "もの"
        }
    }
}

public enum EnglishWordCatalog {
    public static let all: [EnglishWordCard] = [
        EnglishWordCard(id: "apple", english: "apple", japanese: "りんご", katakana: "アップル", category: .food, tier: 1),
        EnglishWordCard(id: "dog", english: "dog", japanese: "いぬ", katakana: "ドッグ", category: .animal, tier: 1),
        EnglishWordCard(id: "cat", english: "cat", japanese: "ねこ", katakana: "キャット", category: .animal, tier: 1),
        EnglishWordCard(id: "car", english: "car", japanese: "くるま", katakana: "カー", category: .thing, tier: 1),
        EnglishWordCard(id: "sun", english: "sun", japanese: "たいよう", katakana: "サン", category: .nature, tier: 1),
        EnglishWordCard(id: "moon", english: "moon", japanese: "つき", katakana: "ムーン", category: .nature, tier: 1),
        EnglishWordCard(id: "red", english: "red", japanese: "あか", katakana: "レッド", category: .color, tier: 1),
        EnglishWordCard(id: "blue", english: "blue", japanese: "あお", katakana: "ブルー", category: .color, tier: 1),
        EnglishWordCard(id: "mom", english: "mom", japanese: "おかあさん", katakana: "マム", alternativeSpellings: ["mommy", "mum"], category: .family, tier: 1),
        EnglishWordCard(id: "dad", english: "dad", japanese: "おとうさん", katakana: "ダッド", alternativeSpellings: ["daddy"], category: .family, tier: 1),
        EnglishWordCard(id: "lion", english: "lion", japanese: "ライオン", katakana: "ライオン", category: .animal, tier: 2),
        EnglishWordCard(id: "fish", english: "fish", japanese: "さかな", katakana: "フィッシュ", category: .animal, tier: 2),
        EnglishWordCard(id: "bird", english: "bird", japanese: "とり", katakana: "バード", category: .animal, tier: 2),
        EnglishWordCard(id: "egg", english: "egg", japanese: "たまご", katakana: "エッグ", category: .food, tier: 2),
        EnglishWordCard(id: "milk", english: "milk", japanese: "ミルク", katakana: "ミルク", category: .food, tier: 2),
        EnglishWordCard(id: "ball", english: "ball", japanese: "ボール", katakana: "ボール", category: .thing, tier: 2),
        EnglishWordCard(id: "tree", english: "tree", japanese: "き", katakana: "ツリー", category: .nature, tier: 2),
        EnglishWordCard(id: "star", english: "star", japanese: "ほし", katakana: "スター", category: .nature, tier: 2),
        EnglishWordCard(id: "green", english: "green", japanese: "みどり", katakana: "グリーン", category: .color, tier: 2),
        EnglishWordCard(id: "yellow", english: "yellow", japanese: "きいろ", katakana: "イエロー", category: .color, tier: 2),
        EnglishWordCard(id: "grape", english: "grape", japanese: "ぶどう", katakana: "グレープ", category: .food, tier: 3),
        EnglishWordCard(id: "hat", english: "hat", japanese: "ぼうし", katakana: "ハット", category: .thing, tier: 3),
        EnglishWordCard(id: "ice", english: "ice", japanese: "こおり", katakana: "アイス", category: .nature, tier: 3),
        EnglishWordCard(id: "juice", english: "juice", japanese: "ジュース", katakana: "ジュース", category: .food, tier: 3),
        EnglishWordCard(id: "key", english: "key", japanese: "かぎ", katakana: "キー", category: .thing, tier: 3),
        EnglishWordCard(id: "nose", english: "nose", japanese: "はな", katakana: "ノーズ", category: .thing, tier: 3),
        EnglishWordCard(id: "orange", english: "orange", japanese: "オレンジ", katakana: "オレンジ", category: .food, tier: 3),
        EnglishWordCard(id: "pig", english: "pig", japanese: "ぶた", katakana: "ピッグ", category: .animal, tier: 3),
        EnglishWordCard(id: "queen", english: "queen", japanese: "おうじょ", katakana: "クイーン", category: .thing, tier: 4),
        EnglishWordCard(id: "umbrella", english: "umbrella", japanese: "かさ", katakana: "アンブレラ", category: .thing, tier: 4),
        EnglishWordCard(id: "van", english: "van", japanese: "バン", katakana: "バン", category: .thing, tier: 4),
        EnglishWordCard(id: "water", english: "water", japanese: "みず", katakana: "ウォーター", category: .nature, tier: 4),
        EnglishWordCard(id: "box", english: "box", japanese: "はこ", katakana: "ボックス", category: .thing, tier: 4),
        EnglishWordCard(id: "zebra", english: "zebra", japanese: "しまうま", katakana: "ゼブラ", category: .animal, tier: 4)
    ]

    public static func card(for id: String) -> EnglishWordCard? {
        all.first { $0.id == id }
    }

    /// 難易度に応じた出題範囲。
    public static func cards(for level: DifficultyLevel) -> [EnglishWordCard] {
        let maxTier: Int
        switch level.raw {
        case 1: maxTier = 1
        case 2: maxTier = 2
        case 3: maxTier = 2
        case 4: maxTier = 3
        default: maxTier = 4
        }
        return all.filter { $0.tier <= maxTier }
    }
}
