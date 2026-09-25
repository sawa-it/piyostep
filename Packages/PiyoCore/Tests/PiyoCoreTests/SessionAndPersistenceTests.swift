import XCTest
@testable import PiyoCore

final class LearningSessionEngineTests: XCTestCase {

    private func makeEngine(questionCount: Int = 2, clock: MutableClock = MutableClock()) -> LearningSessionEngine {
        let questions = (0 ..< questionCount).map { Fixture.integerQuestion(correct: $0 + 1) }
        return LearningSessionEngine(
            kind: .dailyChallenge,
            questions: questions,
            clock: clock
        )
    }

    func testStartMovesToFirstQuestion() {
        let engine = makeEngine()
        XCTAssertEqual(engine.phase, .notStarted)
        XCTAssertEqual(engine.start(), .asking(index: 0))
        XCTAssertEqual(engine.currentQuestion?.answer, .integer(1))
    }

    func testEmptySessionCompletesImmediately() {
        let engine = makeEngine(questionCount: 0)
        guard case .completed = engine.start() else {
            return XCTFail("問題が無いときは即完了する")
        }
    }

    func testCorrectFirstTimeEarnsTwoStars() {
        let engine = makeEngine()
        engine.start()
        let feedback = engine.submit(.integer(1))
        XCTAssertEqual(feedback.judgement, .correct)
        XCTAssertEqual(feedback.starsEarned, 2)
        XCTAssertFalse(feedback.canRetry)
        XCTAssertEqual(engine.starsEarned, 2)
        XCTAssertEqual(engine.correctCount, 1)
    }

    func testCorrectAfterRetryEarnsOneStar() {
        let engine = makeEngine()
        engine.start()
        let first = engine.submit(.integer(9))
        XCTAssertEqual(first.judgement, .incorrect)
        XCTAssertTrue(first.canRetry)
        XCTAssertEqual(first.starsEarned, 0)

        engine.retry()
        let second = engine.submit(.integer(1))
        XCTAssertEqual(second.judgement, .correct)
        XCTAssertEqual(second.starsEarned, 1)
    }

    func testRunsOutOfAttemptsAndRevealsAnswerKindly() {
        let engine = makeEngine()
        engine.start()
        _ = engine.submit(.integer(9))
        engine.retry()
        _ = engine.submit(.integer(8))
        engine.retry()
        let third = engine.submit(.integer(7))

        XCTAssertFalse(third.canRetry)
        XCTAssertTrue(third.revealsAnswer)
        XCTAssertTrue(third.message.contains("1"), "答えを教えてあげる")
        XCTAssertFalse(third.message.contains("まちがい"))
        XCTAssertFalse(third.message.contains("ざんねん"))
    }

    func testUnclearSpeechDoesNotConsumeAnAttempt() {
        let engine = makeEngine()
        engine.start()
        let feedback = engine.submit(.speech(transcript: "わかんない", confidence: 0.9))
        XCTAssertEqual(feedback.judgement, .unclear)
        XCTAssertTrue(feedback.canRetry)
        XCTAssertEqual(engine.currentAttemptCount, 0, "挑戦回数に数えない")
        XCTAssertTrue(engine.attemptRecords.isEmpty, "履歴にも残さない")
        XCTAssertEqual(feedback.message, "もういちど いってみよう！")
    }

    func testAdvanceMovesThroughQuestionsAndCompletes() {
        let engine = makeEngine(questionCount: 2)
        engine.start()
        _ = engine.submit(.integer(1))
        XCTAssertEqual(engine.advance(), .asking(index: 1))
        _ = engine.submit(.integer(2))
        guard case let .completed(summary) = engine.advance() else {
            return XCTFail("完了していない")
        }
        XCTAssertEqual(summary.questionCount, 2)
        XCTAssertEqual(summary.correctCount, 2)
        XCTAssertEqual(summary.starsEarned, 4)
        XCTAssertEqual(summary.attempts.count, 2)
        XCTAssertTrue(engine.isCompleted)
    }

    func testParticipationStarIsAlwaysAwarded() {
        let engine = makeEngine(questionCount: 1)
        engine.start()
        _ = engine.submit(.integer(99))
        engine.retry()
        _ = engine.submit(.integer(98))
        engine.retry()
        _ = engine.submit(.integer(97))
        guard case let .completed(summary) = engine.advance() else {
            return XCTFail("完了していない")
        }
        XCTAssertEqual(summary.correctCount, 0)
        XCTAssertEqual(summary.starsEarned, StarRule.participationStars, "0★ にはしない")
        XCTAssertFalse(summary.childMessage.isEmpty)
    }

