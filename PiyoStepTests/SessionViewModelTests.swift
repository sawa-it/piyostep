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

    func testNumberPadInput() {
        let environment = TestEnvironment.make()
        let model = makeModel(
            environment: environment,
            questions: [TestEnvironment.integerQuestion(correct: 12)]
        )
        model.answerMode = .numberPad
        model.appendDigit(1)
        model.appendDigit(2)
        XCTAssertEqual(model.numberInput, "12")
        model.submitNumberInput()
        XCTAssertEqual(model.feedback?.judgement, .correct)
    }

    func testNumberPadClear() {
        let environment = TestEnvironment.make()
        let model = makeModel(environment: environment, questions: [TestEnvironment.integerQuestion()])
        model.answerMode = .numberPad
        model.appendDigit(9)
        model.clearInput()
        XCTAssertTrue(model.numberInput.isEmpty)
    }

    func testClockTimeInputUsesTwoFields() {
        let environment = TestEnvironment.make()
        let time = ClockTime(hour: 3, minute: 30)
        let question = Question(
            skill: .clockRead,
            difficulty: .level3,
            prompt: Prompt(displayText: "なんじ？", spokenText: "なんじ かな？"),
            content: .clockRead(time: time),
            answer: .time(time, toleranceMinutes: 0),
            answerModes: [.numberPad, .choice],
            choices: []
        )
        let model = makeModel(environment: environment, questions: [question])
        model.answerMode = .numberPad

        model.appendDigit(3)
        model.activeTimeField = .minute
        model.appendDigit(3)
        model.appendDigit(0)
        XCTAssertEqual(model.hourInput, "3")
        XCTAssertEqual(model.minuteInput, "30")

        model.submitTimeInput()
        XCTAssertEqual(model.feedback?.judgement, .correct)
    }

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

        model.draggedTime = target
        model.submitDraggedTime()
        XCTAssertEqual(model.feedback?.judgement, .correct)
    }

    func testTraceAnswerUsesRenderedGlyph() {
        let environment = TestEnvironment.make()
        let model = makeModel(environment: environment, questions: [TestEnvironment.traceQuestion()])

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

    func testEmptyTraceIsNotCorrect() {
        let environment = TestEnvironment.make()
        let model = makeModel(environment: environment, questions: [TestEnvironment.traceQuestion()])
        model.traceStrokes = []
        model.submitTrace()
        XCTAssertEqual(model.feedback?.judgement, .incorrect)
    }

    func testAdvancingThroughAllQuestionsFinishesAndSaves() {
        let store = InMemoryLearningHistoryStore()
        let environment = TestEnvironment.make(historyStore: store)
        let questions = [
            TestEnvironment.integerQuestion(correct: 1),
            TestEnvironment.integerQuestion(correct: 2)
        ]
        let model = makeModel(environment: environment, questions: questions)

        model.submitNumberInputDirectly(1)
        model.advance()
        model.submitNumberInputDirectly(2)
        model.advance()

        XCTAssertEqual(model.stage, .finished)
        XCTAssertEqual(model.summary?.correctCount, 2)
        XCTAssertEqual(store.sessions().count, 1)
        XCTAssertEqual(store.attempts().count, 2)
        XCTAssertGreaterThan(environment.progress.totalStars, 0)
    }

    // MARK: - 音声（ボタンは無く、読み上げのあと自動で聞く）

    func testListeningStartsByItselfAfterThePrompt() {
        let recognizer = MockSpeechRecognizer(
            script: [SpeechRecognitionResult(transcript: "さん", confidence: 0.9, isFinal: true)]
        )
        let environment = TestEnvironment.make(recognizer: recognizer)
        let model = makeModel(
            environment: environment,
            questions: [TestEnvironment.integerQuestion(correct: 3)]
        )
        XCTAssertTrue(model.isVoiceAvailable)
        XCTAssertNotEqual(model.answerMode, .voice, "画面に出すのはタップで答えるもの")

        // マイクのボタンを押さなくても、読み上げが終わると聞き始めて判定まで進む
        TestEnvironment.wait(until: { model.stage == .feedback })
        XCTAssertGreaterThanOrEqual(recognizer.startCount, 1, "自動で聞き始めていない")
        XCTAssertEqual(model.feedback?.judgement, .correct)
    }

    func testVoiceAnswerFlowWithScriptedRecogniser() {
        let environment = TestEnvironment.make(voiceScript: ["さん"])
        let model = makeModel(
            environment: environment,
            questions: [TestEnvironment.integerQuestion(correct: 3)]
        )
        TestEnvironment.wait(until: { model.stage == .feedback })
        XCTAssertEqual(model.feedback?.judgement, .correct)
    }

    func testListeningWaitsUntilThePromptHasBeenRead() {
        let synthesizer = MockSpeechSynthesizer()
        synthesizer.completionDelay = 0.4
        let recognizer = MockSpeechRecognizer(
            script: [SpeechRecognitionResult(transcript: "さん", confidence: 0.9, isFinal: true)]
        )
        let environment = TestEnvironment.make(synthesizer: synthesizer, recognizer: recognizer)
        let model = makeModel(
            environment: environment,
            questions: [TestEnvironment.integerQuestion(correct: 3)]
        )
        // 読み上げ中はマイクを開かない（自分の声を拾わないように）
        XCTAssertEqual(recognizer.startCount, 0)
        XCTAssertFalse(model.isListening)

        TestEnvironment.wait(until: { model.stage == .feedback })
        XCTAssertEqual(recognizer.startCount, 1)
    }

    func testUnrecognisedSpeechDoesNotCountAsWrongAndKeepsListening() {
        let store = InMemoryLearningHistoryStore()
        let recognizer = MockSpeechRecognizer(
            script: [SpeechRecognitionResult(transcript: "わかんない", confidence: 0.9, isFinal: true)]
        )
        let environment = TestEnvironment.make(historyStore: store, recognizer: recognizer)
        let model = makeModel(
            environment: environment,
            questions: [TestEnvironment.integerQuestion(correct: 3)]
        )

        // 台本を使い切ったあとは「声なし」になり、静かに聞き直し続ける
        TestEnvironment.wait(until: { recognizer.startCount >= 2 })
        XCTAssertGreaterThanOrEqual(recognizer.startCount, 2, "聞き取れなくても聞き直す")
        XCTAssertEqual(model.stage, .asking, "聞き取れなかっただけなので問題は進めない")
        XCTAssertNil(model.feedback)
        XCTAssertTrue(store.attempts().isEmpty, "学習履歴にも不正解として残さない")
    }

    func testTappingAnAnswerClosesTheMicrophone() {
        let recognizer = MockSpeechRecognizer(script: [])
        let environment = TestEnvironment.make(recognizer: recognizer)
        let question = TestEnvironment.integerQuestion(correct: 3)
        let model = makeModel(environment: environment, questions: [question])
        TestEnvironment.wait(until: { recognizer.startCount >= 1 })

        guard let correct = question.choices.first(where: \.isCorrect) else {
            return XCTFail("正解の選択肢がない")
        }
        model.select(choice: correct)
        XCTAssertEqual(model.stage, .feedback)
        XCTAssertFalse(model.isListening)
        XCTAssertGreaterThanOrEqual(recognizer.stopCount, 1)

        // フィードバック中は聞き直さない
        let stopsBefore = recognizer.startCount
        TestEnvironment.wait(timeout: 1.0, until: { false })
        XCTAssertEqual(recognizer.startCount, stopsBefore)
    }

    func testVoiceIsNotUsedWhenTurnedOff() {
        var settings = AppSettings.default
        settings.voiceAnswerEnabled = false
        let recognizer = MockSpeechRecognizer(
            script: [SpeechRecognitionResult(transcript: "さん", confidence: 0.9, isFinal: true)]
        )
        let environment = TestEnvironment.make(settings: settings, recognizer: recognizer)
        let model = makeModel(
            environment: environment,
            questions: [TestEnvironment.integerQuestion(correct: 3)]
        )
        XCTAssertFalse(model.availableModes.contains(.voice))
        XCTAssertFalse(model.isVoiceAvailable)
        XCTAssertFalse(model.availableModes.isEmpty, "タップ回答は必ず残る")

        TestEnvironment.wait(timeout: 0.5, until: { false })
        XCTAssertEqual(recognizer.startCount, 0, "設定で OFF ならマイクを開かない")
        XCTAssertEqual(model.stage, .asking)
    }

    func testPermissionIsNotAskedWhileAnswering() {
        let recognizer = MockSpeechRecognizer(
            authorizationStatus: .notDetermined,
            script: [SpeechRecognitionResult(transcript: "さん", confidence: 0.9, isFinal: true)]
        )
        let environment = TestEnvironment.make(recognizer: recognizer)
        let model = makeModel(
            environment: environment,
            questions: [TestEnvironment.integerQuestion(correct: 3)]
        )
        TestEnvironment.wait(timeout: 0.5, until: { false })
        // 許可はオンボーディングで頼む。答える場面でダイアログを割り込ませない。
        XCTAssertEqual(recognizer.authorizationStatus, .notDetermined)
        XCTAssertEqual(recognizer.startCount, 0)
        XCTAssertEqual(model.stage, .asking)
    }

    func testWritingShowsTheTemplateOnlyAsAHint() {
        let environment = TestEnvironment.make()
        let card = KanaCatalog.teachable[0]
        let question = Question(
            skill: .hiraganaWrite,
            difficulty: DifficultyLevel(5),
            prompt: Prompt(displayText: "かいてみよう", spokenText: "かいてみよう", hintText: "うすい もじを だしたよ"),
            content: .kanaCard(card: card, task: .write),
            answer: .trace(requiredCoverage: 0.9),
            answerModes: [.trace],
            choices: []
        )
        let model = makeModel(environment: environment, questions: [question])
        XCTAssertFalse(TraceTemplatePolicy.showsTemplate(for: question.content, hintShown: model.showsHint))

        model.submitTrace()
        XCTAssertEqual(model.feedback?.judgement, .incorrect)
        model.retryCurrentQuestion()
        XCTAssertTrue(model.showsHint)
        XCTAssertTrue(TraceTemplatePolicy.showsTemplate(for: question.content, hintShown: model.showsHint))
    }

    func testFinishingReturnsHomeWithoutAResultScreen() {
        let synthesizer = MockSpeechSynthesizer()
        let environment = TestEnvironment.make(synthesizer: synthesizer)
        let model = makeModel(environment: environment, questions: [TestEnvironment.integerQuestion(correct: 3)])
        model.submitNumberInputDirectly(3)
        model.advance()

        XCTAssertEqual(model.stage, .finished)
        XCTAssertNotNil(model.summary)
        XCTAssertTrue(synthesizer.spokenTexts.contains(model.summary?.childMessage ?? "?"), "ひとこと ねぎらう")
    }

    func testAdsAreSuppressedDuringLearning() {
        let adPresenter = MockAdPresenter(allow: true)
        let environment = TestEnvironment.make(adPresenter: adPresenter)
        let model = makeModel(environment: environment, questions: [TestEnvironment.integerQuestion()])

        XCTAssertTrue(adPresenter.isLearningSessionActive)
        XCTAssertFalse(adPresenter.shouldPresentParentAd(adsRemoved: false), "学習中は広告を出さない")

        model.submitNumberInputDirectly(3)
        model.advance()
        XCTAssertFalse(adPresenter.isLearningSessionActive)
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
        model.submitNumberInputDirectly(1)
        model.close()

        XCTAssertEqual(store.attempts().count, 1)
        XCTAssertEqual(store.sessions().count, 1)
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
}

private extension SessionViewModel {
    /// テスト用に数字入力をまとめて行う。
    func submitNumberInputDirectly(_ value: Int) {
        answerMode = .numberPad
        clearInput()
        for character in "\(value)" {
            if let digit = character.wholeNumberValue {
                appendDigit(digit)
            }
        }
        submitNumberInput()
    }
}
