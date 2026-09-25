import Foundation

/// Skill から適切なジェネレーターを引く。
public struct QuestionFactory {
    private let generators: [Skill: any QuestionGenerating]

    public init(generators: [any QuestionGenerating]? = nil) {
        let list = generators ?? QuestionFactory.defaultGenerators
        var map: [Skill: any QuestionGenerating] = [:]
        for generator in list {
            map[generator.skill] = generator
        }
        self.generators = map
    }

    public static var defaultGenerators: [any QuestionGenerating] {
        [
            ClockReadQuestionGenerator(),
            ClockSetQuestionGenerator(),
            KanaReadQuestionGenerator(subject: .hiragana),
            KanaWriteQuestionGenerator(subject: .hiragana),
            KanaWordQuestionGenerator(subject: .hiragana),
            KanaReadQuestionGenerator(subject: .katakana),
            KanaWriteQuestionGenerator(subject: .katakana),
            KanaWordQuestionGenerator(subject: .katakana),
            CountQuestionGenerator(),
            NumberReadQuestionGenerator(),
            PlaceValueQuestionGenerator(),
            AlphabetReadQuestionGenerator(),
            AlphabetWriteQuestionGenerator(),
            EnglishWordQuestionGenerator()
        ]
    }

    public func generator(for skill: Skill) -> (any QuestionGenerating)? {
        generators[skill]
    }

    /// 1 問つくる。対応するジェネレーターがなければ nil。
    public func makeQuestion(
        skill: Skill,
        level: DifficultyLevel,
        random: RandomSource,
        allowVoice: Bool
    ) -> Question? {
        generators[skill]?.generate(level: level, random: random, allowVoice: allowVoice)
    }

    /// 対応している Skill 一覧。
    public var supportedSkills: [Skill] {
        Skill.allCases.filter { generators[$0] != nil }
    }
}