    func testAttemptRecordsCaptureAnswerModeAndDuration() {
        let clock = MutableClock()
        let engine = makeEngine(questionCount: 1, clock: clock)
        engine.start()
        clock.advance(by: 12)
        _ = engine.submit(.choice(id: Fixture.correctChoiceID(engine.currentQuestion!)!))

        let record = engine.attemptRecords.first
        XCTAssertEqual(record?.answerMode, .choice)
        XCTAssertEqual(record?.judgement, .correct)
        XCTAssertEqual(record?.duration ?? 0, 12, accuracy: 0.001)
        XCTAssertEqual(record?.skill, .numberCount)
    }

    func testProgressReportsPosition() {
        let engine = makeEngine(questionCount: 4)
        engine.start()
        XCTAssertEqual(engine.progress, 0, accuracy: 0.001)
        _ = engine.submit(.integer(1))
        engine.advance()
        XCTAssertEqual(engine.progress, 0.25, accuracy: 0.001)
    }

    func testFinishEarlyKeepsWhatWasDone() {
        let clock = MutableClock()
        let engine = makeEngine(questionCount: 4, clock: clock)
        engine.start()
        _ = engine.submit(.integer(1))
        clock.advance(by: 30)
        let summary = engine.finishEarly()
        XCTAssertEqual(summary.correctCount, 1)
        XCTAssertEqual(summary.record.duration, 30, accuracy: 0.001)
        XCTAssertTrue(engine.isCompleted)
    }

    func testRetryingTheSameQuestionCountsCorrectOnlyOnce() {
        let engine = makeEngine(questionCount: 1)
        engine.start()
        _ = engine.submit(.integer(1))
        // 何らかの理由でもう一度正解しても、正答数は増えない
        engine.retry()
        _ = engine.submit(.integer(1))
        XCTAssertEqual(engine.correctCount, 1)
    }

    func testFeedbackMessagesStayPositive() {
        let negativeWords = ["まちがい", "ざんねん", "だめ", "おそい", "しっぱい"]
        let cases: [(AnswerJudgement, Int, Bool)] = [
            (.correct, 1, false), (.correct, 2, false),
            (.incorrect, 1, false), (.incorrect, 3, true), (.unclear, 1, false)
        ]
        for (judgement, attempt, outOfAttempts) in cases {
            let message = LearningSessionEngine.message(
                judgement: judgement,
                attemptIndex: attempt,
                outOfAttempts: outOfAttempts,
                correctAnswerDisplay: "3"
            )
            XCTAssertFalse(message.isEmpty)
            for word in negativeWords {
                XCTAssertFalse(message.contains(word), "「\(message)」に否定的な語が含まれている")
            }
        }
    }
}

final class LearningResultProcessorTests: XCTestCase {

    private func makeSummary(
        skill: Skill = .numberCount,
        judgements: [AnswerJudgement],
        level: DifficultyLevel = .level1,
        stars: Int = 4
    ) -> SessionSummary {
        let base = Fixture.referenceDate
        let attempts = judgements.enumerated().map { index, judgement in
            Fixture.attempt(
                skill: skill,
                judgement: judgement,
                level: level,
                at: base.addingTimeInterval(Double(index))
            )
        }
        let record = SessionRecord(
            kind: .dailyChallenge,
            startedAt: base,
            endedAt: base.addingTimeInterval(180),
            questionCount: judgements.count,
            correctCount: judgements.filter(\.isCorrect).count,
            starsEarned: stars
        )
        return SessionSummary(record: record, attempts: attempts)
    }

    func testStoresAttemptsAndSession() {
        let store = InMemoryLearningHistoryStore()
        let processor = LearningResultProcessor()
        let summary = makeSummary(judgements: [.correct, .incorrect, .correct])

        processor.process(
            summary: summary,
            settings: Fixture.settings(),
            store: store,
            now: Fixture.referenceDate.addingTimeInterval(200)
        )

        XCTAssertEqual(store.attempts().count, 3)
        XCTAssertEqual(store.sessions().count, 1)
        XCTAssertEqual(store.masterySnapshots()[.numberCount]?.attempts, 3)
        XCTAssertEqual(store.masterySnapshots()[.numberCount]?.correctCount, 2)
    }

