import XCTest
@testable import PiyoCore

final class DayEndSummarizerTests: XCTestCase {

    private let calendar = Calendar.piyo
    private let summarizer = DayEndSummarizer()

    /// 2023-11-14 22:13 JST（Fixture.referenceDate）の日の朝。
    private var morning: Date {
        calendar.startOfDay(for: Fixture.referenceDate).addingTimeInterval(8 * 3600)
    }

    private func session(
        kind: SessionKind = .freePlay,
        at date: Date,
        stars: Int,
        questions: Int = 3
    ) -> SessionRecord {
        SessionRecord(
            kind: kind,
            startedAt: date,
            endedAt: date.addingTimeInterval(120),
            questionCount: questions,
            correctCount: questions,
            starsEarned: stars
        )
    }

    func testCountsOnlyTodayWhenNeverFinishedBefore() {
        let yesterday = morning.addingTimeInterval(-24 * 3600)
        let now = morning.addingTimeInterval(6 * 3600)

        let summary = summarizer.summarize(
            sessions: [
                session(at: yesterday, stars: 9),
                session(at: morning, stars: 4),
                session(at: morning.addingTimeInterval(3600), stars: 3)
            ],
            attempts: [
                Fixture.attempt(skill: .numberCount, judgement: .correct, at: yesterday),
                Fixture.attempt(skill: .numberCount, judgement: .correct, at: morning),
                Fixture.attempt(skill: .numberCount, judgement: .incorrect, at: morning),
                Fixture.attempt(skill: .numberCount, judgement: .unclear, at: morning)
            ],
            unlocks: [],
            lastDayEnd: nil,
            now: now
        )

        XCTAssertEqual(summary.starsEarned, 7, "きのうの★は数えない")
        XCTAssertEqual(summary.questionCount, 2, "聞き取れなかった音声は数えない")
        XCTAssertEqual(summary.correctCount, 1)
        XCTAssertEqual(summary.sessionCount, 2)
        XCTAssertEqual(summary.totalStars, 16, "通算はぜんぶ")
        XCTAssertTrue(summary.didPlay)
    }

    func testCountsSinceTheLastDayEndWithinToday() {
        let firstEnd = morning.addingTimeInterval(2 * 3600)
        let summary = summarizer.summarize(
            sessions: [
                session(at: morning, stars: 5),
                session(at: firstEnd.addingTimeInterval(600), stars: 2)
            ],
            attempts: [],
            unlocks: [],
            lastDayEnd: firstEnd,
            now: firstEnd.addingTimeInterval(3600)
        )
        XCTAssertEqual(summary.starsEarned, 2, "いちど おしまいにしたぶんは、もう受け取っている")
        XCTAssertEqual(summary.sessionCount, 1)
    }

    func testMealTimerIsCountedSeparately() {
        let summary = summarizer.summarize(
            sessions: [
                session(kind: .mealTimer, at: morning, stars: 3, questions: 0),
                session(kind: .dailyChallenge, at: morning.addingTimeInterval(60), stars: 6)
            ],
            attempts: [],
            unlocks: [],
            lastDayEnd: nil,
            now: morning.addingTimeInterval(3600)
        )
        XCTAssertEqual(summary.mealCount, 1)
        XCTAssertEqual(summary.sessionCount, 1)
        XCTAssertEqual(summary.starsEarned, 9)
    }

    func testUnlocksAreNotLostWhenDaysPassWithoutFinishing() {
        let threeDaysAgo = morning.addingTimeInterval(-3 * 24 * 3600)
        let twoDaysAgo = morning.addingTimeInterval(-2 * 24 * 3600)

        let summary = summarizer.summarize(
            sessions: [session(at: morning, stars: 1)],
            attempts: [],
            unlocks: [
                UnlockRecord(itemID: "costume.cap", unlockedAt: threeDaysAgo.addingTimeInterval(-3600)),
                UnlockRecord(itemID: "bg.park", unlockedAt: twoDaysAgo),
                UnlockRecord(itemID: "char.nyan", unlockedAt: morning)
            ],
            lastDayEnd: threeDaysAgo,
            now: morning.addingTimeInterval(3600)
        )

        XCTAssertEqual(summary.newlyUnlocked.map(\.id), ["bg.park", "char.nyan"], "前回のおしまい以降のものを、古い順に")
        XCTAssertEqual(summary.starsEarned, 1, "★は きょうのぶんだけ")
    }

    func testUnlocksAreOnlyTodaysWhenNeverFinishedBefore() {
        let yesterday = morning.addingTimeInterval(-24 * 3600)
        let summary = summarizer.summarize(
            sessions: [],
            attempts: [],
            unlocks: [
                UnlockRecord(itemID: "costume.cap", unlockedAt: yesterday),
                UnlockRecord(itemID: "bg.park", unlockedAt: morning)
            ],
            lastDayEnd: nil,
            now: morning.addingTimeInterval(3600)
        )
        XCTAssertEqual(summary.newlyUnlocked.map(\.id), ["bg.park"])
    }

    func testUnknownUnlockIDsAreIgnored() {
        let summary = summarizer.summarize(
            sessions: [],
            attempts: [],
            unlocks: [UnlockRecord(itemID: "nope", unlockedAt: morning)],
            lastDayEnd: nil,
            now: morning.addingTimeInterval(60)
        )
        XCTAssertTrue(summary.newlyUnlocked.isEmpty)
    }

