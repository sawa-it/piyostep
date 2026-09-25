import Foundation

/// 問題生成の共通インターフェース。
public protocol QuestionGenerating {
    var skill: Skill { get }
    /// 指定難易度の問題を 1 問つくる。
    /// - Parameter allowVoice: 設定や権限により音声回答を許すか。
    func generate(level: DifficultyLevel, random: RandomSource, allowVoice: Bool) -> Question
}

extension QuestionGenerating {
    /// 音声回答を許すかどうかを踏まえた回答手段を返す。
    func answerModes(_ base: [AnswerMode], allowVoice: Bool) -> [AnswerMode] {
        guard skill.supportsVoiceAnswer, allowVoice else {
            return base.filter { $0 != .voice }
        }
        return base
    }
}

/// 選択肢づくりの共通処理。
public enum ChoiceBuilder {

    /// 正解を含む `count` 個の整数選択肢をつくる。
    public static func integerChoices(
        correct: Int,
        count: Int,
        range: ClosedRange<Int>,
        random: RandomSource,
        spokenText: (Int) -> String = { "\($0)" },
        display: (Int) -> ChoiceDisplay = { .number($0) }
    ) -> [AnswerChoice] {
        var values: [Int] = [correct]
        // 近い値を優先して候補にする。
        var candidates: [Int] = []
        for delta in [1, -1, 2, -2, 3, -3, 10, -10, 5, -5] {
            let value = correct + delta
            if range.contains(value), value != correct {
                candidates.append(value)
            }
        }
        candidates = random.shuffled(candidates)
        for candidate in candidates where values.count < count {
            if !values.contains(candidate) { values.append(candidate) }
        }
        // それでも足りなければ範囲内からランダムに補う。
        var safety = 0
        while values.count < count && safety < 200 {
            safety += 1
            let value = random.nextInt(in: range)
            if !values.contains(value) { values.append(value) }
        }
        return random.shuffled(values).map { value in
            AnswerChoice(
                label: "\(value)",
                spokenText: spokenText(value),
                display: display(value),
                isCorrect: value == correct
            )
        }
    }

    /// 正解を含む `count` 個の任意要素の選択肢をつくる。
    public static func choices<T: Equatable>(
        correct: T,
        pool: [T],
        count: Int,
        random: RandomSource,
        label: (T) -> String,
        spokenText: (T) -> String,
        display: (T) -> ChoiceDisplay
    ) -> [AnswerChoice] {
        var values: [T] = [correct]
        let shuffledPool = random.shuffled(pool.filter { $0 != correct })
        for candidate in shuffledPool where values.count < count {
            values.append(candidate)
        }
        return random.shuffled(values).map { value in
            AnswerChoice(
                label: label(value),
                spokenText: spokenText(value),
                display: display(value),
                isCorrect: value == correct
            )
        }
    }
}
