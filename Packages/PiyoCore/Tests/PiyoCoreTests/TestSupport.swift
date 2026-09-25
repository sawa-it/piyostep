import Foundation
@testable import PiyoCore

enum Fixture {
    static let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)

    static func profile(age: Int = 5, name: String = "さくら") -> ChildProfile {
        ChildProfile(nickname: name, age: age, createdAt: referenceDate)
    }

    static func settings(
        dailyGoal: DailyGoal = .normal,
        difficultyMode: DifficultyMode = .automatic,
        enabledSubjects: Set<Subject> = Set(Subject.allCases),
        voiceAnswerEnabled: Bool = true
    ) -> AppSettings {
        AppSettings(
            difficultyMode: difficultyMode,
            voiceAnswerEnabled: voiceAnswerEnabled,
            dailyGoal: dailyGoal,
            enabledSubjects: enabledSubjects
        )
    }

    static func random(seed: UInt64 = 20_240_101) -> SeededRandomSource {
        SeededRandomSource(seed: seed)
    }

    static func attempt(
        skill: Skill,
        judgement: AnswerJudgement,
        level: DifficultyLevel = .level1,
        mode: AnswerMode = .choice,
        at date: Date = referenceDate
    ) -> AttemptRecord {
        AttemptRecord(
            skill: skill,
            difficulty: level,
            judgement: judgement,
            answerMode: mode,
            createdAt: date
        )
    }

    /// 選択肢のうち正解のものの ID。
    static func correctChoiceID(_ question: Question) -> UUID? {
        question.choices.first(where: { $0.isCorrect })?.id
    }

    /// 選択肢のうち誤答のものの ID。
    static func wrongChoiceID(_ question: Question) -> UUID? {
        question.choices.first(where: { !$0.isCorrect })?.id
    }

    /// テスト用の単純な問題。
    static func integerQuestion(correct: Int = 3, skill: Skill = .numberCount) -> Question {
        let choices = [correct, correct + 1, correct + 2, max(0, correct - 1)]
            .enumerated()
            .map { index, value in
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
            prompt: Prompt(displayText: "いくつ？", spokenText: "いくつ かな？"),
            content: .countObjects(kind: .apple, count: correct),
            answer: .integer(correct),
            answerModes: [.choice, .numberPad, .voice],
            choices: choices
        )
    }
}
