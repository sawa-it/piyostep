import Foundation

/// キャラクターの見た目の種類。アプリ側の図形描画にマッピングされる。
public enum CharacterArtStyle: String, CaseIterable, Codable, Sendable {
    case chick
    case bear
    case cat
    case rabbit
    case penguin
    case dinosaur
}

/// キャラクターの性格。ご飯タイマーの振る舞いに影響する。
public struct CharacterPersonality: Hashable, Codable, Sendable {
    /// 食べるスピードのばらつき（0.0 = 一定, 1.0 = とても気まぐれ）
    public let paceVariance: Double
    /// ひと休みの入りやすさ（0.0 - 1.0）
    public let restTendency: Double
    /// 応援してくれる頻度（0.0 - 1.0）
    public let cheerTendency: Double

    public init(paceVariance: Double, restTendency: Double, cheerTendency: Double) {
        self.paceVariance = min(max(paceVariance, 0), 1)
        self.restTendency = min(max(restTendency, 0), 1)
        self.cheerTendency = min(max(cheerTendency, 0), 1)
    }

    public static let steady = CharacterPersonality(paceVariance: 0.15, restTendency: 0.2, cheerTendency: 0.5)
    public static let playful = CharacterPersonality(paceVariance: 0.45, restTendency: 0.45, cheerTendency: 0.8)
    public static let gentle = CharacterPersonality(paceVariance: 0.25, restTendency: 0.35, cheerTendency: 0.9)
}

/// キャラクター定義。
public struct CharacterDefinition: Hashable, Codable, Sendable, Identifiable {
    public let id: String
    /// 子どもが呼ぶ名前（ひらがな）
    public let name: String
    public let artStyle: CharacterArtStyle
    /// メインカラー（#RRGGBB）
    public let primaryColorHex: String
    /// アクセントカラー（#RRGGBB）
    public let accentColorHex: String
    public let personality: CharacterPersonality
    /// 好きな食べ物（ご飯タイマーのお皿に出る）
    public let favoriteFood: String

    public init(
        id: String,
        name: String,
        artStyle: CharacterArtStyle,
        primaryColorHex: String,
        accentColorHex: String,
        personality: CharacterPersonality,
        favoriteFood: String
    ) {
        self.id = id
        self.name = name
        self.artStyle = artStyle
        self.primaryColorHex = primaryColorHex
        self.accentColorHex = accentColorHex
        self.personality = personality
        self.favoriteFood = favoriteFood
    }

    // MARK: - セリフ（すべて肯定的。否定語は使わない）

    public var raceIntroLine: String {
        "\(name)と きょうそう！ どっちが さきに ごはんを たべおわるかな？"
    }

    public func cheerLine(childName: String) -> String {
        let name = childName.isEmpty ? "きみ" : childName
        return "\(name)、がんばって！"
    }

    public var restLine: String {
        "ふぅ、ちょっと ひとやすみ…"
    }

    public var eatLine: String {
        "もぐもぐ！ おいしいね！"
    }

    public func childWonLine(childName: String) -> String {
        let name = childName.isEmpty ? "きみ" : childName
        return "やったー！ \(name)は \(self.name)より はやかったね！"
    }

    /// キャラが先に食べ終わった場合でも、応援のことばだけを使う。
    public var characterFinishedLine: String {
        "\(name)は たべおわったよ！ あとちょっと！"
    }

    public var watchingLine: String {
        "\(name)が おうえんしてるよ！"
    }

    public func finishTogetherLine(childName: String) -> String {
        let name = childName.isEmpty ? "きみ" : childName
        return "\(self.name)と \(name)、ごちそうさま！"
    }
}

public enum CharacterCatalog {
    public static let defaultCharacterID = "piyo"

    public static let all: [CharacterDefinition] = [
        CharacterDefinition(
            id: "piyo",
            name: "ぴよちゃん",
            artStyle: .chick,
            primaryColorHex: "#FFD54F",
            accentColorHex: "#FF8A65",
            personality: .steady,
            favoriteFood: "おにぎり"
        ),
        CharacterDefinition(
            id: "kuma",
            name: "くまくん",
            artStyle: .bear,
            primaryColorHex: "#BCAAA4",
            accentColorHex: "#8D6E63",
            personality: .gentle,
            favoriteFood: "パンケーキ"
        ),
        CharacterDefinition(
            id: "nyan",
            name: "にゃんた",
            artStyle: .cat,
            primaryColorHex: "#FFCC80",
            accentColorHex: "#FF7043",
            personality: .playful,
            favoriteFood: "おさかな"
        ),
        CharacterDefinition(
            id: "usa",
            name: "うさぴょん",
            artStyle: .rabbit,
            primaryColorHex: "#F8BBD0",
            accentColorHex: "#EC407A",
            personality: .playful,
            favoriteFood: "にんじん"
        ),
        CharacterDefinition(
            id: "pen",
            name: "ぺんた",
            artStyle: .penguin,
            primaryColorHex: "#90CAF9",
            accentColorHex: "#1E88E5",
            personality: .steady,
            favoriteFood: "おさかな"
        ),
        CharacterDefinition(
            id: "dino",
            name: "がおくん",
            artStyle: .dinosaur,
            primaryColorHex: "#A5D6A7",
            accentColorHex: "#43A047",
            personality: .playful,
            favoriteFood: "やさいスープ"
        )
    ]

    public static func character(id: String) -> CharacterDefinition? {
        all.first { $0.id == id }
    }

    public static var fallback: CharacterDefinition {
        // 定義は静的なので必ず存在する。
        character(id: defaultCharacterID) ?? all[0]
    }
}
