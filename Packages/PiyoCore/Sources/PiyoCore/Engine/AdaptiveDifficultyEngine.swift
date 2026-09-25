import Foundation

/// 難易度の調整結果。
public enum DifficultyAdjustment: Equatable, Sendable {
    case increased(from: DifficultyLevel, to: DifficultyLevel)
    case decreased(from: DifficultyLevel, to: DifficultyLevel)
    case unchanged(DifficultyLevel)

    public var level: DifficultyLevel {
        switch self {
        case .increased(_, let to): return to
        case .decreased(_, let to): return to
        case .unchanged(let level): return level
        }
    }

    public var didChange: Bool {
        if case .unchanged = self { return false }
        return true
    }
}

/// 回答履歴から次の出題難易度を決める。
public struct AdaptiveDifficultyEngine {
    /// レベルを上げるのに必要な、現レベルでの最小回答数
    public let minimumAttemptsToPromote: Int
    /// レベルを下げるのに必要な、現レベルでの最小回答数
    public let minimumAttemptsToDemote: Int
    /// 昇格のしきい値（ewma）
    public let promoteThreshold: Double
    /// 降格のしきい値（ewma）
    public let demoteThreshold: Double
    /// この回数連続で間違えたら復習モードに入る
    public let consecutiveMissesForReview: Int

    public init(
        minimumAttemptsToPromote: Int = 6,
        minimumAttemptsToDemote: Int = 4,
        promoteThreshold: Double = 0.8,
        demoteThreshold: Double = 0.4,
        consecutiveMissesForReview: Int = 3
    ) {
        self.minimumAttemptsToPromote = minimumAttemptsToPromote
        self.minimumAttemptsToDemote = minimumAttemptsToDemote
        self.promoteThreshold = promoteThreshold
        self.demoteThreshold = demoteThreshold
        self.consecutiveMissesForReview = consecutiveMissesForReview
    }

    /// スナップショットとモードから次のレベルを決める。
    public func adjust(
        snapshot: MasterySnapshot,
        mode: DifficultyMode
    ) -> DifficultyAdjustment {
        let range = mode.allowedRange
        let current = snapshot.level.clamped(to: range)

        // 手動モードでレベルが範囲外なら、まず範囲内へ寄せる。
        if current != snapshot.level {
            return current > snapshot.level
                ? .increased(from: snapshot.level, to: current)
                : .decreased(from: snapshot.level, to: current)
        }

        if snapshot.attemptsAtCurrentLevel >= minimumAttemptsToPromote,
           snapshot.ewma >= promoteThreshold {
            let next = current.increased().clamped(to: range)
            return next == current ? .unchanged(current) : .increased(from: current, to: next)
        }

        if snapshot.attemptsAtCurrentLevel >= minimumAttemptsToDemote,
           snapshot.ewma <= demoteThreshold {
            let next = current.decreased().clamped(to: range)
            return next == current ? .unchanged(current) : .decreased(from: current, to: next)
        }

        return .unchanged(current)
    }

    /// レベルが変わったスナップショットを返す（現レベルの回答数はリセット）。
    public func applying(
        adjustment: DifficultyAdjustment,
        to snapshot: MasterySnapshot
    ) -> MasterySnapshot {
        var updated = snapshot
        updated.level = adjustment.level
        if adjustment.didChange {
            updated.attemptsAtCurrentLevel = 0
            // レベル変更直後は判断材料をリセットし、極端な上下動を防ぐ。
            updated.ewma = MasterySnapshot.initialEWMA
        }
        return updated
    }

    /// 直近の回答から「復習が必要か」を判定する。
    /// `unclear`（聞き取れなかった）は連続不正解に数えない。
    public func needsReview(recentAttempts: [AttemptRecord], skill: Skill) -> Bool {
        let relevant = recentAttempts
            .filter { $0.skill == skill && $0.judgement.countsTowardMastery }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(consecutiveMissesForReview)
        guard relevant.count >= consecutiveMissesForReview else { return false }
        return relevant.allSatisfy { !$0.judgement.isCorrect }
    }

    /// 復習時に使う、1 段やさしいレベル。
    public func reviewLevel(for level: DifficultyLevel, mode: DifficultyMode) -> DifficultyLevel {
        level.decreased().clamped(to: mode.allowedRange)
    }
}
