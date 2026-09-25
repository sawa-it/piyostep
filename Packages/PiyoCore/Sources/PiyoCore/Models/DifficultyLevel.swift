import Foundation

/// 1（やさしい）〜 5（むずかしい）の 5 段階。意味づけは Skill ごとに異なる。
public struct DifficultyLevel: Hashable, Codable, Sendable, Comparable, CustomStringConvertible {
    public static let minimumRaw = 1
    public static let maximumRaw = 5

    public let raw: Int

    public init(_ raw: Int) {
        self.raw = min(max(raw, DifficultyLevel.minimumRaw), DifficultyLevel.maximumRaw)
    }

    public static let level1 = DifficultyLevel(1)
    public static let level2 = DifficultyLevel(2)
    public static let level3 = DifficultyLevel(3)
    public static let level4 = DifficultyLevel(4)
    public static let level5 = DifficultyLevel(5)

    public static func < (lhs: DifficultyLevel, rhs: DifficultyLevel) -> Bool {
        lhs.raw < rhs.raw
    }

    public var description: String { "Lv\(raw)" }

    /// 1 段上げる（上限でクランプ）。
    public func increased(by step: Int = 1) -> DifficultyLevel {
        DifficultyLevel(raw + step)
    }

    /// 1 段下げる（下限でクランプ）。
    public func decreased(by step: Int = 1) -> DifficultyLevel {
        DifficultyLevel(raw - step)
    }

    /// 指定範囲に収める。
    public func clamped(to range: ClosedRange<Int>) -> DifficultyLevel {
        DifficultyLevel(min(max(raw, range.lowerBound), range.upperBound))
    }

    public var childLabel: String {
        switch raw {
        case 1: return "はじめて"
        case 2: return "かんたん"
        case 3: return "ふつう"
        case 4: return "ちょうせん"
        default: return "たつじん"
        }
    }
}

/// 保護者が選ぶ難易度モード。
public enum DifficultyMode: String, CaseIterable, Codable, Sendable, Identifiable {
    case automatic  // 習熟度に応じて自動調整
    case easy
    case normal
    case hard

    public var id: String { rawValue }

    public var parentTitle: String {
        switch self {
        case .automatic: return "じどう（おすすめ）"
        case .easy: return "かんたん"
        case .normal: return "ふつう"
        case .hard: return "むずかしい"
        }
    }

    /// このモードで許される難易度の範囲。
    public var allowedRange: ClosedRange<Int> {
        switch self {
        case .automatic: return 1 ... 5
        case .easy: return 1 ... 2
        case .normal: return 2 ... 4
        case .hard: return 3 ... 5
        }
    }
}
