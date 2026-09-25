import Foundation

/// セッション結果を反映した後の変化。
public struct LearningResultOutcome: Equatable, Sendable {
    public let newlyUnlocked: [UnlockableItem]
    public let adjustments: [Skill: DifficultyAdjustment]
    public let summary: ProgressSummary

    public init(
        newlyUnlocked: [UnlockableItem],
        adjustments: [Skill: DifficultyAdjustment],
        summary: ProgressSummary
    ) {
        self.newlyUnlocked = newlyUnlocked
        self.adjustments = adjustments
        self.summary = summary
    }
}

/// セッション結果の保存・習熟度更新・難易度調整・アンロック判定をまとめて行う。
public struct LearningResultProcessor {
    private let estimator: MasteryEstimator
    private let difficultyEngine: AdaptiveDifficultyEngine
    private let unlockEvaluator: UnlockEvaluator
    private let aggregator: ProgressAggregator

    public init(
        estimator: MasteryEstimator = MasteryEstimator(),
        difficultyEngine: AdaptiveDifficultyEngine = AdaptiveDifficultyEngine(),
        unlockEvaluator: UnlockEvaluator = UnlockEvaluator(),
        aggregator: ProgressAggregator = ProgressAggregator()
    ) {
        self.estimator = estimator
        self.difficultyEngine = difficultyEngine
        self.unlockEvaluator = unlockEvaluator
        self.aggregator = aggregator
    }

    /// 学習セッションの結果を保存する。
    @discardableResult
    public func process(
        summary: SessionSummary,
        settings: AppSettings,
        store: LearningHistoryStoring,
        now: Date
    ) -> LearningResultOutcome {
        let previouslyUnlocked = store.unlockedItemIDs()

        for attempt in summary.attempts {
            store.append(attempt: attempt)
        }
        store.append(session: summary.record)

        var snapshots = store.masterySnapshots()
        var adjustments: [Skill: DifficultyAdjustment] = [:]

        for attempt in summary.attempts {
            var snapshot = snapshots[attempt.skill]
                ?? MasterySnapshot(skill: attempt.skill, level: attempt.difficulty)
            snapshot = estimator.apply(attempt: attempt, to: snapshot)
            snapshots[attempt.skill] = snapshot
        }

        // 難易度を見直す
        for (skill, snapshot) in snapshots {
            let adjustment = difficultyEngine.adjust(snapshot: snapshot, mode: settings.difficultyMode)
            if adjustment.didChange {
                adjustments[skill] = adjustment
            }
            let updated = difficultyEngine.applying(adjustment: adjustment, to: snapshot)
            snapshots[skill] = updated
            store.save(snapshot: updated)
        }

        return finalize(
            store: store,
            snapshots: snapshots,
            previouslyUnlocked: previouslyUnlocked,
            adjustments: adjustments,
            now: now
        )
    }

    /// ご飯タイマーの結果を保存する。
    @discardableResult
    public func process(
        meal: MealSessionRecord,
        starsEarned: Int,
        store: LearningHistoryStoring,
        now: Date
    ) -> LearningResultOutcome {
        let previouslyUnlocked = store.unlockedItemIDs()
        store.append(mealSession: meal)
        // ★はセッション記録として残す（ご飯タイマーも「今日の学習」に数える）。
        store.append(
            session: SessionRecord(
                kind: .mealTimer,
                subject: nil,
                startedAt: meal.startedAt,
                endedAt: meal.startedAt.addingTimeInterval(meal.actualDuration),
                questionCount: 0,
                correctCount: 0,
                starsEarned: starsEarned
            )
        )
        return finalize(
            store: store,
            snapshots: store.masterySnapshots(),
            previouslyUnlocked: previouslyUnlocked,
            adjustments: [:],
            now: now
        )
    }

    private func finalize(
        store: LearningHistoryStoring,
        snapshots: [Skill: MasterySnapshot],
        previouslyUnlocked: Set<String>,
        adjustments: [Skill: DifficultyAdjustment],
        now: Date
    ) -> LearningResultOutcome {
        let progressSummary = aggregator.summarize(
            attempts: store.attempts(),
            sessions: store.sessions(),
            mealSessions: store.mealSessions(),
            snapshots: snapshots,
            now: now
        )
        let unlockProgress = aggregator.unlockProgress(from: progressSummary, snapshots: snapshots)
        let newlyUnlocked = unlockEvaluator.newlyUnlocked(
            previouslyUnlocked: previouslyUnlocked,
            progress: unlockProgress
        )
        if !newlyUnlocked.isEmpty {
            store.markUnlocked(itemIDs: Set(newlyUnlocked.map(\.id)), at: now)
        }
        return LearningResultOutcome(
            newlyUnlocked: newlyUnlocked,
            adjustments: adjustments,
            summary: progressSummary
        )
    }
}
