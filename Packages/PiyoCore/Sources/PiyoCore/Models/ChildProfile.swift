import Foundation

/// 子どものプロフィール。
public struct ChildProfile: Hashable, Codable, Sendable, Identifiable {
    public let id: UUID
    public var nickname: String
    public var age: Int
    /// ホームに出てくる相棒キャラクターの ID。
    public var buddyCharacterID: String
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        nickname: String,
        age: Int,
        buddyCharacterID: String = CharacterCatalog.defaultCharacterID,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.nickname = ChildProfile.sanitize(nickname: nickname)
        self.age = min(max(age, 3), 6)
        self.buddyCharacterID = buddyCharacterID
        self.createdAt = createdAt
    }

    /// 呼びかけ用（「さくらちゃん」ではなく素の名前に「ちゃん」等は付けない。名前だけを使う）。
    public var callName: String {
        nickname.isEmpty ? "きみ" : nickname
    }

    /// 空白除去と最大文字数の制限。
    public static func sanitize(nickname: String) -> String {
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count > 8 {
            return String(trimmed.prefix(8))
        }
        return trimmed
    }

    /// 年齢から推奨される初期難易度。
    public var suggestedStartingLevel: DifficultyLevel {
        switch age {
        case 3: return .level1
        case 4: return .level2
        case 5: return .level2
        default: return .level3
        }
    }
}

/// 1日の学習量の目安。
public enum DailyGoal: String, CaseIterable, Codable, Sendable, Identifiable {
    case light
    case normal
    case plenty

    public var id: String { rawValue }

    /// 今日のチャレンジの問題数。
    public var questionCount: Int {
        switch self {
        case .light: return 5
        case .normal: return 8
        case .plenty: return 12
        }
    }

    public var parentTitle: String {
        switch self {
        case .light: return "すこし（5問 / 約3分）"
        case .normal: return "ふつう（8問 / 約5分）"
        case .plenty: return "しっかり（12問 / 約8分）"
        }
    }
}
