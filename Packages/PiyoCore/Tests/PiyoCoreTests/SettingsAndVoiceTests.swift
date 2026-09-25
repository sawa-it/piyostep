import XCTest
@testable import PiyoCore

final class AppSettingsTests: XCTestCase {

    func testDefaultsAreSensible() {
        let settings = AppSettings.default
        XCTAssertEqual(settings.difficultyMode, .automatic)
        XCTAssertEqual(settings.dailyGoal, .normal)
        XCTAssertEqual(settings.mealDurationMinutes, 15)
        XCTAssertEqual(settings.enabledSubjects, Set(Subject.allCases))
        XCTAssertTrue(settings.voiceGuidanceEnabled)
        XCTAssertTrue(settings.voiceAnswerEnabled)
        XCTAssertFalse(settings.adsRemoved)
        XCTAssertTrue(settings.canShowAds)
    }

    func testValuesAreClamped() {
        let loud = AppSettings(volume: 3.0, mealDurationMinutes: 300)
        XCTAssertEqual(loud.volume, 1.0, accuracy: 0.0001)
        XCTAssertEqual(loud.mealDurationMinutes, 60)

        let quiet = AppSettings(volume: -1, mealDurationMinutes: 0)
        XCTAssertEqual(quiet.volume, 0, accuracy: 0.0001)
        XCTAssertEqual(quiet.mealDurationMinutes, 3)
    }

    func testUnknownCharacterFallsBackToDefault() {
        let settings = AppSettings(mealCharacterID: "nope")
        XCTAssertEqual(settings.mealCharacterID, CharacterCatalog.defaultCharacterID)
    }

    func testEmptySubjectSelectionFallsBackToEverything() {
        let settings = AppSettings(enabledSubjects: [])
        XCTAssertEqual(settings.enabledSubjects, Set(Subject.allCases))
    }

    func testMealDurationInSeconds() {
        XCTAssertEqual(AppSettings(mealDurationMinutes: 20).mealDuration, 1200, accuracy: 0.001)
    }

    func testAdsAreHiddenAfterPurchase() {
        var settings = AppSettings.default
        settings.adsRemoved = true
        XCTAssertFalse(settings.canShowAds)
    }