    func testUnclearAttemptsAreStoredButNotCounted() {
        let store = InMemoryLearningHistoryStore()
        let processor = LearningResultProcessor()
        let summary = makeSummary(judgements: [.correct, .unclear, .unclear])

        processor.process(
            summary: summary,
            settings: Fixture.settings(),
            store: store,
            now: Fixture.referenceDate.addingTimeInterval(200)
        )

        XCTAssertEqual(store.attempts().count, 3, "記録自体は残す")
        XCTAssertEqual(store.masterySnapshots()[.numberCount]?.attempts, 1, "習熟度には 1 件だけ反映")
    }

    func testDifficultyIsRaisedAfterStrongPerformance() {
        let store = InMemoryLearningHistoryStore()
        let processor = LearningResultProcessor()
        let summary = makeSummary(judgements: Array(repeating: .correct, count: 8))

        let outcome = processor.process(
            summary: summary,
            settings: Fixture.settings(),
            store: store,
            now: Fixture.referenceDate.addingTimeInterval(200)
        )

        XCTAssertEqual(outcome.adjustments[.numberCount]?.level, .level2)
        XCTAssertEqual(store.masterySnapshots()[.numberCount]?.level, .level2)
        XCTAssertEqual(store.masterySnapshots()[.numberCount]?.attemptsAtCurrentLevel, 0)
    }

    func testUnlocksAreReportedOnce() {
        let store = InMemoryLearningHistoryStore()
        let processor = LearningResultProcessor()
        // ★10 で「ぼうし」が解放される
        let summary = makeSummary(judgements: [.correct, .correct], stars: 12)

        let first = processor.process(
            summary: summary,
            settings: Fixture.settings(),
            store: store,
            now: Fixture.referenceDate.addingTimeInterval(200)
        )
        XCTAssertTrue(first.newlyUnlocked.contains { $0.id == "costume.cap" })

        let second = processor.process(
            summary: makeSummary(judgements: [.correct], stars: 1),
            settings: Fixture.settings(),
            store: store,
            now: Fixture.referenceDate.addingTimeInterval(400)
        )
        XCTAssertFalse(second.newlyUnlocked.contains { $0.id == "costume.cap" }, "同じアンロックを二度報告しない")
    }

    func testMealSessionIsRecorded() {
        let store = InMemoryLearningHistoryStore()
        let processor = LearningResultProcessor()
        let meal = MealSessionRecord(
            characterID: "kuma",
            targetDuration: 900,
            actualDuration: 780,
            childFinishedFirst: true,
            startedAt: Fixture.referenceDate
        )

        let outcome = processor.process(
            meal: meal,
            starsEarned: 3,
            store: store,
            now: Fixture.referenceDate.addingTimeInterval(800)
        )

        XCTAssertEqual(store.mealSessions().count, 1)
        XCTAssertEqual(store.sessions().count, 1)
        XCTAssertEqual(outcome.summary.mealsCompleted, 1)
        XCTAssertEqual(outcome.summary.totalStars, 3)
    }
}

final class ProgressAggregatorTests: XCTestCase {

    private let calendar = Calendar.piyo

    func testDailyStatsCoverRequestedWindow() {
        let aggregator = ProgressAggregator()
        let now = Fixture.referenceDate
        let attempts = [
            Fixture.attempt(skill: .numberCount, judgement: .correct, at: now),
            Fixture.attempt(skill: .numberCount, judgement: .incorrect, at: now),
            Fixture.attempt(
                skill: .numberCount,
                judgement: .correct,
                at: calendar.date(byAdding: .day, value: -2, to: now)!
            )
        ]
        let stats = aggregator.dailyStats(attempts: attempts, sessions: [], now: now, dayCount: 7)
        XCTAssertEqual(stats.count, 7)
        XCTAssertEqual(stats.last?.questionCount, 2)
        XCTAssertEqual(stats.last?.correctCount, 1)
        XCTAssertEqual(stats.last?.accuracy ?? 0, 0.5, accuracy: 0.0001)
        XCTAssertEqual(stats[4].questionCount, 1, "2 日前のぶん")
        XCTAssertFalse(stats[0].didStudy)
    }

    func testUnclearAttemptsAreExcludedFromDailyStats() {
        let aggregator = ProgressAggregator()
        let now = Fixture.referenceDate
        let attempts = [
            Fixture.attempt(skill: .numberCount, judgement: .correct, at: now),
            Fixture.attempt(skill: .numberCount, judgement: .unclear, mode: .voice, at: now)
        ]
        let stats = aggregator.dailyStats(attempts: attempts, sessions: [], now: now, dayCount: 1)
        XCTAssertEqual(stats.last?.questionCount, 1)
    }

