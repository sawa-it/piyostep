import Foundation

/// アンロックできるコンテンツの種別。
public enum UnlockCategory: String, CaseIterable, Codable, Sendable, Identifiable {
    case character
    case costume
    case tableware
    case background
    case badge

    public var id: String { rawValue }

    public var childTitle: String {
        switch self {
        case .character: return "なかま"
        case .costume: return "きせかえ"
        case .tableware: return "おさら"
        case .background: return "はいけい"
        case .badge: return "バッジ"
        }
    }
}

/// アンロック条件。
public enum UnlockCondition: Hashable, Codable, Sendable {
    /// 累計スター
    case totalStars(Int)
    /// 学習した日数
    case learningDays(Int)
    /// ご飯タイマーの完了回数
    case mealsCompleted(Int)
    /// 教科の習熟度（0.0 - 1.0）
    case subjectMastery(Subject, Double)
    /// 今日のチャレンジの完了回数
    case challengesCompleted(Int)
    /// 最初から使える
    case always

    /// 子どもに見せる説明文。
    public var childDescription: String {
        switch self {
        case .totalStars(let count): return "★を \(count)こ あつめる"
        case .learningDays(let days): return "\(days)にち べんきょうする"
        case .mealsCompleted(let count): return "ごはんタイマーを \(count)かい やる"
        case .subjectMastery(let subject, _): return "\(subject.childTitle)を もっと れんしゅうする"
        case .challengesCompleted(let count): return "きょうのチャレンジを \(count)かい やる"
        case .always: return "さいしょから つかえるよ"
        }
    }
}

/// アンロック対象アイテム。
public struct UnlockableItem: Hashable, Codable, Sendable, Identifiable {
    public let id: String
    public let category: UnlockCategory
    public let name: String
    public let condition: UnlockCondition
    /// 描画に使う識別子（キャラなら CharacterDefinition.id など）
    public let artKey: String

    public init(
        id: String,
        category: UnlockCategory,
        name: String,
        condition: UnlockCondition,
        artKey: String
    ) {
        self.id = id
        self.category = category
        self.name = name
        self.condition = condition
        self.artKey = artKey
    }
}

/// アンロック判定に使う進捗サマリー。
public struct UnlockProgress: Hashable, Codable, Sendable {
    public var totalStars: Int
    public var learningDays: Int
    public var mealsCompleted: Int
    public var challengesCompleted: Int
    public var subjectMastery: [Subject: Double]

    public init(
        totalStars: Int = 0,
        learningDays: Int = 0,
        mealsCompleted: Int = 0,
        challengesCompleted: Int = 0,
        subjectMastery: [Subject: Double] = [:]
    ) {
        self.totalStars = totalStars
        self.learningDays = learningDays
        self.mealsCompleted = mealsCompleted
        self.challengesCompleted = challengesCompleted
        self.subjectMastery = subjectMastery
    }
}

