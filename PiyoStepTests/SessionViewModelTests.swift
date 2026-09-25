import XCTest
import PiyoCore
@testable import PiyoStep

@MainActor
final class SessionViewModelTests: XCTestCase {

    private func makeModel(
        environment: AppEnvironment,
        questions: [Question]
    ) -> SessionViewModel {
        let model = SessionViewModel(
            environment: environment,
            kind: .dailyChallenge,
            subject: nil,
            questions: questions
        )
        model.start()
        return model
    }

    /// 「こえで こたえる」問題（answerModes の先頭が .voice）。
    private func voiceFirstQuestion(correct: Int = 3) -> Question {
        let base = TestEnvironment.integerQuestion(correct: correct)
        return Question(
            skill: .numberRead,
            difficulty: .level1,
            prompt: Prompt(
                displayText: "なんて よむ？",
                spokenText: "この すうじ、なんて よむ かな？",
                hintText: "こえで いってみよう",
                tapFallbackSpokenText: "\(correct)は どれ かな？"
            ),
            content: .numberRead(value: correct),
            answer: .integer(correct),
            answerModes: [.voice, .choice],
            choices: base.choices
        )
    }

    func testStartPresentsFirstQuestion() {
        let environment = TestEnvironment.make()
        let model = makeModel(
            environment: environment,
            questions: [TestEnvironment.integerQuestion(correct: 3)]
        )
        XCTAssertEqual(model.stage, .asking)
        XCTAssertEqual(model.currentQuestion?.answer, .integer(3))
        XCTAssertEqual(model.totalCount, 1)
        XCTAssertEqual(model.progressCount, 0)
    }

    func testStartReadsThePromptAloud() {
        let synthesizer = MockSpeechSynthesizer()
        let environment = TestEnvironment.make(synthesizer: synthesizer)
        _ = makeModel(environment: environment, questions: [TestEnvironment.integerQuestion()])
        XCTAssertTrue(synthesizer.spokenTexts.contains("いくつ かな？"))
    }

    func testVoiceGuidanceCanBeSilenced() {
        var settings = AppSettings.default
        settings.voiceGuidanceEnabled = false
        let synthesizer = MockSpeechSynthesizer()
        let environment = TestEnvironment.make(settings: settings, synthesizer: synthesizer)
        _ = makeModel(environment: environment, questions: [TestEnvironment.integerQuestion()])
        XCTAssertTrue(synthesizer.spokenTexts.isEmpty)
    }

    // MARK: - 答え方は切り替えない

    func testTapInputIsChosenPerQuestionAndNeverTheNumberPad() {
        let environment = TestEnvironment.make()
        let time = ClockTime(hour: 3, minute: 30)
        let clockQuestion = Question(
            skill: .clockRead,
            difficulty: .level3,
            prompt: Prompt(displayText: "なんじ？", spokenText: "なんじ かな？"),
            content: .clockRead(time: time),
            answer: .time(time, toleranceMinutes: 0),
            answerModes: [.numberPad, .choice, .voice],
            choices: TestEnvironment.integerQuestion().choices
        )
        let model = makeModel(environment: environment, questions: [clockQuestion])
        XCTAssertEqual(model.tapMode, .choice, "数字入力は幼児には扱えないので選ばない")
        XCTAssertTrue(model.showsTapInput)
        XCTAssertFalse(model.isVoiceFirst)
    }

    func testTapFirstQuestionShowsChoicesAndListensAtTheSameTime() {
        let environment = TestEnvironment.make(voiceScript: ["さん"])
        let model = makeModel(
            environment: environment,
            questions: [TestEnvironment.integerQuestion(correct: 3)]
        )
        XCTAssertTrue(model.showsTapInput, "選択肢は最初から出ている")
        XCTAssertTrue(model.showsVoiceStatus, "声も同時に聞いている")
        TestEnvironment.wait(until: { model.isListening })
        XCTAssertTrue(model.isListening, "マイクを押さなくても聞き始める")
    }

    // MARK: - 選択肢

