import XCTest
@testable import PiyoCore

final class MasteryEstimatorTests: XCTestCase {

    func testCorrectAnswerRaisesEWMA() {
        let estimator = MasteryEstimator(alpha: 0.3)
        let snapshot = MasterySnapshot(skill: .numberCount)
        let updated = estimator.apply(
            attempt: Fixture.attempt(skill: .numberCount, judgement: .correct),
            to: snapshot
        )
        XCTAssertEqual(updated.ewma, 0.5 * 0.7 + 0.3, accuracy: 0.0001)
        XCTAssertEqual(updated.attempts, 1)
        XCTAssertEqual(updated.correctCount, 1)
        XCTAssertEqual(updated.attemptsAtCurrentLevel, 1)
    }

    func testIncorrectAnswerLowersEWMA() {
        let estimator = MasteryEstimator(alpha: 0.3)
        var snapshot = MasterySnapshot(skill: .numberCount)
        snapshot.ewma = 0.8
        let updated = estimator.apply(
            attempt: Fixture.attempt(skill: .numberCount, judgement: .incorrect),
            to: snapshot
        )
        XCTAssertEqual(updated.ewma, 0.8 * 0.7, accuracy: 0.0001)
        XCTAssertEqual(updated.attempts, 1)
        XCTAssertEqual(updated.correctCount, 0)
    }

    func testUnclearSpeechDoesNotAffectMastery() {
        let estimator = MasteryEstimator()
        let snapshot = MasterySnapshot(skill: .hiraganaRead)
        let updated = estimator.apply(
            attempt: Fixture.attempt(skill: .hiraganaRead, judgement: .unclear, mode: .voice),
            to: snapshot
        )
        XCTAssertEqual(updated.ewma, snapshot.ewma, accuracy: 0.0001)
        XCTAssertEqual(updated.attempts, 0)
        XCTAssertEqual(updated.attemptsAtCurrentLevel, 0)
        XCTAssertNotNil(updated.lastPracticedAt, "練習した事実だけは残す")
    }

    func testAccuracyAndMasteryScore() {
        var snapshot = MasterySnapshot(skill: .numberCount, level: .level3)
        XCTAssertNil(snapshot.accuracy)
        XCTAssertEqual(snapshot.masteryScore, 0, accuracy: 0.0001)

        snapshot.attempts = 10
        snapshot.correctCount = 8
        snapshot.ewma = 0.8
        XCTAssertEqual(snapshot.accuracy ?? 0, 0.8, accuracy: 0.0001)
        XCTAssertGreaterThan(snapshot.masteryScore, 0.5)
        XCTAssertLessThanOrEqual(snapshot.masteryScore, 1.0)
    }

    func testMasteryScoreIsDampenedWhenFewAttempts() {
        var few = MasterySnapshot(skill: .numberCount, level: .level3)
        few.attempts = 2
        few.correctCount = 2
        few.ewma = 0.9

        var many = few
        many.attempts = 20
        many.correctCount = 18

        XCTAssertLessThan(few.masteryScore, many.masteryScore)
    }

    func testRecentAccuracyWindow() {
        let estimator = MasteryEstimator(windowSize: 3)
        let base = Fixture.referenceDate
        let attempts = [
            Fixture.attempt(skill: .numberCount, judgement: .incorrect, at: base),
            Fixture.attempt(skill: .numberCount, judgement: .correct, at: base.addingTimeInterval(10)),
            Fixture.attempt(skill: .numberCount, judgement: .correct, at: base.addingTimeInterval(20)),
            Fixture.attempt(skill: .numberCount, judgement: .correct, at: base.addingTimeInterval(30))
        ]
        // 直近 3 件はすべて正解
        XCTAssertEqual(estimator.recentAccuracy(for: .numberCount, in: attempts) ?? 0, 1.0, accuracy: 0.0001)
        XCTAssertNil(estimator.recentAccuracy(for: .clockRead, in: attempts))
    }

