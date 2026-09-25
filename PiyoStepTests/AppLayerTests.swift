import XCTest
import SwiftData
import PiyoCore
@testable import PiyoStep

@MainActor
final class AppEnvironmentTests: XCTestCase {

    func testSettingsArePersisted() {
        let environment = TestEnvironment.make()
        var settings = environment.settings
        settings.mealDurationMinutes = 20
        settings.dailyGoal = .light
        environment.update(settings: settings)

        XCTAssertEqual(environment.settings.mealDurationMinutes, 20)
        XCTAssertEqual(environment.settingsStore.load().dailyGoal, .light)
    }

    func testInvalidSettingsAreSanitisedOnSave() {
        let environment = TestEnvironment.make()
        var settings = environment.settings
        settings.mealDurationMinutes = 999
        environment.update(settings: settings)
        XCTAssertEqual(environment.settings.mealDurationMinutes, 60)
    }

    func testProfileIsPersisted() {
        let environment = TestEnvironment.make(profile: nil)
        XCTAssertNil(environment.profile)

        let profile = ChildProfile(nickname: "たろう", age: 4, buddyCharacterID: "kuma")
        environment.save(profile: profile)

        XCTAssertEqual(environment.profile?.nickname, "たろう")
        XCTAssertEqual(environment.settingsStore.loadProfile()?.buddyCharacterID, "kuma")
    }

    func testDailyChallengeMatchesTheDailyGoal() {
        var settings = AppSettings.default
        settings.dailyGoal = .light
        let environment = TestEnvironment.make(settings: settings)

        let challenge = environment.makeDailyChallenge()
        XCTAssertEqual(challenge.questionCount, DailyGoal.light.questionCount)
        XCTAssertFalse(challenge.questions.contains { $0.answerModes.isEmpty })
    }

    func testDailyChallengeRespectsAge() {
        let environment = TestEnvironment.make(
            profile: ChildProfile(nickname: "みつき", age: 3)
        )
        let challenge = environment.makeDailyChallenge()
        XCTAssertFalse(challenge.skills.contains(.placeValue))
        XCTAssertFalse(challenge.skills.contains(.clockRead))
    }

    func testFreePlayProducesQuestionsForTheChosenSkill() {
        let environment = TestEnvironment.make()
        let questions = environment.makeFreePlayQuestions(skill: .clockSet, count: 4)
        XCTAssertEqual(questions.count, 4)
        XCTAssertTrue(questions.allSatisfy { $0.skill == .clockSet })
    }

    func testMealConfigurationUsesSettings() {
        var settings = AppSettings.default
        settings.mealDurationMinutes = 10
        settings.mealCharacterID = "nyan"
        let environment = TestEnvironment.make(
            settings: settings,
            launchArguments: TestEnvironment.makeLaunchArguments(mealSeconds: nil)
        )
        let configuration = environment.makeMealConfiguration()
        XCTAssertEqual(configuration.targetDuration, 600, accuracy: 0.001)
        XCTAssertEqual(configuration.characterID, "nyan")
    }

    func testPurchasingRemovesAds() async {
        let purchase = MockPurchaseService(isAdFreePurchased: true)
        let environment = TestEnvironment.make(purchaseService: purchase)
        XCTAssertFalse(environment.settings.adsRemoved)

        await environment.loadPurchases()
        XCTAssertTrue(environment.settings.adsRemoved)
        XCTAssertFalse(environment.settings.canShowAds)
    }

    func testUnlocksAreSurfacedAfterLearning() {
        let store = InMemoryLearningHistoryStore()
        let environment = TestEnvironment.make(historyStore: store)

        let summary = SessionSummary(
            record: SessionRecord(
                kind: .dailyChallenge,
                startedAt: Date(),
                endedAt: Date().addingTimeInterval(120),
                questionCount: 6,
                correctCount: 6,
                starsEarned: 12
            ),
            attempts: (0 ..< 6).map { _ in
                AttemptRecord(
                    skill: .numberCount,
                    difficulty: .level1,
                    judgement: .correct,
                    answerMode: .choice
                )
            }
        )
        environment.process(summary: summary)

        XCTAssertTrue(environment.pendingUnlocks.contains { $0.id == "costume.cap" })
        XCTAssertEqual(environment.progress.totalStars, 12)

        let consumed = environment.consumePendingUnlocks()
        XCTAssertFalse(consumed.isEmpty)
        XCTAssertTrue(environment.pendingUnlocks.isEmpty)
    }

    func testAvailableCharactersStartWithTheFreeOnes() {
        let environment = TestEnvironment.make()
        let ids = Set(environment.availableCharacters.map(\.id))
        XCTAssertEqual(ids, ["piyo", "kuma"])
    }

    func testBuddyCharacterFallsBackWhenUnknown() {
        let environment = TestEnvironment.make(
            profile: ChildProfile(nickname: "あ", age: 5, buddyCharacterID: "nope")
        )
        XCTAssertEqual(environment.buddyCharacter.id, CharacterCatalog.defaultCharacterID)
    }