    func testChoosingTheCorrectAnswerGivesPositiveFeedback() {
        let environment = TestEnvironment.make()
        let question = TestEnvironment.integerQuestion(correct: 3)
        let model = makeModel(environment: environment, questions: [question])

        guard let correct = question.choices.first(where: \.isCorrect) else {
            return XCTFail("正解の選択肢がない")
        }
        model.select(choice: correct)

        XCTAssertEqual(model.stage, .feedback)
        XCTAssertEqual(model.feedback?.judgement, .correct)
        XCTAssertEqual(model.feedback?.starsEarned, 2)
        XCTAssertTrue(model.showsConfetti)
        XCTAssertFalse(model.isListening, "答えたら聞き取りは止める")
    }

    func testWrongAnswerAllowsRetryWithHint() {
        let environment = TestEnvironment.make()
        let question = TestEnvironment.integerQuestion(correct: 3)
        let model = makeModel(environment: environment, questions: [question])

        guard let wrong = question.choices.first(where: { !$0.isCorrect }) else {
            return XCTFail("誤答の選択肢がない")
        }
        model.select(choice: wrong)
        XCTAssertEqual(model.feedback?.judgement, .incorrect)
        XCTAssertTrue(model.feedback?.canRetry ?? false)

        model.retryCurrentQuestion()
        XCTAssertEqual(model.stage, .asking)
        XCTAssertTrue(model.showsHint)
        XCTAssertEqual(model.visibleChoices.count, 2, "ヒント時は選択肢を減らす")
        XCTAssertTrue(model.visibleChoices.contains(where: \.isCorrect))
    }

    func testCorrectAnswerAdvancesWithoutTappingNext() {
        let environment = TestEnvironment.make()
        let questions = [
            TestEnvironment.integerQuestion(correct: 1),
            TestEnvironment.integerQuestion(correct: 2)
        ]
        let model = makeModel(environment: environment, questions: questions)
        model.autoAdvanceDelay = 0.1

        model.selectCorrectChoice()
        XCTAssertEqual(model.stage, .feedback)

        TestEnvironment.wait(until: { model.progressCount == 1 })
        XCTAssertEqual(model.progressCount, 1, "「つぎへ」を押さなくても次の問題へ進む")
        XCTAssertEqual(model.stage, .asking)
    }

    func testWrongAnswerWaitsForTheChildToRetry() {
        let environment = TestEnvironment.make()
        let question = TestEnvironment.integerQuestion(correct: 3)
        let model = makeModel(environment: environment, questions: [question])
        model.autoAdvanceDelay = 0.05

        guard let wrong = question.choices.first(where: { !$0.isCorrect }) else {
            return XCTFail("誤答の選択肢がない")
        }
        model.select(choice: wrong)
        RunLoop.main.run(until: Date().addingTimeInterval(0.4))
        XCTAssertEqual(model.stage, .feedback, "まちがえたときは自動で進まない")
    }

    // MARK: - 時計・なぞり書き

    func testDraggedClockAnswer() {
        let environment = TestEnvironment.make()
        let target = ClockTime(hour: 7, minute: 0)
        let question = Question(
            skill: .clockSet,
            difficulty: .level1,
            prompt: Prompt(displayText: "7じに してね", spokenText: "7時に してね"),
            content: .clockSet(target: target, start: ClockTime(hour: 12, minute: 0), minuteStep: 30),
            answer: .time(target, toleranceMinutes: 0),
            answerModes: [.dragHands],
            choices: []
        )
        let model = makeModel(environment: environment, questions: [question])
        XCTAssertEqual(model.draggedTime, ClockTime(hour: 12, minute: 0), "はじめの位置がセットされる")
        XCTAssertEqual(model.tapMode, .dragHands)
        XCTAssertFalse(model.showsVoiceStatus, "声で答えようのない問題では聞き取りを出さない")

        model.draggedTime = target
        model.submitDraggedTime()
        XCTAssertEqual(model.feedback?.judgement, .correct)
    }