    func testSnapshotsFromHistory() {
        let estimator = MasteryEstimator()
        let base = Fixture.referenceDate
        let attempts = [
            Fixture.attempt(skill: .hiraganaRead, judgement: .correct, level: .level2, at: base),
            Fixture.attempt(skill: .hiraganaRead, judgement: .correct, level: .level2, at: base.addingTimeInterval(5)),
            Fixture.attempt(skill: .clockRead, judgement: .incorrect, level: .level1, at: base.addingTimeInterval(10))
        ]
        let snapshots = estimator.snapshots(from: attempts)
        XCTAssertEqual(snapshots.count, 2)
        XCTAssertEqual(snapshots[.hiraganaRead]?.attempts, 2)
        XCTAssertEqual(snapshots[.hiraganaRead]?.correctCount, 2)
        XCTAssertEqual(snapshots[.hiraganaRead]?.level, .level2)
        XCTAssertEqual(snapshots[.clockRead]?.correctCount, 0)
    }

    func testSubjectMasteryAveragesSkills() {
        let estimator = MasteryEstimator()
        var read = MasterySnapshot(skill: .hiraganaRead, level: .level3)
        read.attempts = 20
        read.correctCount = 20
        read.ewma = 1.0
        var write = MasterySnapshot(skill: .hiraganaWrite, level: .level1)
        write.attempts = 20
        write.correctCount = 0
        write.ewma = 0.0

        let mastery = estimator.subjectMastery(from: [.hiraganaRead: read, .hiraganaWrite: write])
        let value = mastery[.hiragana] ?? -1
        XCTAssertGreaterThan(value, 0)
        XCTAssertLessThan(value, read.masteryScore)
    }
}

final class AdaptiveDifficultyEngineTests: XCTestCase {

    func testPromotesWhenDoingWell() {
        let engine = AdaptiveDifficultyEngine()
        var snapshot = MasterySnapshot(skill: .numberCount, level: .level2)
        snapshot.ewma = 0.85
        snapshot.attemptsAtCurrentLevel = 6

        let adjustment = engine.adjust(snapshot: snapshot, mode: .automatic)
        XCTAssertEqual(adjustment, .increased(from: .level2, to: .level3))
        XCTAssertTrue(adjustment.didChange)
    }

    func testDoesNotPromoteWithoutEnoughAttempts() {
        let engine = AdaptiveDifficultyEngine()
        var snapshot = MasterySnapshot(skill: .numberCount, level: .level2)
        snapshot.ewma = 0.95
        snapshot.attemptsAtCurrentLevel = 3
        XCTAssertEqual(engine.adjust(snapshot: snapshot, mode: .automatic), .unchanged(.level2))
    }

    func testDemotesWhenStruggling() {
        let engine = AdaptiveDifficultyEngine()
        var snapshot = MasterySnapshot(skill: .numberCount, level: .level3)
        snapshot.ewma = 0.3
        snapshot.attemptsAtCurrentLevel = 4
        XCTAssertEqual(engine.adjust(snapshot: snapshot, mode: .automatic), .decreased(from: .level3, to: .level2))
    }

    func testNeverGoesBelowLevel1() {
        let engine = AdaptiveDifficultyEngine()
        var snapshot = MasterySnapshot(skill: .numberCount, level: .level1)
        snapshot.ewma = 0.1
        snapshot.attemptsAtCurrentLevel = 10
        XCTAssertEqual(engine.adjust(snapshot: snapshot, mode: .automatic), .unchanged(.level1))
    }

    func testNeverGoesAboveLevel5() {
        let engine = AdaptiveDifficultyEngine()
        var snapshot = MasterySnapshot(skill: .numberCount, level: .level5)
        snapshot.ewma = 1.0
        snapshot.attemptsAtCurrentLevel = 20
        XCTAssertEqual(engine.adjust(snapshot: snapshot, mode: .automatic), .unchanged(.level5))
    }