    func testLaunchArgumentsSeedAProfile() {
        let arguments = LaunchArguments(
            isUITest: true,
            useInMemoryStore: true,
            seededProfileName: "ゆい",
            seededProfileAge: 6,
            forceFreshInstall: false,
            randomSeed: 1,
            voiceScript: [],
            disableAds: true,
            reduceAnimations: true,
            mealDurationSeconds: nil
        )
        let environment = TestEnvironment.make(profile: nil, launchArguments: arguments)
        XCTAssertEqual(environment.profile?.nickname, "ゆい")
        XCTAssertEqual(environment.profile?.age, 6)
    }

    func testLaunchArgumentParsing() {
        let parsed = LaunchArguments.parse([
            "app", "-uiTestMode", "1",
            "-uiTestProfile", "さくら",
            "-uiTestSeed", "42",
            "-uiTestVoiceScript", "さん",
            "-uiTestMealSeconds", "90"
        ])
        XCTAssertTrue(parsed.isUITest)
        XCTAssertTrue(parsed.useInMemoryStore)
        XCTAssertEqual(parsed.seededProfileName, "さくら")
        XCTAssertEqual(parsed.randomSeed, 42)
        XCTAssertEqual(parsed.voiceScript, ["さん"])
        XCTAssertEqual(parsed.mealDurationSeconds, 90)
        XCTAssertTrue(parsed.disableAds)
    }

    func testLaunchArgumentsDefaultToProduction() {
        let parsed = LaunchArguments.parse(["app"])
        XCTAssertFalse(parsed.isUITest)
        XCTAssertFalse(parsed.useInMemoryStore)
        XCTAssertNil(parsed.seededProfileName)
        XCTAssertFalse(parsed.disableAds)
    }
}

@MainActor
final class AdPresenterTests: XCTestCase {

    func testAdIsShownInTheParentArea() {
        let presenter = ParentAreaAdPresenter()
        XCTAssertTrue(presenter.shouldPresentAd(adsRemoved: false))
    }

    func testAdIsSkippedWhenPurchased() {
        let presenter = ParentAreaAdPresenter()
        XCTAssertFalse(presenter.shouldPresentAd(adsRemoved: true))
    }

    func testAdIsSkippedDuringLearning() {
        let presenter = ParentAreaAdPresenter()
        presenter.isLearningSessionActive = true
        XCTAssertFalse(presenter.shouldPresentAd(adsRemoved: false))
    }

    func testDisabledPresenterNeverShows() {
        let presenter = ParentAreaAdPresenter(isDisabled: true)
        XCTAssertFalse(presenter.shouldPresentAd(adsRemoved: false))
    }
}

@MainActor
final class SwiftDataLearningHistoryStoreTests: XCTestCase {

    private func makeStore() throws -> SwiftDataLearningHistoryStore {
        let container = try PiyoSchema.makeContainer(inMemory: true)
        return SwiftDataLearningHistoryStore(context: ModelContext(container))
    }