    func testLearningDaysCountsUniqueDays() {
        let aggregator = ProgressAggregator()
        let now = Fixture.referenceDate
        let attempts = [
            Fixture.attempt(skill: .numberCount, judgement: .correct, at: now),
            Fixture.attempt(skill: .numberCount, judgement: .correct, at: now.addingTimeInterval(60)),
            Fixture.attempt(
                skill: .numberCount,
                judgement: .correct,
                at: calendar.date(byAdding: .day, value: -1, to: now)!
            )
        ]
        XCTAssertEqual(aggregator.learningDays(attempts: attempts, sessions: []), 2)
    }

    func testSubjectStatsAndStrengths() {
        let aggregator = ProgressAggregator()
        let now = Fixture.referenceDate
        var strong = MasterySnapshot(skill: .hiraganaRead, level: .level4)
        strong.attempts = 20
        strong.correctCount = 19
        strong.ewma = 0.95
        strong.lastPracticedAt = now

        var weakSkill = MasterySnapshot(skill: .clockRead, level: .level1)
        weakSkill.attempts = 20
        weakSkill.correctCount = 4
        weakSkill.ewma = 0.2
        weakSkill.lastPracticedAt = now

        let attempts =
            (0 ..< 20).map { index in
                Fixture.attempt(
                    skill: .hiraganaRead,
                    judgement: index == 0 ? .incorrect : .correct,
                    at: now
                )
            }
            + (0 ..< 20).map { index in
                Fixture.attempt(
                    skill: .clockRead,
                    judgement: index < 4 ? .correct : .incorrect,
                    at: now
                )
            }

        let summary = aggregator.summarize(
            attempts: attempts,
            sessions: [],
            mealSessions: [],
            snapshots: [.hiraganaRead: strong, .clockRead: weakSkill],
            now: now
        )

        XCTAssertEqual(summary.totalQuestions, 40)
        XCTAssertEqual(summary.totalCorrect, 23)
        XCTAssertTrue(summary.strengths.contains(.hiragana))
        XCTAssertTrue(summary.weaknesses.contains(.clock))
        XCTAssertFalse(summary.strengths.contains(where: { summary.weaknesses.contains($0) }))
    }

    func testRecentActivitiesAreSortedNewestFirst() {
        let aggregator = ProgressAggregator()
        let now = Fixture.referenceDate
        let sessions = [
            SessionRecord(
                kind: .dailyChallenge,
                startedAt: now.addingTimeInterval(-3600),
                endedAt: now.addingTimeInterval(-3300),
                questionCount: 8,
                correctCount: 6,
                starsEarned: 10
            )
        ]
        let meals = [
            MealSessionRecord(
                characterID: "kuma",
                targetDuration: 900,
                actualDuration: 800,
                childFinishedFirst: true,
                startedAt: now
            )
        ]
        let activities = aggregator.recentActivities(sessions: sessions, mealSessions: meals)
        XCTAssertEqual(activities.count, 2)
        XCTAssertEqual(activities.first?.title, "ごはんタイマー")
        XCTAssertTrue(activities.last?.detail.contains("6/8") ?? false)
    }

    func testUnlockProgressConversion() {
        let aggregator = ProgressAggregator()
        var snapshot = MasterySnapshot(skill: .hiraganaRead, level: .level4)
        snapshot.attempts = 20
        snapshot.correctCount = 19
        snapshot.ewma = 0.95

        let summary = ProgressSummary(
            totalQuestions: 20,
            totalCorrect: 19,
            totalStars: 42,
            learningDays: 4,
            challengesCompleted: 6,
            mealsCompleted: 2,
            totalStudySeconds: 600,
            dailyStats: [],
            subjectStats: [],
            strengths: [],
            weaknesses: [],
            recentActivities: []
        )
        let progress = aggregator.unlockProgress(from: summary, snapshots: [.hiraganaRead: snapshot])
        XCTAssertEqual(progress.totalStars, 42)
        XCTAssertEqual(progress.learningDays, 4)
        XCTAssertEqual(progress.mealsCompleted, 2)
        XCTAssertEqual(progress.challengesCompleted, 6)
        XCTAssertNotNil(progress.subjectMastery[.hiragana])
    }
}