    func testManualModeClampsIntoAllowedRange() {
        let engine = AdaptiveDifficultyEngine()
        var snapshot = MasterySnapshot(skill: .numberCount, level: .level5)
        snapshot.ewma = 0.9
        snapshot.attemptsAtCurrentLevel = 10
        // 「かんたん」は Lv1-2 に制限される
        XCTAssertEqual(engine.adjust(snapshot: snapshot, mode: .easy), .decreased(from: .level5, to: .level2))
    }

    func testApplyingAdjustmentResetsCounters() {
        let engine = AdaptiveDifficultyEngine()
        var snapshot = MasterySnapshot(skill: .numberCount, level: .level2)
        snapshot.ewma = 0.9
        snapshot.attemptsAtCurrentLevel = 8
        let adjustment = engine.adjust(snapshot: snapshot, mode: .automatic)
        let updated = engine.applying(adjustment: adjustment, to: snapshot)
        XCTAssertEqual(updated.level, .level3)
        XCTAssertEqual(updated.attemptsAtCurrentLevel, 0)
        XCTAssertEqual(updated.ewma, MasterySnapshot.initialEWMA, accuracy: 0.0001)
    }

    func testApplyingUnchangedKeepsCounters() {
        let engine = AdaptiveDifficultyEngine()
        var snapshot = MasterySnapshot(skill: .numberCount, level: .level2)
        snapshot.ewma = 0.6
        snapshot.attemptsAtCurrentLevel = 3
        let updated = engine.applying(adjustment: .unchanged(.level2), to: snapshot)
        XCTAssertEqual(updated.attemptsAtCurrentLevel, 3)
        XCTAssertEqual(updated.ewma, 0.6, accuracy: 0.0001)
    }

    func testNeedsReviewAfterThreeConsecutiveMisses() {
        let engine = AdaptiveDifficultyEngine()
        let base = Fixture.referenceDate
        let attempts = (0 ..< 3).map { index in
            Fixture.attempt(
                skill: .clockRead,
                judgement: .incorrect,
                at: base.addingTimeInterval(Double(index))
            )
        }
        XCTAssertTrue(engine.needsReview(recentAttempts: attempts, skill: .clockRead))
        XCTAssertFalse(engine.needsReview(recentAttempts: attempts, skill: .numberCount))
    }

    func testUnclearAnswersDoNotTriggerReview() {
        let engine = AdaptiveDifficultyEngine()
        let base = Fixture.referenceDate
        var attempts = (0 ..< 2).map { index in
            Fixture.attempt(skill: .clockRead, judgement: .incorrect, at: base.addingTimeInterval(Double(index)))
        }
        attempts.append(
            Fixture.attempt(skill: .clockRead, judgement: .unclear, mode: .voice, at: base.addingTimeInterval(9))
        )
        XCTAssertFalse(
            engine.needsReview(recentAttempts: attempts, skill: .clockRead),
            "聞き取れなかった回答は連続不正解に数えない"
        )
    }

    func testReviewLevelIsOneStepEasier() {
        let engine = AdaptiveDifficultyEngine()
        XCTAssertEqual(engine.reviewLevel(for: .level4, mode: .automatic), .level3)
        XCTAssertEqual(engine.reviewLevel(for: .level1, mode: .automatic), .level1)
        XCTAssertEqual(engine.reviewLevel(for: .level3, mode: .hard), .level3, "むずかしいモードでは Lv3 が下限")
    }
}

final class DailyChallengeBuilderTests: XCTestCase {

    func testProducesRequestedNumberOfQuestions() {
        let builder = DailyChallengeBuilder()
        for goal in DailyGoal.allCases {
            let challenge = builder.build(
                profile: Fixture.profile(age: 6),
                settings: Fixture.settings(dailyGoal: goal),
                snapshots: [:],
                now: Fixture.referenceDate,
                random: Fixture.random()
            )
            XCTAssertEqual(challenge.questionCount, goal.questionCount)
        }
    }