    func testCodableRoundTrip() throws {
        var settings = AppSettings.default
        settings.difficultyMode = .hard
        settings.volume = 0.42
        settings.voiceAnswerEnabled = false
        settings.mealDurationMinutes = 30
        settings.mealCharacterID = "nyan"
        settings.dailyGoal = .plenty
        settings.enabledSubjects = [.hiragana, .clock]
        settings.adsRemoved = true
        settings.hapticsEnabled = false

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)
        XCTAssertEqual(decoded, settings)
    }

    func testDecodingToleratesMissingKeys() throws {
        let json = Data(#"{"volume": 0.25}"#.utf8)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: json)
        XCTAssertEqual(decoded.volume, 0.25, accuracy: 0.0001)
        XCTAssertEqual(decoded.difficultyMode, AppSettings.default.difficultyMode)
        XCTAssertEqual(decoded.dailyGoal, AppSettings.default.dailyGoal)
    }

    func testDecodingToleratesUnknownEnumValues() throws {
        let json = Data(#"{"difficultyMode": "insane", "dailyGoal": "infinite"}"#.utf8)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: json)
        XCTAssertEqual(decoded.difficultyMode, .automatic)
        XCTAssertEqual(decoded.dailyGoal, .normal)
    }

    func testDifficultyModeRanges() {
        XCTAssertEqual(DifficultyMode.automatic.allowedRange, 1 ... 5)
        XCTAssertEqual(DifficultyMode.easy.allowedRange, 1 ... 2)
        XCTAssertEqual(DifficultyMode.normal.allowedRange, 2 ... 4)
        XCTAssertEqual(DifficultyMode.hard.allowedRange, 3 ... 5)
    }

    func testDailyGoalQuestionCounts() {
        XCTAssertEqual(DailyGoal.light.questionCount, 5)
        XCTAssertEqual(DailyGoal.normal.questionCount, 8)
        XCTAssertEqual(DailyGoal.plenty.questionCount, 12)
    }
}

final class SettingsStoreTests: XCTestCase {

    func testLoadsDefaultsWhenEmpty() {
        let store = CodableSettingsStore(store: InMemoryKeyValueStore())
        XCTAssertEqual(store.load(), .default)
        XCTAssertNil(store.loadProfile())
    }

    func testSaveAndLoadRoundTrip() {
        let store = CodableSettingsStore(store: InMemoryKeyValueStore())
        var settings = AppSettings.default
        settings.mealDurationMinutes = 20
        settings.dailyGoal = .light
        settings.enabledSubjects = [.number]
        store.save(settings)

        let loaded = store.load()
        XCTAssertEqual(loaded.mealDurationMinutes, 20)
        XCTAssertEqual(loaded.dailyGoal, .light)
        XCTAssertEqual(loaded.enabledSubjects, [.number])
    }

    func testSettingsSurviveANewStoreInstance() {
        let backing = InMemoryKeyValueStore()
        let first = CodableSettingsStore(store: backing)
        var settings = AppSettings.default
        settings.volume = 0.33
        first.save(settings)

        let second = CodableSettingsStore(store: backing)
        XCTAssertEqual(second.load().volume, 0.33, accuracy: 0.0001)
    }

    func testCorruptDataFallsBackToDefaults() {
        let backing = InMemoryKeyValueStore()
        backing.set(Data("not json".utf8), forKey: CodableSettingsStore.settingsKey)
        let store = CodableSettingsStore(store: backing)
        XCTAssertEqual(store.load(), .default)
    }

    func testProfileRoundTrip() {
        let store = CodableSettingsStore(store: InMemoryKeyValueStore())
        let profile = ChildProfile(nickname: "はると", age: 4, buddyCharacterID: "kuma")
        store.saveProfile(profile)

        let loaded = store.loadProfile()
        XCTAssertEqual(loaded?.nickname, "はると")
        XCTAssertEqual(loaded?.age, 4)
        XCTAssertEqual(loaded?.buddyCharacterID, "kuma")
        XCTAssertEqual(loaded?.id, profile.id)

        store.saveProfile(nil)
        XCTAssertNil(store.loadProfile())
    }

    func testProfileSanitisesInput() {
        let profile = ChildProfile(nickname: "  とてもながいなまえですよ  ", age: 9)
        XCTAssertEqual(profile.nickname.count, 8)
        XCTAssertEqual(profile.age, 6, "3〜6 歳に収める")

        let young = ChildProfile(nickname: "a", age: 1)
        XCTAssertEqual(young.age, 3)

        let blank = ChildProfile(nickname: "   ", age: 4)
        XCTAssertEqual(blank.callName, "きみ")
    }

    func testSuggestedStartingLevelByAge() {
        XCTAssertEqual(ChildProfile(nickname: "a", age: 3).suggestedStartingLevel, .level1)
        XCTAssertEqual(ChildProfile(nickname: "a", age: 4).suggestedStartingLevel, .level2)
        XCTAssertEqual(ChildProfile(nickname: "a", age: 6).suggestedStartingLevel, .level3)
    }
}

final class VoiceAnswerCoordinatorTests: XCTestCase {

    private func makeQuestion() -> Question {
        Fixture.integerQuestion(correct: 3)
    }

    func testAuthorizedGoesStraightToListening() {
        let coordinator = VoiceAnswerCoordinator()
        XCTAssertEqual(coordinator.begin(authorization: .authorized, isAvailable: true), .listening)
        XCTAssertTrue(coordinator.state.isListening)
        XCTAssertEqual(coordinator.guidanceText, "はなしてね")
    }

    func testNotDeterminedAsksForPermissionFirst() {
        let coordinator = VoiceAnswerCoordinator()
        XCTAssertEqual(coordinator.begin(authorization: .notDetermined, isAvailable: true), .requestingPermission)
        XCTAssertEqual(coordinator.handleAuthorization(.authorized), .listening)
    }

    func testDeniedPermissionFallsBackToTapping() {
        let coordinator = VoiceAnswerCoordinator()
        XCTAssertEqual(coordinator.begin(authorization: .denied, isAvailable: true), .unavailable(.denied))
        XCTAssertEqual(coordinator.guidanceText, "タップで こたえてね")
    }

    func testUnavailableDeviceFallsBackToTapping() {
        let coordinator = VoiceAnswerCoordinator()
        XCTAssertEqual(coordinator.begin(authorization: .authorized, isAvailable: false), .unavailable(.unavailable))
    }

    func testCorrectSpeechResetsUnclearStreak() {
        let coordinator = VoiceAnswerCoordinator()
        let question = makeQuestion()
        _ = coordinator.handleFinal(transcript: "むにゃむにゃ", confidence: 0.1, question: question)
        XCTAssertEqual(coordinator.consecutiveUnclearCount, 1)

        let evaluation = coordinator.handleFinal(transcript: "さん", confidence: 0.9, question: question)
        XCTAssertEqual(evaluation.judgement, .correct)
        XCTAssertEqual(coordinator.consecutiveUnclearCount, 0)
        XCTAssertEqual(coordinator.state, .finished(.correct))
    }

    func testTapFallbackIsSuggestedAfterThreeUnclearTries() {
        let coordinator = VoiceAnswerCoordinator()
        let question = makeQuestion()
        for _ in 0 ..< 2 {
            _ = coordinator.handleFinal(transcript: "", confidence: 0.0, question: question)
        }
        XCTAssertFalse(coordinator.shouldSuggestTapAnswer)

        _ = coordinator.handleFinal(transcript: "", confidence: 0.0, question: question)
        XCTAssertTrue(coordinator.shouldSuggestTapAnswer)
        XCTAssertEqual(coordinator.retryMessage(), "タップで こたえても いいよ！")
    }

    func testRetryMessagesStayFriendly() {
        let coordinator = VoiceAnswerCoordinator()
        XCTAssertEqual(coordinator.retryMessage(), "もういちど いってみよう！")
        let question = makeQuestion()
        _ = coordinator.handleFinal(transcript: "", confidence: 0, question: question)
        XCTAssertEqual(coordinator.retryMessage(), "もういちど いってみよう！")
        _ = coordinator.handleFinal(transcript: "", confidence: 0, question: question)
        XCTAssertEqual(coordinator.retryMessage(), "おおきな こえで いってみよう！")
    }

    func testRecognitionFailureIsNotAWrongAnswer() {
        let coordinator = VoiceAnswerCoordinator()
        XCTAssertEqual(coordinator.handleFailure(.noSpeechDetected), .finished(.unclear))
        XCTAssertEqual(coordinator.consecutiveUnclearCount, 1)
        XCTAssertEqual(coordinator.handleFailure(.notAuthorized), .unavailable(.denied))
    }

    func testResetClearsState() {
        let coordinator = VoiceAnswerCoordinator()
        let question = makeQuestion()
        _ = coordinator.handleFinal(transcript: "", confidence: 0, question: question)
        coordinator.reset()
        XCTAssertEqual(coordinator.state, .idle)
        XCTAssertEqual(coordinator.consecutiveUnclearCount, 0)
        XCTAssertTrue(coordinator.lastTranscript.isEmpty)
    }

    func testResetCanKeepTheUnclearStreak() {
        let coordinator = VoiceAnswerCoordinator()
        let question = makeQuestion()
        _ = coordinator.handleFinal(transcript: "", confidence: 0, question: question)
        coordinator.reset(clearUnclearStreak: false)
        XCTAssertEqual(coordinator.consecutiveUnclearCount, 1)
    }

    func testPartialTranscriptIsKept() {
        let coordinator = VoiceAnswerCoordinator()
        coordinator.handlePartial(transcript: "さ")
        XCTAssertEqual(coordinator.lastTranscript, "さ")
    }

    func testMockRecognizerDrivesTheCoordinator() {
        let recognizer = MockSpeechRecognizer(
            script: [SpeechRecognitionResult(transcript: "さん", confidence: 0.9, isFinal: true)]
        )
        let coordinator = VoiceAnswerCoordinator()
        let question = makeQuestion()

        XCTAssertEqual(coordinator.begin(authorization: recognizer.authorizationStatus, isAvailable: true), .listening)

        var evaluation: AnswerEvaluation?
        recognizer.startListening(
            locale: .japanese,
            onResult: { result in
                if result.isFinal {
                    evaluation = coordinator.handleFinal(
                        transcript: result.transcript,
                        confidence: result.confidence,
                        question: question
                    )
                }
            },
            onFailure: { _ in XCTFail("失敗しないはず") }
        )

        XCTAssertEqual(evaluation?.judgement, .correct)
        XCTAssertEqual(recognizer.startCount, 1)
        XCTAssertEqual(recognizer.lastLocale, .japanese)
    }

    func testMockRecognizerReportsNoSpeech() {
        let recognizer = MockSpeechRecognizer(script: [])
        let coordinator = VoiceAnswerCoordinator()
        var failure: SpeechRecognitionFailure?
        recognizer.startListening(
            locale: .japanese,
            onResult: { _ in XCTFail("結果は来ないはず") },
            onFailure: { failure = $0 }
        )
        XCTAssertEqual(failure, .noSpeechDetected)
        XCTAssertEqual(coordinator.handleFailure(failure!), .finished(.unclear))
    }

    func testRecognitionLocalePerSubject() {
        XCTAssertEqual(Subject.hiragana.recognitionLocale, .japanese)
        XCTAssertEqual(Subject.clock.recognitionLocale, .japanese)
        XCTAssertEqual(Subject.number.recognitionLocale, .japanese)
        XCTAssertEqual(Subject.alphabet.recognitionLocale, .englishUS)
        XCTAssertEqual(Subject.englishWord.recognitionLocale, .englishUS)
    }
}

final class TraceEvaluatorTests: XCTestCase {

    /// 縦棒のお手本
    private func verticalBarMask() -> GlyphMask {
        GlyphMask.rectangle(width: 20, height: 20, rect: (x: 9, y: 0, w: 2, h: 20))
    }

    func testMaskGeometry() {
        let mask = verticalBarMask()
        XCTAssertEqual(mask.filledCount, 40)
        XCTAssertTrue(mask.isFilled(x: 9, y: 5))
        XCTAssertFalse(mask.isFilled(x: 0, y: 5))
        XCTAssertFalse(mask.isFilled(x: -1, y: 0))
        XCTAssertFalse(mask.isFilled(x: 100, y: 0))
    }

    func testMaskPadsShortCellArrays() {
        let mask = GlyphMask(width: 3, height: 3, cells: [true, true])
        XCTAssertEqual(mask.cells.count, 9)
        XCTAssertTrue(mask.isFilled(x: 0, y: 0))
        XCTAssertFalse(mask.isFilled(x: 2, y: 2))
    }

    func testNoStrokesMeansNoCoverage() {
        let evaluation = TraceEvaluator.evaluate(mask: verticalBarMask(), strokes: [])
        XCTAssertEqual(evaluation.coverage, 0, accuracy: 0.0001)
        XCTAssertEqual(evaluation.precision, 0, accuracy: 0.0001)
        XCTAssertEqual(evaluation.score, 0, accuracy: 0.0001)
    }

    func testTracingAlongTheGlyphGivesHighCoverage() {
        let stroke = (0 ... 20).map { step in
            TracePoint(x: 0.5, y: Double(step) / 20.0)
        }
        let evaluation = TraceEvaluator.evaluate(
            mask: verticalBarMask(),
            strokes: [stroke],
            brushRadius: 0.06
        )
        XCTAssertGreaterThan(evaluation.coverage, 0.9)
        XCTAssertGreaterThan(evaluation.precision, 0.3)
        XCTAssertGreaterThan(evaluation.score, 0.7)
    }

    func testTracingElsewhereGivesNoCoverage() {
        let stroke = (0 ... 20).map { step in
            TracePoint(x: 0.05, y: Double(step) / 20.0)
        }
        let evaluation = TraceEvaluator.evaluate(
            mask: verticalBarMask(),
            strokes: [stroke],
            brushRadius: 0.04
        )
        XCTAssertEqual(evaluation.coverage, 0, accuracy: 0.0001)
        XCTAssertEqual(evaluation.precision, 0, accuracy: 0.0001)
    }

    func testPartialTraceGivesPartialCoverage() {
        let stroke = (0 ... 10).map { step in
            TracePoint(x: 0.5, y: Double(step) / 20.0)
        }
        let evaluation = TraceEvaluator.evaluate(
            mask: verticalBarMask(),
            strokes: [stroke],
            brushRadius: 0.04
        )
        XCTAssertGreaterThan(evaluation.coverage, 0.3)
        XCTAssertLessThan(evaluation.coverage, 0.8)
    }

    func testMultipleStrokesAccumulate() {
        let top = (0 ... 10).map { TracePoint(x: 0.5, y: Double($0) / 20.0) }
        let bottom = (10 ... 20).map { TracePoint(x: 0.5, y: Double($0) / 20.0) }
        let single = TraceEvaluator.evaluate(mask: verticalBarMask(), strokes: [top], brushRadius: 0.05)
        let both = TraceEvaluator.evaluate(mask: verticalBarMask(), strokes: [top, bottom], brushRadius: 0.05)
        XCTAssertGreaterThan(both.coverage, single.coverage)
    }

    func testSinglePointStrokeIsStamped() {
        let evaluation = TraceEvaluator.evaluate(
            mask: verticalBarMask(),
            strokes: [[TracePoint(x: 0.5, y: 0.5)]],
            brushRadius: 0.06
        )
        XCTAssertGreaterThan(evaluation.coverage, 0)
    }

    func testEmptyMaskIsSafe() {
        let mask = GlyphMask(width: 0, height: 0, cells: [])
        let evaluation = TraceEvaluator.evaluate(mask: mask, strokes: [[TracePoint(x: 0.5, y: 0.5)]])
        XCTAssertEqual(evaluation.coverage, 0, accuracy: 0.0001)
    }

    func testRequiredCoverageRisesWithDifficulty() {
        let easy = KanaWriteQuestionGenerator.requiredCoverage(for: .level1)
        let hard = KanaWriteQuestionGenerator.requiredCoverage(for: .level5)
        XCTAssertLessThan(easy, hard)
        XCTAssertGreaterThan(easy, 0.4)
        XCTAssertLessThan(hard, 1.0)
    }
}
