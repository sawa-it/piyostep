import Foundation
import SwiftData
import PiyoCore

/// SwiftData を使った学習履歴の保存。
/// `PiyoCore` 側は `LearningHistoryStoring` にしか依存しないので、
/// テストではインメモリ実装に差し替えられる。
final class SwiftDataLearningHistoryStore: LearningHistoryStoring {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - 追加

    func append(attempt: AttemptRecord) {
        context.insert(AttemptEntity(record: attempt))
        persist()
    }

    func append(session: SessionRecord) {
        context.insert(SessionEntity(record: session))
        persist()
    }

    func append(mealSession: MealSessionRecord) {
        context.insert(MealSessionEntity(record: mealSession))
        persist()
    }

    // MARK: - 取得

    func attempts(limit: Int?) -> [AttemptRecord] {
        let entities: [AttemptEntity] = fetch(
            sortBy: [SortDescriptor(\AttemptEntity.createdAt, order: .reverse)],
            limit: limit
        )
        return entities.compactMap(\.record)
    }

    func sessions(limit: Int?) -> [SessionRecord] {
        let entities: [SessionEntity] = fetch(
            sortBy: [SortDescriptor(\SessionEntity.startedAt, order: .reverse)],
            limit: limit
        )
        return entities.compactMap(\.record)
    }

    func mealSessions(limit: Int?) -> [MealSessionRecord] {
        let entities: [MealSessionEntity] = fetch(
            sortBy: [SortDescriptor(\MealSessionEntity.startedAt, order: .reverse)],
            limit: limit
        )
        return entities.map(\.record)
    }

    func masterySnapshots() -> [Skill: MasterySnapshot] {
        let entities: [MasteryEntity] = fetch(sortBy: [], limit: nil)
        var result: [Skill: MasterySnapshot] = [:]
        for entity in entities {
            if let snapshot = entity.snapshot {
                result[snapshot.skill] = snapshot
            }
        }
        return result
    }

    func save(snapshot: MasterySnapshot) {
        let entities: [MasteryEntity] = fetch(sortBy: [], limit: nil)
        if let existing = entities.first(where: { $0.skillRaw == snapshot.skill.rawValue }) {
            existing.apply(snapshot)
        } else {
            context.insert(MasteryEntity(snapshot: snapshot))
        }
        persist()
    }

    func unlockedItemIDs() -> Set<String> {
        let entities: [UnlockEntity] = fetch(sortBy: [], limit: nil)
        let stored = Set(entities.map(\.itemID))
        // 初期解放アイテムは常に含める。
        return stored.union(UnlockCatalog.initiallyUnlockedIDs)
    }

    func markUnlocked(itemIDs: Set<String>, at date: Date) {
        let existing = unlockedItemIDs()
        for id in itemIDs.subtracting(existing) {
            context.insert(UnlockEntity(itemID: id, unlockedAt: date))
        }
        persist()
    }

    func unlockRecords() -> [UnlockRecord] {
        let entities: [UnlockEntity] = fetch(
            sortBy: [SortDescriptor(\UnlockEntity.unlockedAt, order: .forward)],
            limit: nil
        )
        return entities.map { UnlockRecord(itemID: $0.itemID, unlockedAt: $0.unlockedAt) }
    }

    // MARK: - 共通

    private func fetch<T: PersistentModel>(sortBy: [SortDescriptor<T>], limit: Int?) -> [T] {
        var descriptor = FetchDescriptor<T>(sortBy: sortBy)
        if let limit {
            descriptor.fetchLimit = limit
        }
        do {
            return try context.fetch(descriptor)
        } catch {
            // 保存層の失敗で学習が止まらないようにする。
            return []
        }
    }

    private func persist() {
        guard context.hasChanges else { return }
        try? context.save()
    }
}