    func testMixesMultipleSubjects() {
        let builder = DailyChallengeBuilder()
        let challenge = builder.build(
            profile: Fixture.profile(age: 6),
            settings: Fixture.settings(dailyGoal: .plenty),
            snapshots: [:],
            now: Fixture.referenceDate,
            random: Fixture.random(seed: 31)
        )
        XCTAssertGreaterThanOrEqual(challenge.subjects.count, 2, "複数教科を組み合わせる")
    }

    func testNeverRepeatsTheSameSkillThreeTimesInARow() {
        let builder = DailyChallengeBuilder()
        for seed in UInt64(1) ... 30 {
            let challenge = builder.build(
                profile: Fixture.profile(age: 6),
                settings: Fixture.settings(dailyGoal: .plenty),
                snapshots: [:],
                now: Fixture.referenceDate,
                random: Fixture.random(seed: seed)
            )
            let skills = challenge.skills
            guard skills.count >= 3 else { continue }
            for index in 0 ... (skills.count - 3) {
                let window = skills[index ..< index + 3]
                XCTAssertGreaterThan(Set(window).count, 1, "seed \(seed): 同じ Skill が 3 連続している")
            }
        }
    }

    func testRespectsAgeRestrictions() {
        let builder = DailyChallengeBuilder()
        let skills = builder.availableSkills(
            profile: Fixture.profile(age: 3),
            settings: Fixture.settings()
        )
        XCTAssertFalse(skills.contains(.placeValue), "3歳には位の問題を出さない")
        XCTAssertFalse(skills.contains(.clockRead), "3歳には時計を出さない")
        XCTAssertTrue(skills.contains(.hiraganaRead))
        XCTAssertTrue(skills.contains(.numberCount))
    }

    func testRespectsDisabledSubjects() {
        let builder = DailyChallengeBuilder()
        let challenge = builder.build(
            profile: Fixture.profile(age: 6),
            settings: Fixture.settings(dailyGoal: .plenty, enabledSubjects: [.hiragana, .number]),
            snapshots: [:],
            now: Fixture.referenceDate,
            random: Fixture.random(seed: 5)
        )
        XCTAssertTrue(challenge.questions.allSatisfy { [.hiragana, .number].contains($0.subject) })
    }

    func testFallsBackWhenNoSubjectIsEnabled() {
        let builder = DailyChallengeBuilder()
        var settings = Fixture.settings()
        settings.enabledSubjects = []
        let skills = builder.availableSkills(profile: Fixture.profile(age: 6), settings: settings)
        XCTAssertFalse(skills.isEmpty, "学習が止まらないようにフォールバックする")
    }

    func testWeightPrefersWeakerSkills() {
        let builder = DailyChallengeBuilder()
        var strong = MasterySnapshot(skill: .hiraganaRead, level: .level4)
        strong.attempts = 30
        strong.correctCount = 30
        strong.ewma = 1.0
        strong.lastPracticedAt = Fixture.referenceDate

        var weakSkill = MasterySnapshot(skill: .numberCount, level: .level1)
        weakSkill.attempts = 30
        weakSkill.correctCount = 5
        weakSkill.ewma = 0.15
        weakSkill.lastPracticedAt = Fixture.referenceDate

        let strongWeight = builder.weight(for: .hiraganaRead, snapshot: strong, now: Fixture.referenceDate)
        let weakWeight = builder.weight(for: .numberCount, snapshot: weakSkill, now: Fixture.referenceDate)
        XCTAssertGreaterThan(weakWeight, strongWeight)
    }

