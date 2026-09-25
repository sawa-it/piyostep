import Foundation
import Observation
import PiyoCore

/// ご飯タイマー（キャラクターとの競争）の画面ロジック。
@MainActor
@Observable
final class MealRaceViewModel {

    enum Stage: Equatable {
        case ready
        case countdown(Int)
        case racing
        case finished
    }

    private let environment: AppEnvironment
    private(set) var engine: MealRaceEngine
    private var timer: Timer?
    private var startedAt: Date?
    private var hasAnnouncedCharacterFinish = false

    private(set) var stage: Stage = .ready
    private(set) var elapsed: TimeInterval = 0
    private(set) var bites: Int = 0
    private(set) var snapshot: MealRaceSnapshot
    private(set) var characterMessage: String = ""
    private(set) var result: MealRaceResult?

    /// タイマーの刻み。UI テストでは短くする。
    private let tickInterval: TimeInterval = 0.5

    init(environment: AppEnvironment) {
        self.environment = environment
        let configuration = environment.makeMealConfiguration()
        let raceEngine = MealRaceEngine(configuration: configuration)
        self.engine = raceEngine
        self.snapshot = raceEngine.snapshot(at: 0, bites: 0)
        self.characterMessage = raceEngine.character.raceIntroLine
    }

    var character: CharacterDefinition { engine.character }
    var childName: String { environment.profile?.callName ?? "きみ" }

    var targetMinutes: Int {
        Int((engine.configuration.targetDuration / 60).rounded())
    }

    var remainingText: String {
        let remaining = Int(snapshot.remainingToTarget.rounded())
        let minutes = remaining / 60
        let seconds = remaining % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// キャラクターの今の様子（イラスト用）。
    var characterMood: CharacterMood {
        switch snapshot.characterActivity {
        case .eating: return .eating
        case .resting: return .resting
        case .cheering: return .cheering
        case .finished: return .cheering
        }
    }

    /// 子ども側のお皿の残り。
    var childPlateFullness: Double {
        max(0, 1 - snapshot.childProgress)
    }

    /// キャラクター側のお皿の残り。
    var characterPlateFullness: Double {
        max(0, 1 - snapshot.characterProgress)
    }

    // MARK: - 進行

    func begin() {
        guard stage == .ready else { return }
        environment.adPresenter.isLearningSessionActive = true
        // 準備画面が開いたときに同じ台詞を読んでいる。ここで読み直すと
        // カウントダウンの音とかぶるので、読み上げは止めて数字だけにする。
        environment.stopSpeaking()
        runCountdown(from: 3)
    }

    private func runCountdown(from value: Int) {
        guard value > 0 else {
            startRace()
            return
        }
        stage = .countdown(value)
        environment.play(.tap)
        let delay = environment.launchArguments.reduceAnimations ? 0.15 : 0.9
        Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.runCountdown(from: value - 1)
            }
        }
    }

    private func startRace() {
        stage = .racing
        startedAt = environment.clock.now
        elapsed = 0
        bites = 0
        hasAnnouncedCharacterFinish = false
        characterMessage = engine.character.eatLine
        environment.play(.mealStart)
        updateSnapshot()

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    private func tick() {
        guard stage == .racing, let startedAt else { return }
        elapsed = environment.clock.now.timeIntervalSince(startedAt)
        updateSnapshot()

        if engine.hasCharacterFinished(at: elapsed), !hasAnnouncedCharacterFinish {
            hasAnnouncedCharacterFinish = true
            // 「まけ」ではなく、応援に切り替える。
            characterMessage = engine.character.characterFinishedLine
            environment.speak(characterMessage)
        }
    }

    private func updateSnapshot() {
        snapshot = engine.snapshot(at: elapsed, bites: bites)
        if !hasAnnouncedCharacterFinish {
            characterMessage = engine.message(at: elapsed, childName: childName)
        }
    }

    /// 「もぐもぐ」タップ。自分のごはんが少し進む。
    func takeBite() {
        guard stage == .racing else { return }
        bites += 1
        environment.haptics.softNudge()
        environment.play(.tap)
        updateSnapshot()
    }

    /// 「たべおわった！」
    func finish() {
        guard stage != .finished, stage != .ready else { return }
        timer?.invalidate()
        timer = nil

        let outcome = engine.finish(at: elapsed, childName: childName)
        result = outcome
        stage = .finished
        environment.adPresenter.isLearningSessionActive = false
        environment.play(.mealFinish)
        environment.haptics.success()
        // 効果音が鳴り終わってから話す。
        environment.speakAfterSound("\(outcome.headline) \(outcome.subline)")

        let record = MealSessionRecord(
            characterID: engine.character.id,
            targetDuration: engine.configuration.targetDuration,
            actualDuration: elapsed,
            childFinishedFirst: outcome.childFinishedFirst,
            startedAt: startedAt ?? environment.clock.now
        )
        environment.process(meal: record, starsEarned: outcome.starsEarned)
    }

    /// 画面を閉じるときの後始末。
    func cancel() {
        timer?.invalidate()
        timer = nil
        environment.adPresenter.isLearningSessionActive = false
        environment.stopSpeaking()
    }
}