public enum UnlockCatalog {
    public static let all: [UnlockableItem] = [
        // キャラクター
        UnlockableItem(id: "char.piyo", category: .character, name: "ぴよちゃん", condition: .always, artKey: "piyo"),
        UnlockableItem(id: "char.kuma", category: .character, name: "くまくん", condition: .always, artKey: "kuma"),
        UnlockableItem(id: "char.nyan", category: .character, name: "にゃんた", condition: .totalStars(30), artKey: "nyan"),
        UnlockableItem(id: "char.usa", category: .character, name: "うさぴょん", condition: .learningDays(3), artKey: "usa"),
        UnlockableItem(id: "char.pen", category: .character, name: "ぺんた", condition: .mealsCompleted(5), artKey: "pen"),
        UnlockableItem(id: "char.dino", category: .character, name: "がおくん", condition: .totalStars(120), artKey: "dino"),

        // きせかえ
        UnlockableItem(id: "costume.cap", category: .costume, name: "ぼうし", condition: .totalStars(10), artKey: "cap"),
        UnlockableItem(id: "costume.ribbon", category: .costume, name: "リボン", condition: .totalStars(25), artKey: "ribbon"),
        UnlockableItem(id: "costume.scarf", category: .costume, name: "マフラー", condition: .learningDays(5), artKey: "scarf"),
        UnlockableItem(id: "costume.crown", category: .costume, name: "おうかん", condition: .challengesCompleted(10), artKey: "crown"),
        UnlockableItem(id: "costume.glasses", category: .costume, name: "めがね", condition: .subjectMastery(.hiragana, 0.6), artKey: "glasses"),

        // おさら
        UnlockableItem(id: "ware.white", category: .tableware, name: "しろいおさら", condition: .always, artKey: "white"),
        UnlockableItem(id: "ware.flower", category: .tableware, name: "おはなのおさら", condition: .mealsCompleted(2), artKey: "flower"),
        UnlockableItem(id: "ware.star", category: .tableware, name: "ほしのおさら", condition: .mealsCompleted(8), artKey: "star"),
        UnlockableItem(id: "ware.rainbow", category: .tableware, name: "にじのおさら", condition: .mealsCompleted(15), artKey: "rainbow"),

        // はいけい
        UnlockableItem(id: "bg.sky", category: .background, name: "あおぞら", condition: .always, artKey: "sky"),
        UnlockableItem(id: "bg.park", category: .background, name: "こうえん", condition: .totalStars(15), artKey: "park"),
        UnlockableItem(id: "bg.sea", category: .background, name: "うみ", condition: .subjectMastery(.number, 0.6), artKey: "sea"),
        UnlockableItem(id: "bg.space", category: .background, name: "うちゅう", condition: .subjectMastery(.clock, 0.7), artKey: "space"),
        UnlockableItem(id: "bg.night", category: .background, name: "よぞら", condition: .learningDays(10), artKey: "night"),

        // バッジ
        UnlockableItem(id: "badge.tulip", category: .badge, name: "チューリップバッジ", condition: .always, artKey: "tulip"),
        UnlockableItem(id: "badge.grasshopper", category: .badge, name: "バッタバッジ", condition: .totalStars(5), artKey: "grasshopper"),
        UnlockableItem(id: "badge.butterfly", category: .badge, name: "ちょうちょバッジ", condition: .learningDays(2), artKey: "butterfly"),
        UnlockableItem(id: "badge.ladybug", category: .badge, name: "てんとうむしバッジ", condition: .challengesCompleted(3), artKey: "ladybug"),
        UnlockableItem(id: "badge.snail", category: .badge, name: "かたつむりバッジ", condition: .mealsCompleted(3), artKey: "snail"),
        UnlockableItem(id: "badge.sunflower", category: .badge, name: "ひまわりバッジ", condition: .challengesCompleted(7), artKey: "sunflower"),
        UnlockableItem(id: "badge.bee", category: .badge, name: "みつばちバッジ", condition: .subjectMastery(.hiragana, 0.5), artKey: "bee"),
        UnlockableItem(id: "badge.frog", category: .badge, name: "かえるバッジ", condition: .subjectMastery(.number, 0.5), artKey: "frog"),
        UnlockableItem(id: "badge.rainbow", category: .badge, name: "にじバッジ", condition: .subjectMastery(.englishWord, 0.5), artKey: "rainbow"),
        UnlockableItem(id: "badge.trophy", category: .badge, name: "トロフィーバッジ", condition: .challengesCompleted(20), artKey: "trophy")
    ]

    public static func item(id: String) -> UnlockableItem? {
        all.first { $0.id == id }
    }

    public static func items(in category: UnlockCategory) -> [UnlockableItem] {
        all.filter { $0.category == category }
    }

    /// 最初から利用できるアイテムの ID。
    public static var initiallyUnlockedIDs: Set<String> {
        Set(all.filter { $0.condition == .always }.map(\.id))
    }
}