    func testWeightPrefersSkillsNotPractisedRecently() {
        let builder = DailyChallengeBuilder()
        var recent = MasterySnapshot(skill: .hiraganaRead)
        recent.attempts = 10
        recent.correctCount = 5
        recent.ewma = 0.5
        recent.lastPracticedAt = Fixture.referenceDate

        var stale = recent
        stale.lastPracticedAt = Fixture.referenceDate.addingTimeInterval(-10 * 86_400)

        XCTAssertGreaterThan(
            builder.weight(for: .hiraganaRead, snapshot: stale, now: Fixture.referenceDate),
            builder.weight(for: .hiraganaRead, snapshot: recent, now: Fixture.referenceDate)
        )
    }

    func testUnseenSkillsGetHighPriority() {
        let builder = DailyChallengeBuilder()
        var practised = MasterySnapshot(skill: .hiraganaRead)
        practised.attempts = 10
        practised.correctCount = 9
        practised.ewma = 0.9
        practised.lastPracticedAt = Fixture.referenceDate

        XCTAssertGreaterThan(
            builder.weight(for: .katakanaRead, snapshot: nil, now: Fixture.referenceDate),
            builder.weight(for: .hiraganaRead, snapshot: practised, now: Fixture.referenceDate)
        )
    }

    func testFirstQuestionIsAWarmUp() {
        let builder = DailyChallengeBuilder()
        var strong = MasterySnapshot(skill: .hiraganaRead, level: .level4)
        strong.attempts = 30
        strong.correctCount = 30
        strong.ewma = 1.0

        let challenge = builder.build(
            profile: Fixture.profile(age: 6),
            settings: Fixture.settings(),
            snapshots: [.hiraganaRead: strong],
            now: Fixture.referenceDate,
            random: Fixture.random(seed: 2)
        )
        XCTAssertEqual(challenge.questions.first?.skill, .hiraganaRead, "得意な Skill から始める")
        XCTAssertEqual(challenge.questions.first?.difficulty, .level3, "1 問目は 1 段やさしく")
    }

    func testReviewLowersLevelAfterConsecutiveMisses() {
        let builder = DailyChallengeBuilder()
        var snapshot = MasterySnapshot(skill: .clockRead, level: .level4)
        snapshot.attempts = 10
        snapshot.correctCount = 3
        let base = Fixture.referenceDate
        let misses = (0 ..< 3).map { index in
            Fixture.attempt(
                skill: .clockRead,
                judgement: .incorrect,
                level: .level4,
                at: base.addingTimeInterval(Double(index))
            )
        }

        let level = builder.level(
            for: .clockRead,
            snapshot: snapshot,
            settings: Fixture.settings(),
            profile: Fixture.profile(age: 6),
            recentAttempts: misses
        )
        XCTAssertEqual(level, .level3)
    }

    func testDeterministicForSameSeed() {
        let builder = DailyChallengeBuilder()
        let first = builder.build(
            profile: Fixture.profile(age: 6),
            settings: Fixture.settings(),
            snapshots: [:],
            now: Fixture.referenceDate,
            random: Fixture.random(seed: 777)
        )
        let second = builder.build(
            profile: Fixture.profile(age: 6),
            settings: Fixture.settings(),
            snapshots: [:],
            now: Fixture.referenceDate,
            random: Fixture.random(seed: 777)
        )
        XCTAssertEqual(first.skills, second.skills)
        XCTAssertEqual(
            first.questions.map(\.prompt.displayText),
            second.questions.map(\.prompt.displayText)
        )
    }

    func testVoiceCanBeTurnedOffGlobally() {
        let builder = DailyChallengeBuilder()
        let challenge = builder.build(
            profile: Fixture.profile(age: 6),
            settings: Fixture.settings(dailyGoal: .plenty, voiceAnswerEnabled: false),
            snapshots: [:],
            now: Fixture.referenceDate,
            random: Fixture.random(seed: 9)
        )
        XCTAssertTrue(challenge.questions.allSatisfy { !$0.answerModes.contains(.voice) })
        XCTAssertTrue(challenge.questions.allSatisfy { !$0.answerModes.isEmpty })
    }
}

