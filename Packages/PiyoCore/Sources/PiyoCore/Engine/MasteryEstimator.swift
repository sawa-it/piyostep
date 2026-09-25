import Foundation

/// 回答履歴から Skill ごとの習熟度を推定する。
public struct MasteryEstimator {
    /// 指数移動平均の係数。
    public let alpha: Double
    /// 直近の正答率を見るウィンドウ幅。
    public let windowSize: Int

    public init(alpha: Double = 0.3, windowSize: Int = 30) {
        self.alpha = min(max(alpha, 0.01), 1.0)
        self.windowSize = max(1, windowSize)
    }

    /// 1 回答を反映した新しいスナップショットを返す。
    /// `unclear`（聞き取れなかった）は習熟度に影響させない。
    public func apply(
        attempt: AttemptRecord,
        to snapshot: MasterySnapshot
    ) -> MasterySnapshot {
        var updated = snapshot
        updated.lastPracticedAt = attempt.createdAt

        guard attempt.judgement.countsTowardMastery else {
            return updated
        }

        let outcome = attempt.judgement.isCorrect ? 1.0 : 0.0
        updated.ewma = updated.ewma * (1 - alpha) + outcome * alpha
        updated.attempts += 1
        updated.attemptsAtCurrentLevel += 1
        if attempt.judgement.isCorrect {
            updated.correctCount += 1
        }
        return updated
    }

    /// 履歴全体から Skill ごとのスナップショットを再計算する。
    public func snapshots(from attempts: [AttemptRecord]) -> [Skill: MasterySnapshot] {
        var result: [Skill: MasterySnapshot] = [:]
        let sorted = attempts.sorted { $0.createdAt < $1.createdAt }
        for attempt in sorted {
            var snapshot = result[attempt.skill] ?? MasterySnapshot(skill: attempt.skill, level: attempt.difficulty)
            snapshot = apply(attempt: attempt, to: snapshot)
            // 履歴から復元するときは、最後に解いた難易度を現在レベルとみなす。
            snapshot.level = attempt.difficulty
            result[attempt.skill] = snapshot
        }
        return result
    }

    /// 直近 `windowSize` 件の正答率。集計対象が無ければ nil。
    public func recentAccuracy(for skill: Skill, in attempts: [AttemptRecord]) -> Double? {
        let relevant = attempts
            .filter { $0.skill == skill && $0.judgement.countsTowardMastery }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(windowSize)
        guard !relevant.isEmpty else { return nil }
        let correct = relevant.filter { $0.judgement.isCorrect }.count
        return Double(correct) / Double(relevant.count)
    }

    /// ewma と直近正答率を合成した習熟スコア（0.0 - 1.0）。
    public func masteryScore(
        snapshot: MasterySnapshot,
        recentAccuracy: Double?
    ) -> Double {
        guard let accuracy = recentAccuracy else { return snapshot.masteryScore }
        let blendedEWMA = 0.7 * snapshot.ewma + 0.3 * accuracy
        var blended = snapshot
        blended.ewma = blendedEWMA
        return blended.masteryScore
    }

    /// 教科ごとの習熟度（所属 Skill の平均）。
    public func subjectMastery(from snapshots: [Skill: MasterySnapshot]) -> [Subject: Double] {
        var result: [Subject: Double] = [:]
        for subject in Subject.allCases {
            let scores = subject.skills.compactMap { snapshots[$0]?.masteryScore }
            guard !scores.isEmpty else { continue }
            result[subject] = scores.reduce(0, +) / Double(scores.count)
        }
        return result
    }
}
