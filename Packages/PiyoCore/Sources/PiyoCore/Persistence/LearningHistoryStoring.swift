import Foundation

/// 学習履歴の保存先。アプリでは SwiftData 実装を、テストではインメモリ実装を使う。
public protocol LearningHistoryStoring: AnyObject {
    func append(attempt: AttemptRecord)
    func append(session: SessionRecord)
    func append(mealSession: MealSessionRecord)

    /// 新しい順に最大 `limit` 件。`limit` が nil ならすべて。
    func attempts(limit: Int?) -> [AttemptRecord]
    func sessions(limit: Int?) -> [SessionRecord]
    func mealSessions(limit: Int?) -> [MealSessionRecord]

    func masterySnapshots() -> [Skill: MasterySnapshot]
    func save(snapshot: MasterySnapshot)

    func unlockedItemIDs() -> Set<String>
    func markUnlocked(itemIDs: Set<String>, at date: Date)
}

extension LearningHistoryStoring {
    public func attempts() -> [AttemptRecord] { attempts(limit: nil) }
    public func sessions() -> [SessionRecord] { sessions(limit: nil) }
    public func mealSessions() -> [MealSessionRecord] { mealSessions(limit: nil) }
}

/// テスト・プレビュー用のインメモリ実装。
public final class InMemoryLearningHistoryStore: LearningHistoryStoring {
    private var attemptRecords: [AttemptRecord] = []
    private var sessionRecords: [SessionRecord] = []
    private var mealRecords: [MealSessionRecord] = []
    private var snapshots: [Skill: MasterySnapshot] = [:]
    private var unlocked: Set<String>

    public init(unlocked: Set<String> = UnlockCatalog.initiallyUnlockedIDs) {
        self.unlocked = unlocked
    }

    public func append(attempt: AttemptRecord) {
        attemptRecords.append(attempt)
    }

    public func append(session: SessionRecord) {
        sessionRecords.append(session)
    }

    public func append(mealSession: MealSessionRecord) {
        mealRecords.append(mealSession)
    }

    public func attempts(limit: Int?) -> [AttemptRecord] {
        let sorted = attemptRecords.sorted { $0.createdAt > $1.createdAt }
        guard let limit else { return sorted }
        return Array(sorted.prefix(limit))
    }

    public func sessions(limit: Int?) -> [SessionRecord] {
        let sorted = sessionRecords.sorted { $0.startedAt > $1.startedAt }
        guard let limit else { return sorted }
        return Array(sorted.prefix(limit))
    }

    public func mealSessions(limit: Int?) -> [MealSessionRecord] {
        let sorted = mealRecords.sorted { $0.startedAt > $1.startedAt }
        guard let limit else { return sorted }
        return Array(sorted.prefix(limit))
    }

    public func masterySnapshots() -> [Skill: MasterySnapshot] {
        snapshots
    }

    public func save(snapshot: MasterySnapshot) {
        snapshots[snapshot.skill] = snapshot
    }

    public func unlockedItemIDs() -> Set<String> {
        unlocked
    }

    public func markUnlocked(itemIDs: Set<String>, at date: Date) {
        unlocked.formUnion(itemIDs)
    }
}