    func testTraceAnswerUsesRenderedGlyph() {
        let environment = TestEnvironment.make()
        let model = makeModel(environment: environment, questions: [TestEnvironment.traceQuestion()])
        XCTAssertEqual(model.tapMode, .trace)

        // キャンバス全体を塗りつぶすように何本も線を引く
        var strokes: [[TracePoint]] = []
        for row in stride(from: 0.05, through: 0.95, by: 0.03) {
            strokes.append([
                TracePoint(x: 0.02, y: row),
                TracePoint(x: 0.98, y: row)
            ])
        }
        model.traceStrokes = strokes
        model.submitTrace()

        XCTAssertEqual(model.feedback?.judgement, .correct, "十分になぞれば正解になる")
    }

    func testTraceSubmitsItselfOnceItIsGoodEnough() {
        let environment = TestEnvironment.make()
        let model = makeModel(environment: environment, questions: [TestEnvironment.traceQuestion()])

        model.traceStrokes = [[TracePoint(x: 0.5, y: 0.5)]]
        XCTAssertFalse(model.autoSubmitTraceIfComplete(), "ちょっと触っただけでは進まない")
        XCTAssertEqual(model.stage, .asking)

        var strokes: [[TracePoint]] = []
        for row in stride(from: 0.05, through: 0.95, by: 0.03) {
            strokes.append([TracePoint(x: 0.02, y: row), TracePoint(x: 0.98, y: row)])
        }
        model.traceStrokes = strokes
        XCTAssertTrue(model.autoSubmitTraceIfComplete(), "なぞれたら「できた！」を押さなくても進む")
        XCTAssertEqual(model.feedback?.judgement, .correct)
    }

    func testEmptyTraceIsNotCorrect() {
        let environment = TestEnvironment.make()
        let model = makeModel(environment: environment, questions: [TestEnvironment.traceQuestion()])
        model.traceStrokes = []
        model.submitTrace()
        XCTAssertEqual(model.feedback?.judgement, .incorrect)
    }

    // MARK: - 進行と保存

    func testAdvancingThroughAllQuestionsFinishesAndSaves() {
        let store = InMemoryLearningHistoryStore()
        let environment = TestEnvironment.make(historyStore: store)
        let questions = [
            TestEnvironment.integerQuestion(correct: 1),
            TestEnvironment.integerQuestion(correct: 2)
        ]
        let model = makeModel(environment: environment, questions: questions)

        model.selectCorrectChoice()
        model.advance()
        model.selectCorrectChoice()
        model.advance()

        XCTAssertEqual(model.stage, .finished)
        XCTAssertEqual(model.summary?.correctCount, 2)
        XCTAssertEqual(store.sessions().count, 1)
        XCTAssertEqual(store.attempts().count, 2)
        XCTAssertGreaterThan(environment.progress.totalStars, 0)
    }

    func testClosingMidSessionStillSavesProgress() {
        let store = InMemoryLearningHistoryStore()
        let environment = TestEnvironment.make(historyStore: store)
        let model = makeModel(
            environment: environment,
            questions: [
                TestEnvironment.integerQuestion(correct: 1),
                TestEnvironment.integerQuestion(correct: 2)
            ]
        )
        model.selectCorrectChoice()
        model.close()

        XCTAssertEqual(store.attempts().count, 1)
        XCTAssertEqual(store.sessions().count, 1)
    }

    func testAdsAreSuppressedDuringLearning() {
        let adPresenter = MockAdPresenter(allow: true)
        let environment = TestEnvironment.make(adPresenter: adPresenter)
        let model = makeModel(environment: environment, questions: [TestEnvironment.integerQuestion()])

        XCTAssertTrue(adPresenter.isLearningSessionActive)
        XCTAssertFalse(adPresenter.shouldPresentParentAd(adsRemoved: false), "学習中は広告を出さない")

        model.selectCorrectChoice()
        model.advance()
        XCTAssertFalse(adPresenter.isLearningSessionActive)
    }

    func testCountingTapsToggle() {
        let environment = TestEnvironment.make()
        let model = makeModel(environment: environment, questions: [TestEnvironment.integerQuestion(correct: 4)])
        model.toggleCounted(index: 0)
        model.toggleCounted(index: 1)
        XCTAssertEqual(model.countedIndices, [0, 1])
        model.toggleCounted(index: 0)
        XCTAssertEqual(model.countedIndices, [1])
    }

