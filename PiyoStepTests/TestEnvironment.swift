import Foundation
import XCTest
import PiyoCore
@testable import PiyoStep

/// アプリ層のテストで使う共通の環境。すべての外部依存はモック。
@MainActor
enum TestEnvironment {

    static func makeLaunchArguments(
        reduceAnimations: Bool = true,
        mealSeconds: Int? = nil
    ) -> LaunchArguments {
        LaunchArguments(
            isUITest: true,
            useInMemoryStore: true,
            seededProfileName: nil,
            seededProfileAge: 5,
            forceFreshInstall: false,
            randomSeed: 20_240_401,
            voiceScript: [],
            disableAds: true,
            reduceAnimations: reduceAnimations,
            mealDurationSeconds: mealSeconds
        )
    }

    static func make(
        profile: ChildProfile? = ChildProfile(nickname: "さくら", age: 5),
        settings: AppSettings = .default,
        voiceScript: [String] = [],
        historyStore: LearningHistoryStoring = InMemoryLearningHistoryStore(),
        // @MainActor の型は既定値にできない（既定値の式は nonisolated として
        // 検査されるため）。nil を既定にして、本体で生成する。
        purchaseService: MockPurchaseService? = nil,
        adPresenter: MockAdPresenter? = nil,
        haptics: NoopHapticsService? = nil,
        synthesizer: MockSpeechSynthesizer = MockSpeechSynthesizer(),
        soundPlayer: MockSoundPlayer = MockSoundPlayer(),
        recognizer: SpeechRecognizing? = nil,
        launchArguments: LaunchArguments? = nil,
        seed: UInt64 = 20_240_401
    ) -> AppEnvironment {
        let keyValueStore = InMemoryKeyValueStore()
        let settingsStore = CodableSettingsStore(store: keyValueStore)
        settingsStore.save(settings)
        settingsStore.saveProfile(profile)

        let environment = AppEnvironment(
            settingsStore: settingsStore,
            historyStore: historyStore,
            speechRecognizer: recognizer ?? ScriptedSpeechRecognizer(transcripts: voiceScript),
            speechSynthesizer: synthesizer,
            soundPlayer: soundPlayer,
            haptics: haptics ?? NoopHapticsService(),
            purchaseService: purchaseService ?? MockPurchaseService(),
            adPresenter: adPresenter ?? MockAdPresenter(allow: true),
            random: SeededRandomSource(seed: seed),
            clock: SystemClock(),
            launchArguments: launchArguments ?? makeLaunchArguments()
        )
        environment.bootstrap()
        return environment
    }

    /// 決まった答えの問題をつくる。
    static func integerQuestion(correct: Int = 3, skill: Skill = .numberCount) -> Question {
        let values = [correct, correct + 1, correct + 2, max(0, correct - 1)]
        let choices = values.enumerated().map { index, value in
            AnswerChoice(
                label: "\(value)",
                spokenText: "\(value)",
                display: .number(value),
                isCorrect: index == 0
            )
        }
        return Question(
            skill: skill,
            difficulty: .level1,
            prompt: Prompt(displayText: "いくつ？", spokenText: "いくつ かな？", hintText: "かぞえてみよう"),
            content: .countObjects(kind: .apple, count: correct),
            answer: .integer(correct),
            answerModes: [.choice, .numberPad, .voice],
            choices: choices
        )
    }

    static func traceQuestion() -> Question {
        let card = KanaCatalog.teachable[0]
        return Question(
            skill: .hiraganaWrite,
            difficulty: .level1,
            prompt: Prompt(displayText: "なぞろう", spokenText: "なぞってみよう"),
            content: .kanaCard(card: card, task: .trace),
            answer: .trace(requiredCoverage: 0.5),
            answerModes: [.trace],
            choices: [
                AnswerChoice(
                    label: card.hiragana,
                    spokenText: card.hiragana,
                    display: .text(card.hiragana),
                    isCorrect: true
                )
            ]
        )
    }

    /// 非同期な状態変化を待つ。
    static func wait(
        for description: String = "condition",
        timeout: TimeInterval = 2.0,
        until condition: @escaping () -> Bool
    ) {
        let expectation = XCTestExpectation(description: description)
        let deadline = Date().addingTimeInterval(timeout)

        func poll() {
            if condition() {
                expectation.fulfill()
                return
            }
            if Date() > deadline { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                poll()
            }
        }
        poll()
        _ = XCTWaiter().wait(for: [expectation], timeout: timeout + 0.5)
    }
}