    func testAttemptsRoundTrip() throws {
        let store = try makeStore()
        let record = AttemptRecord(
            skill: .hiraganaRead,
            difficulty: .level2,
            judgement: .correct,
            answerMode: .voice,
            attemptIndex: 2,
            duration: 3.5
        )
        store.append(attempt: record)

        let loaded = store.attempts()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.skill, .hiraganaRead)
        XCTAssertEqual(loaded.first?.difficulty, .level2)
        XCTAssertEqual(loaded.first?.judgement, .correct)
        XCTAssertEqual(loaded.first?.answerMode, .voice)
        XCTAssertEqual(loaded.first?.attemptIndex, 2)
        XCTAssertEqual(loaded.first?.duration ?? 0, 3.5, accuracy: 0.001)
    }

    func testAttemptsAreReturnedNewestFirstAndLimited() throws {
        let store = try makeStore()
        let base = Date()
        for index in 0 ..< 5 {
            store.append(
                attempt: AttemptRecord(
                    skill: .numberCount,
                    difficulty: .level1,
                    judgement: .correct,
                    answerMode: .choice,
                    createdAt: base.addingTimeInterval(Double(index))
                )
            )
        }
        let limited = store.attempts(limit: 2)
        XCTAssertEqual(limited.count, 2)
        XCTAssertGreaterThan(limited[0].createdAt, limited[1].createdAt)
    }

    func testSessionsAndMealsRoundTrip() throws {
        let store = try makeStore()
        let now = Date()
        store.append(
            session: SessionRecord(
                kind: .dailyChallenge,
                subject: .number,
                startedAt: now,
                endedAt: now.addingTimeInterval(60),
                questionCount: 5,
                correctCount: 4,
                starsEarned: 8
            )
        )
        store.append(
            mealSession: MealSessionRecord(
                characterID: "kuma",
                targetDuration: 900,
                actualDuration: 700,
                childFinishedFirst: true,
                startedAt: now
            )
        )

        XCTAssertEqual(store.sessions().first?.correctCount, 4)
        XCTAssertEqual(store.sessions().first?.subject, .number)
        XCTAssertEqual(store.mealSessions().first?.characterID, "kuma")
        XCTAssertTrue(store.mealSessions().first?.childFinishedFirst ?? false)
    }

    func testMasterySnapshotIsUpdatedNotDuplicated() throws {
        let store = try makeStore()
        var snapshot = MasterySnapshot(skill: .clockRead, level: .level2)
        snapshot.attempts = 3
        store.save(snapshot: snapshot)

        snapshot.attempts = 7
        snapshot.level = .level3
        store.save(snapshot: snapshot)

        let loaded = store.masterySnapshots()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[.clockRead]?.attempts, 7)
        XCTAssertEqual(loaded[.clockRead]?.level, .level3)
    }

    func testUnlocksIncludeTheFreeItems() throws {
        let store = try makeStore()
        XCTAssertEqual(store.unlockedItemIDs(), UnlockCatalog.initiallyUnlockedIDs)

        store.markUnlocked(itemIDs: ["char.nyan"], at: Date())
        XCTAssertTrue(store.unlockedItemIDs().contains("char.nyan"))

        // 二重登録されないこと
        store.markUnlocked(itemIDs: ["char.nyan"], at: Date())
        XCTAssertEqual(store.unlockedItemIDs().filter { $0 == "char.nyan" }.count, 1)
    }

    func testFullLearningCycleThroughSwiftData() throws {
        let store = try makeStore()
        let processor = LearningResultProcessor()
        let now = Date()
        let summary = SessionSummary(
            record: SessionRecord(
                kind: .dailyChallenge,
                startedAt: now,
                endedAt: now.addingTimeInterval(180),
                questionCount: 8,
                correctCount: 8,
                starsEarned: 16
            ),
            attempts: (0 ..< 8).map { index in
                AttemptRecord(
                    skill: .numberCount,
                    difficulty: .level1,
                    judgement: .correct,
                    answerMode: .choice,
                    createdAt: now.addingTimeInterval(Double(index))
                )
            }
        )
        let outcome = processor.process(
            summary: summary,
            settings: .default,
            store: store,
            now: now
        )

        XCTAssertEqual(store.attempts().count, 8)
        XCTAssertEqual(store.masterySnapshots()[.numberCount]?.level, .level2, "習熟して難易度が上がる")
        XCTAssertEqual(outcome.summary.totalStars, 16)
        XCTAssertTrue(outcome.newlyUnlocked.contains { $0.id == "costume.cap" })
    }
}

@MainActor
final class GlyphMaskRendererTests: XCTestCase {

    func testRendersANonEmptyMaskForKana() {
        let mask = GlyphMaskRenderer.mask(for: "あ")
        XCTAssertEqual(mask.width, GlyphMaskRenderer.resolution)
        XCTAssertGreaterThan(mask.filledCount, 50, "文字の形が取れていない")
        XCTAssertLessThan(mask.filledCount, mask.width * mask.height, "全面が塗りつぶされている")
    }

    func testRendersMasksForEveryTeachableKana() {
        for card in KanaCatalog.teachable {
            XCTAssertGreaterThan(
                GlyphMaskRenderer.mask(for: card.hiragana).filledCount,
                20,
                "\(card.hiragana) のマスクが作れない"
            )
            XCTAssertGreaterThan(
                GlyphMaskRenderer.mask(for: card.katakana).filledCount,
                20,
                "\(card.katakana) のマスクが作れない"
            )
        }
    }

    func testRendersMasksForAlphabet() {
        for card in AlphabetCatalog.all {
            XCTAssertGreaterThan(GlyphMaskRenderer.mask(for: card.uppercase).filledCount, 20)
            XCTAssertGreaterThan(GlyphMaskRenderer.mask(for: card.lowercase).filledCount, 10)
        }
    }

    func testEmptyStringProducesEmptyMask() {
        XCTAssertEqual(GlyphMaskRenderer.mask(for: "").filledCount, 0)
    }

    func testTracingOverTheGlyphScoresHigherThanTracingBeside() {
        let mask = GlyphMaskRenderer.mask(for: "あ")
        let onGlyph = (0 ... 20).map { TracePoint(x: 0.5, y: 0.1 + Double($0) * 0.04) }
        let besideGlyph = (0 ... 20).map { TracePoint(x: 0.02, y: 0.1 + Double($0) * 0.04) }

        let good = TraceEvaluator.evaluate(mask: mask, strokes: [onGlyph], brushRadius: 0.08)
        let bad = TraceEvaluator.evaluate(mask: mask, strokes: [besideGlyph], brushRadius: 0.08)
        XCTAssertGreaterThan(good.coverage, bad.coverage)
    }
}