    // MARK: - 音声（マイクを押さない）

    func testVoiceAnswerIsHeardWithoutPressingTheMicrophone() {
        let environment = TestEnvironment.make(voiceScript: ["さん"])
        let model = makeModel(
            environment: environment,
            questions: [TestEnvironment.integerQuestion(correct: 3)]
        )
        XCTAssertTrue(model.isVoiceUsable)

        // 何も押さずに待つだけで、問いかけのあと聞き取りが始まり、答えが判定される。
        TestEnvironment.wait(until: { model.stage == .feedback })
        XCTAssertEqual(model.feedback?.judgement, .correct)
    }

    func testUnrecognisedSpeechDoesNotCountAsWrongAndListensAgain() {
        let store = InMemoryLearningHistoryStore()
        let synthesizer = MockSpeechSynthesizer()
        let environment = TestEnvironment.make(
            voiceScript: ["わかんない"],
            historyStore: store,
            synthesizer: synthesizer
        )
        let model = makeModel(
            environment: environment,
            questions: [TestEnvironment.integerQuestion(correct: 3)]
        )

        TestEnvironment.wait(until: { synthesizer.spokenTexts.contains("もういちど いってみよう！") })
        XCTAssertEqual(model.stage, .asking, "聞き取れなかっただけなので問題は進めない")
        XCTAssertNil(model.feedback)
        XCTAssertTrue(store.attempts().isEmpty, "学習履歴にも不正解として残さない")

        // ことばをかけたあと、また聞き始める。
        TestEnvironment.wait(until: { model.isListening })
        XCTAssertTrue(model.isListening)
    }

    func testSilenceIsNotScoldedAndListeningStopsAfterAWhile() {
        let synthesizer = MockSpeechSynthesizer()
        // 台本が空 = 何も聞こえない
        let environment = TestEnvironment.make(voiceScript: [], synthesizer: synthesizer)
        let model = makeModel(
            environment: environment,
            questions: [TestEnvironment.integerQuestion(correct: 3)]
        )

        TestEnvironment.wait(until: { model.silentListenCycles >= SessionViewModel.silentListenLimit })
        RunLoop.main.run(until: Date().addingTimeInterval(0.4))

        XCTAssertFalse(model.isListening, "黙ったままなら聞き取りは止まる")
        XCTAssertTrue(model.canRestartVoice, "マイクを押せばもう一度聞いてもらえる")
        XCTAssertTrue(model.showsTapInput)
        XCTAssertFalse(
            synthesizer.spokenTexts.contains("もういちど いってみよう！"),
            "黙っているだけの子に「もういちど」と言わない"
        )
        XCTAssertEqual(model.stage, .asking)
    }

    func testVoiceFirstQuestionHidesChoicesUntilVoiceGivesUp() {
        let synthesizer = MockSpeechSynthesizer()
        let environment = TestEnvironment.make(voiceScript: [], synthesizer: synthesizer)
        let model = makeModel(environment: environment, questions: [voiceFirstQuestion(correct: 3)])

        XCTAssertTrue(model.isVoiceFirst)
        XCTAssertFalse(model.showsTapInput, "声で答える問題では、答えになる選択肢を先に見せない")

        // 黙ったままなら、しばらくしてタップに切り替わる。
        TestEnvironment.wait(until: { model.showsTapInput })
        XCTAssertTrue(model.hasFallenBackToTap)
        XCTAssertTrue(
            synthesizer.spokenTexts.contains { $0.contains("タップで こたえても いいよ！") && $0.contains("3は どれ かな？") },
            "切り替えを声で知らせ、タップ用の問いかけを読む / \(synthesizer.spokenTexts)"
        )
    }

    func testVoiceFirstQuestionCanSwitchToTapByButton() {
        let environment = TestEnvironment.make(voiceScript: [])
        let model = makeModel(environment: environment, questions: [voiceFirstQuestion(correct: 3)])
        XCTAssertFalse(model.showsTapInput)

        model.chooseTapAnswer()
        XCTAssertTrue(model.showsTapInput)
        XCTAssertFalse(model.isListening)
        XCTAssertEqual(model.spokenPrompt, "3は どれ かな？")
    }

