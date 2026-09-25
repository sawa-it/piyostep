import Foundation

/// アンロック条件を評価する。
public struct UnlockEvaluator {
    private let catalog: [UnlockableItem]

    public init(catalog: [UnlockableItem] = UnlockCatalog.all) {
        self.catalog = catalog
    }

    /// 条件を満たしているか。
    public func isSatisfied(_ condition: UnlockCondition, progress: UnlockProgress) -> Bool {
        switch condition {
        case .always:
            return true
        case .totalStars(let required):
            return progress.totalStars >= required
        case .learningDays(let required):
            return progress.learningDays >= required
        case .mealsCompleted(let required):
            return progress.mealsCompleted >= required
        case .challengesCompleted(let required):
            return progress.challengesCompleted >= required
        case .subjectMastery(let subject, let required):
            return (progress.subjectMastery[subject] ?? 0) >= required
        }
    }

    /// 現在の進捗で解放されているアイテム ID。
    public func unlockedIDs(progress: UnlockProgress) -> Set<String> {
        Set(catalog.filter { isSatisfied($0.condition, progress: progress) }.map(\.id))
    }

    /// 前回から新たに解放されたアイテム。演出に使う。
    public func newlyUnlocked(
        previouslyUnlocked: Set<String>,
        progress: UnlockProgress
    ) -> [UnlockableItem] {
        let current = unlockedIDs(progress: progress)
        let newIDs = current.subtracting(previouslyUnlocked)
        return catalog
            .filter { newIDs.contains($0.id) }
            .sorted { $0.id < $1.id }
    }

    /// 「あと少しで解放されるもの」を 1 つ返す（図鑑のモチベーション表示用）。
    public func nextGoal(progress: UnlockProgress, unlocked: Set<String>) -> UnlockableItem? {
        let locked = catalog.filter { !unlocked.contains($0.id) }
        return locked.min { lhs, rhs in
            remainingEffort(for: lhs.condition, progress: progress)
                < remainingEffort(for: rhs.condition, progress: progress)
        }
    }

    /// 条件達成までの残り度合い（小さいほど近い）。
    func remainingEffort(for condition: UnlockCondition, progress: UnlockProgress) -> Double {
        switch condition {
        case .always:
            return 0
        case .totalStars(let required):
            return Double(max(0, required - progress.totalStars)) / 10.0
        case .learningDays(let required):
            return Double(max(0, required - progress.learningDays))
        case .mealsCompleted(let required):
            return Double(max(0, required - progress.mealsCompleted)) * 1.5
        case .challengesCompleted(let required):
            return Double(max(0, required - progress.challengesCompleted)) * 1.2
        case .subjectMastery(let subject, let required):
            let current = progress.subjectMastery[subject] ?? 0
            return max(0, required - current) * 20.0
        }
    }

    /// 解放済みのキャラクター定義。
    public func availableCharacters(unlocked: Set<String>) -> [CharacterDefinition] {
        let unlockedArtKeys = Set(
            catalog
                .filter { $0.category == .character && unlocked.contains($0.id) }
                .map(\.artKey)
        )
        return CharacterCatalog.all.filter { unlockedArtKeys.contains($0.id) }
    }
}

/// 獲得した★の計算。失敗しても 0 にはしない（参加賞を必ず出す）。
public enum StarRule {
    /// 1 回目で正解 = 2★、やり直して正解 = 1★、最後まで正解できなくても 1★。
    public static func stars(forAttemptIndex attemptIndex: Int, judgement: AnswerJudgement) -> Int {
        guard judgement == .correct else { return 0 }
        return attemptIndex <= 1 ? 2 : 1
    }

    /// セッション終了時に必ず付く参加賞。
    public static let participationStars = 1
}
