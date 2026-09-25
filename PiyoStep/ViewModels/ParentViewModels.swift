import Foundation
import Observation
import PiyoCore

/// 保護者画面に入るためのゲート。
@MainActor
@Observable
final class ParentGateViewModel {
    private let random: RandomSource

    private(set) var challenge: ParentGateChallenge
    private(set) var failedAttempts: Int = 0
    var input: String = ""
    private(set) var didPass: Bool = false

    init(random: RandomSource = SystemRandomSource()) {
        self.random = random
        self.challenge = ParentGate.makeChallenge(random: random)
    }

    var questionText: String { challenge.questionText }

    func append(digit: Int) {
        guard input.count < 3 else { return }
        input += "\(digit)"
    }

    func clear() {
        input = ""
    }

    @discardableResult
    func submit() -> Bool {
        guard let value = Int(input) else {
            regenerate()
            return false
        }
        if challenge.isCorrect(value) {
            didPass = true
            return true
        }
        failedAttempts += 1
        regenerate()
        return false
    }

    private func regenerate() {
        input = ""
        challenge = ParentGate.makeChallenge(random: random)
    }

    func reset() {
        didPass = false
        failedAttempts = 0
        regenerate()
    }
}

/// 保護者向けの設定画面。
@MainActor
@Observable
final class SettingsViewModel {
    private let environment: AppEnvironment

    var draft: AppSettings
    var childName: String
    var childAge: Int
    var buddyCharacterID: String

    init(environment: AppEnvironment) {
        self.environment = environment
        self.draft = environment.settings
        self.childName = environment.profile?.nickname ?? ""
        self.childAge = environment.profile?.age ?? 4
        self.buddyCharacterID = environment.profile?.buddyCharacterID ?? CharacterCatalog.defaultCharacterID
    }

    var availableCharacters: [CharacterDefinition] {
        environment.availableCharacters
    }

    var mealDurationPresets: [Int] { AppSettings.mealDurationPresets }

    /// 変更を保存する。画面を閉じるとき・値が変わるたびに呼ぶ。
    func apply() {
        environment.update(settings: draft)
        let profile = ChildProfile(
            id: environment.profile?.id ?? UUID(),
            nickname: childName,
            age: childAge,
            buddyCharacterID: buddyCharacterID,
            createdAt: environment.profile?.createdAt ?? environment.clock.now
        )
        environment.save(profile: profile)
    }

    func toggle(subject: Subject) {
        var subjects = draft.enabledSubjects
        if subjects.contains(subject) {
            // 最後の 1 つは外せないようにする（学習が空にならないため）。
            guard subjects.count > 1 else { return }
            subjects.remove(subject)
        } else {
            subjects.insert(subject)
        }
        draft.enabledSubjects = subjects
        apply()
    }

    func isEnabled(subject: Subject) -> Bool {
        draft.enabledSubjects.contains(subject)
    }
}

/// 保護者向けの習熟度画面。
@MainActor
@Observable
final class ParentDashboardViewModel {
    private let environment: AppEnvironment

    private(set) var summary: ProgressSummary = .empty

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    func refresh() {
        environment.refreshProgress()
        summary = environment.progress
    }

    var childName: String {
        environment.profile?.nickname ?? "おこさま"
    }

    /// 直近 7 日のグラフ用データ。
    var weeklyStats: [DailyStat] {
        summary.dailyStats
    }

    var maximumDailyQuestions: Int {
        max(1, weeklyStats.map(\.questionCount).max() ?? 1)
    }

    var accuracyText: String {
        guard let accuracy = summary.overallAccuracy else { return "—" }
        return "\(Int((accuracy * 100).rounded()))%"
    }

    var totalStudyMinutes: Int {
        Int((summary.totalStudySeconds / 60).rounded())
    }

    func formattedDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.calendar = .piyo
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }

    func formattedDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.calendar = .piyo
        formatter.dateFormat = "M/d HH:mm"
        return formatter.string(from: date)
    }
}