final class ParentGateTests: XCTestCase {

    func testAdditionChallengeIsHardForPreschoolers() {
        let random = Fixture.random(seed: 3)
        for _ in 0 ..< 50 {
            let challenge = ParentGate.makeChallenge(random: random)
            if challenge.isAddition {
                XCTAssertGreaterThanOrEqual(challenge.leftOperand, 11)
                XCTAssertGreaterThanOrEqual(challenge.rightOperand, 12)
                XCTAssertEqual(challenge.answer, challenge.leftOperand + challenge.rightOperand)
            } else {
                XCTAssertGreaterThan(challenge.leftOperand, challenge.rightOperand)
                XCTAssertEqual(challenge.answer, challenge.leftOperand - challenge.rightOperand)
            }
            XCTAssertTrue(challenge.isCorrect(challenge.answer))
            XCTAssertFalse(challenge.isCorrect(challenge.answer + 1))
        }
    }

    func testQuestionTextMentionsBothOperands() {
        let challenge = ParentGateChallenge(leftOperand: 3, rightOperand: 4, isAddition: true)
        XCTAssertEqual(challenge.questionText, "3 + 4 は？")
        XCTAssertEqual(challenge.answer, 7)
    }

    func testBothOperationsAppear() {
        let random = Fixture.random(seed: 12)
        var sawAddition = false
        var sawSubtraction = false
        for _ in 0 ..< 60 {
            if ParentGate.makeChallenge(random: random).isAddition {
                sawAddition = true
            } else {
                sawSubtraction = true
            }
        }
        XCTAssertTrue(sawAddition && sawSubtraction)
    }
}

final class RandomSourceTests: XCTestCase {

    func testSeededSourceIsDeterministic() {
        let a = SeededRandomSource(seed: 99)
        let b = SeededRandomSource(seed: 99)
        for _ in 0 ..< 50 {
            XCTAssertEqual(a.nextInt(upperBound: 1000), b.nextInt(upperBound: 1000))
        }
    }

    func testDifferentSeedsDiverge() {
        let a = SeededRandomSource(seed: 1)
        let b = SeededRandomSource(seed: 2)
        let first = (0 ..< 20).map { _ in a.nextInt(upperBound: 1000) }
        let second = (0 ..< 20).map { _ in b.nextInt(upperBound: 1000) }
        XCTAssertNotEqual(first, second)
    }

    func testBoundsAreRespected() {
        let random = SeededRandomSource(seed: 5)
        for _ in 0 ..< 200 {
            let value = random.nextInt(in: 3 ... 7)
            XCTAssertTrue((3 ... 7).contains(value))
            let double = random.nextDouble()
            XCTAssertTrue((0.0 ..< 1.0).contains(double))
        }
        XCTAssertEqual(random.nextInt(upperBound: 0), 0)
    }

    func testShuffledKeepsAllElements() {
        let random = SeededRandomSource(seed: 8)
        let input = Array(1 ... 20)
        let shuffled = random.shuffled(input)
        XCTAssertEqual(Set(shuffled), Set(input))
        XCTAssertEqual(shuffled.count, input.count)
    }

    func testWeightedPickFavoursHeavyOptions() {
        let random = SeededRandomSource(seed: 4)
        let options = ["light", "heavy"]
        var heavyCount = 0
        for _ in 0 ..< 400 {
            if random.pickWeighted(options, weight: { $0 == "heavy" ? 9.0 : 1.0 }) == "heavy" {
                heavyCount += 1
            }
        }
        XCTAssertGreaterThan(heavyCount, 300)
    }

    func testWeightedPickFallsBackWhenAllWeightsAreZero() {
        let random = SeededRandomSource(seed: 6)
        XCTAssertNotNil(random.pickWeighted(["a", "b"], weight: { _ in 0 }))
        XCTAssertNil(random.pickWeighted([String](), weight: { _ in 1 }))
    }
}