    func testMessagesStayPositiveAndDifferWhenNothingWasPlayed() {
        let quiet = summarizer.summarize(sessions: [], attempts: [], unlocks: [], lastDayEnd: nil, now: morning)
        XCTAssertFalse(quiet.didPlay)
        XCTAssertEqual(quiet, DayEndSummary.empty)

        let played = summarizer.summarize(
            sessions: [session(at: morning, stars: 2)],
            attempts: [],
            unlocks: [],
            lastDayEnd: nil,
            now: morning.addingTimeInterval(60)
        )
        XCTAssertNotEqual(quiet.childMessage, played.childMessage)
        for word in ["まちがい", "だめ", "おそい", "しっぱい"] {
            XCTAssertFalse(quiet.childMessage.contains(word))
            XCTAssertFalse(played.childMessage.contains(word))
        }
    }
}

final class DayEndStoreTests: XCTestCase {

    func testDayEndDateRoundTrip() {
        let keyValue = InMemoryKeyValueStore()
        let store = CodableSettingsStore(store: keyValue)
        XCTAssertNil(store.loadDayEndDate())

        let date = Fixture.referenceDate
        store.saveDayEndDate(date)
        XCTAssertEqual(store.loadDayEndDate()?.timeIntervalSince1970 ?? 0, date.timeIntervalSince1970, accuracy: 1)

        // 別のインスタンスでも読める
        XCTAssertNotNil(CodableSettingsStore(store: keyValue).loadDayEndDate())

        store.saveDayEndDate(nil)
        XCTAssertNil(store.loadDayEndDate())
    }

    func testInMemoryStoreRecordsWhenItemsWereUnlocked() {
        let store = InMemoryLearningHistoryStore()
        XCTAssertTrue(store.unlockRecords().isEmpty, "最初から使えるものは記録に含めない")

        store.markUnlocked(itemIDs: ["costume.cap"], at: Fixture.referenceDate)
        store.markUnlocked(itemIDs: ["costume.cap", "bg.park"], at: Fixture.referenceDate.addingTimeInterval(60))

        let records = store.unlockRecords()
        XCTAssertEqual(records.map(\.itemID), ["costume.cap", "bg.park"], "二度目の同じ ID は記録しない")
        XCTAssertEqual(records.last?.unlockedAt, Fixture.referenceDate.addingTimeInterval(60))
    }
}

final class TraceTemplatePolicyTests: XCTestCase {

    private let card = KanaCatalog.teachable[0]

    func testTracingAlwaysShowsTheTemplate() {
        let content = QuestionContent.kanaCard(card: card, task: .trace)
        XCTAssertTrue(TraceTemplatePolicy.showsTemplate(for: content, hintShown: false))
        XCTAssertTrue(TraceTemplatePolicy.showsTemplate(for: content, hintShown: true))
    }

    func testWritingHidesTheTemplateUntilTheHint() {
        let content = QuestionContent.kanaCard(card: card, task: .write)
        XCTAssertFalse(TraceTemplatePolicy.showsTemplate(for: content, hintShown: false), "かきとりは お手本なし")
        XCTAssertTrue(TraceTemplatePolicy.showsTemplate(for: content, hintShown: true), "2 回目はヒントとして お手本を出す")
    }

    func testAlphabetFollowsTheSameRule() {
        let letter = AlphabetCatalog.all[0]
        let write = QuestionContent.alphabetCard(card: letter, task: .write, isUppercase: true)
        XCTAssertFalse(TraceTemplatePolicy.showsTemplate(for: write, hintShown: false))
        XCTAssertTrue(TraceTemplatePolicy.showsTemplate(for: write, hintShown: true))
    }

    /// ヒント文が「うすい もじ」に触れるのは、お手本が実際に出るときだけ。
    func testWriteHintMatchesWhatIsOnScreen() {
        let random = Fixture.random()
        for subject in [Subject.hiragana, .katakana] {
            let generator = KanaWriteQuestionGenerator(subject: subject)
            let traced = generator.generate(level: .level1, random: random, allowVoice: false)
            let written = generator.generate(level: DifficultyLevel(5), random: random, allowVoice: false)

            guard case .kanaCard(_, let traceTask) = traced.content,
                  case .kanaCard(_, let writeTask) = written.content else {
                return XCTFail("かな問題でない")
            }
            XCTAssertEqual(traceTask, .trace)
            XCTAssertEqual(writeTask, .write)
            XCTAssertEqual(traced.prompt.hintText, "うすい もじの うえを なぞってね")
            XCTAssertEqual(written.prompt.hintText, "うすい もじを だしたよ。うえを なぞってね")
            XCTAssertTrue(written.prompt.spokenText.contains("かいてみよう"))
        }

        let alphabet = AlphabetWriteQuestionGenerator()
        let written = alphabet.generate(level: DifficultyLevel(5), random: random, allowVoice: false)
        XCTAssertEqual(written.prompt.hintText, "うすい もじを だしたよ。うえを なぞってね")
        XCTAssertTrue(written.prompt.spokenText.contains("かいてみよう"))
    }
}