    func testVoiceFirstQuestionFallsBackWhenTheMicrophoneIsDenied() {
        let recognizer = MockSpeechRecognizer(authorizationStatus: .denied)
        let environment = TestEnvironment.make(recognizer: recognizer)
        let model = makeModel(environment: environment, questions: [voiceFirstQuestion(correct: 3)])

        TestEnvironment.wait(until: { model.showsTapInput })
        XCTAssertTrue(model.showsTapInput, "マイクが使えないなら、はじめから選択肢で答えられる")
        XCTAssertFalse(model.showsVoiceStatus)
        XCTAssertFalse(model.isVoiceUsable)
    }

    func testVoiceIsHiddenWhenTurnedOff() {
        var settings = AppSettings.default
        settings.voiceAnswerEnabled = false
        let environment = TestEnvironment.make(settings: settings)
        let model = makeModel(
            environment: environment,
            questions: [TestEnvironment.integerQuestion(correct: 3)]
        )
        XCTAssertFalse(model.isVoiceUsable)
        XCTAssertFalse(model.showsVoiceStatus)
        XCTAssertTrue(model.showsTapInput, "タップ回答は必ず残る")
    }

    func testStaleSpeechResultsAreIgnoredAfterMovingOn() {
        let recognizer = ManualSpeechRecognizer()
        let environment = TestEnvironment.make(recognizer: recognizer)
        let questions = [
            TestEnvironment.integerQuestion(correct: 3),
            TestEnvironment.integerQuestion(correct: 5)
        ]
        let model = makeModel(environment: environment, questions: questions)

        // 1 問目の聞き取りが始まってから、選択肢で答えて次へ進む。
        TestEnvironment.wait(until: { recognizer.sessions.count == 1 })
        let firstSession = recognizer.sessions[0]
        model.selectCorrectChoice()
        model.advance()
        XCTAssertEqual(model.progressCount, 1)
        TestEnvironment.wait(until: { recognizer.sessions.count == 2 })

        // 1 問目のために始めた聞き取りの結果が、あとから届いても 2 問目には使わない。
        firstSession.onResult(SpeechRecognitionResult(transcript: "さん", confidence: 0.9, isFinal: true))
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        XCTAssertEqual(model.stage, .asking, "古い結果で 2 問目が判定されている")
        XCTAssertNil(model.feedback)

        // 2 問目の聞き取りの結果は使う。
        recognizer.sessions[1].onResult(SpeechRecognitionResult(transcript: "ご", confidence: 0.9, isFinal: true))
        TestEnvironment.wait(until: { model.stage == .feedback })
        XCTAssertEqual(model.feedback?.judgement, .correct)
    }
}

/// 聞き取りの結果をテストから手で流し込むための認識器。
private final class ManualSpeechRecognizer: SpeechRecognizing {
    struct Session {
        let locale: RecognitionLocale
        let onResult: (SpeechRecognitionResult) -> Void
        let onFailure: (SpeechRecognitionFailure) -> Void
    }

    var authorizationStatus: SpeechAuthorizationStatus = .authorized
    var audioLevel: Double = 0.5
    private(set) var sessions: [Session] = []

    func isAvailable(for locale: RecognitionLocale) -> Bool { true }

    func requestAuthorization(completion: @escaping (SpeechAuthorizationStatus) -> Void) {
        completion(.authorized)
    }

    func startListening(
        locale: RecognitionLocale,
        onResult: @escaping (SpeechRecognitionResult) -> Void,
        onFailure: @escaping (SpeechRecognitionFailure) -> Void
    ) {
        sessions.append(Session(locale: locale, onResult: onResult, onFailure: onFailure))
    }

    func stopListening() {}
}

private extension SessionViewModel {
    /// テスト用に正解の選択肢を押す。
    func selectCorrectChoice() {
        guard let correct = currentQuestion?.choices.first(where: \.isCorrect) else {
            XCTFail("正解の選択肢がない")
            return
        }
        select(choice: correct)
    }
}
