import Foundation

/// 音声回答の扱いに関するしきい値。
public enum SpeechAnswerPolicy {
    /// これ未満の信頼度で、かつ正解候補にも誤答候補にも当たらない場合は「聞き取れなかった」とする。
    public static let lowConfidenceThreshold: Double = 0.45
    /// 連続してこの回数聞き取れなければ、タップ回答をすすめる。
    public static let unclearStreakBeforeFallback: Int = 3
}

/// 回答の正誤判定。
public struct AnswerGrader {

    public init() {}

    public func evaluate(question: Question, input: AnswerInput) -> AnswerEvaluation {
        let correctDisplay = AnswerGrader.correctAnswerDisplay(for: question)

        switch input {
        case .choice(let id):
            let judgement: AnswerJudgement
            if let choice = question.choices.first(where: { $0.id == id }) {
                judgement = choice.isCorrect ? .correct : .incorrect
            } else {
                judgement = .incorrect
            }
            return AnswerEvaluation(
                judgement: judgement,
                normalizedInput: question.choices.first(where: { $0.id == id })?.label,
                correctAnswerDisplay: correctDisplay
            )

        case .integer(let value):
            return AnswerEvaluation(
                judgement: AnswerGrader.judgeInteger(value, against: question.answer),
                normalizedInput: "\(value)",
                correctAnswerDisplay: correctDisplay
            )

        case .time(let time):
            guard case let .time(expected, tolerance) = question.answer else {
                return AnswerEvaluation(
                    judgement: .incorrect,
                    normalizedInput: time.displayJapanese,
                    correctAnswerDisplay: correctDisplay
                )
            }
            return AnswerEvaluation(
                judgement: time.matches(expected, toleranceMinutes: tolerance) ? .correct : .incorrect,
                normalizedInput: time.displayJapanese,
                correctAnswerDisplay: correctDisplay
            )

        case .trace(let coverage):
            guard case let .trace(required) = question.answer else {
                return AnswerEvaluation(
                    judgement: .incorrect,
                    normalizedInput: String(format: "%.2f", coverage),
                    correctAnswerDisplay: correctDisplay
                )
            }
            return AnswerEvaluation(
                judgement: coverage >= required ? .correct : .incorrect,
                normalizedInput: String(format: "%.2f", coverage),
                correctAnswerDisplay: correctDisplay
            )

        case .speech(let transcript, let confidence):
            return evaluateSpeech(
                question: question,
                transcript: transcript,
                confidence: confidence,
                correctDisplay: correctDisplay
            )

        case .skipped:
            return AnswerEvaluation(
                judgement: .incorrect,
                normalizedInput: nil,
                correctAnswerDisplay: correctDisplay
            )
        }
    }

    // MARK: - 音声

    private func evaluateSpeech(
        question: Question,
        transcript: String,
        confidence: Double,
        correctDisplay: String
    ) -> AnswerEvaluation {
        switch question.answer {
        case .time(let expected, let tolerance):
            let normalized = JapaneseTextNormalizer.normalize(transcript)
            guard !normalized.isEmpty else {
                return AnswerEvaluation(judgement: .unclear, normalizedInput: nil, correctAnswerDisplay: correctDisplay)
            }
            switch TimeSpeechParser.parse(transcript) {
            case .time(let spoken):
                return AnswerEvaluation(
                    judgement: spoken.matches(expected, toleranceMinutes: tolerance) ? .correct : .incorrect,
                    normalizedInput: spoken.displayJapanese,
                    correctAnswerDisplay: correctDisplay
                )
            case .bareNumber(let value):
                // 「さん」だけの発話。ちょうどの時刻なら「時」として受け取る。
                if expected.minute == 0, (1 ... 12).contains(value) {
                    let spoken = ClockTime(hour: value, minute: 0)
                    return AnswerEvaluation(
                        judgement: spoken == expected ? .correct : .incorrect,
                        normalizedInput: spoken.displayJapanese,
                        correctAnswerDisplay: correctDisplay
                    )
                }
                return AnswerEvaluation(
                    judgement: .unclear,
                    normalizedInput: normalized,
                    correctAnswerDisplay: correctDisplay
                )
            case .unparsable:
                return AnswerEvaluation(
                    judgement: .unclear,
                    normalizedInput: normalized,
                    correctAnswerDisplay: correctDisplay
                )
            }

        case .integer(let expected):
            let normalized = JapaneseTextNormalizer.normalize(transcript)
            guard !normalized.isEmpty else {
                return AnswerEvaluation(judgement: .unclear, normalizedInput: nil, correctAnswerDisplay: correctDisplay)
            }
            guard let value = JapaneseNumberParser.parse(transcript) else {
                return AnswerEvaluation(
                    judgement: .unclear,
                    normalizedInput: normalized,
                    correctAnswerDisplay: correctDisplay
                )
            }
            return AnswerEvaluation(
                judgement: value == expected ? .correct : .incorrect,
                normalizedInput: "\(value)",
                correctAnswerDisplay: correctDisplay
            )

        case .text(let canonical, let accepted, let locale):
            return evaluateTextSpeech(
                question: question,
                transcript: transcript,
                confidence: confidence,
                canonical: canonical,
                accepted: accepted,
                locale: locale,
                correctDisplay: correctDisplay
            )

        case .trace:
            // なぞり書きに音声回答はない。
            return AnswerEvaluation(judgement: .unclear, normalizedInput: nil, correctAnswerDisplay: correctDisplay)
        }
    }

    private func evaluateTextSpeech(
        question: Question,
        transcript: String,
        confidence: Double,
        canonical: String,
        accepted: [String],
        locale: RecognitionLocale,
        correctDisplay: String
    ) -> AnswerEvaluation {
        let candidates = ([canonical] + accepted).filter { !$0.isEmpty }
        let normalized: String
        let strength: FuzzyMatcher.MatchStrength
        switch locale {
        case .japanese:
            normalized = JapaneseTextNormalizer.normalize(transcript)
            strength = FuzzyMatcher.matchJapanese(input: transcript, candidates: candidates)
        case .englishUS:
            normalized = EnglishTextNormalizer.normalize(transcript)
            strength = FuzzyMatcher.matchEnglish(input: transcript, candidates: candidates)
        }

        guard !normalized.isEmpty else {
            return AnswerEvaluation(judgement: .unclear, normalizedInput: nil, correctAnswerDisplay: correctDisplay)
        }
        if strength != .none {
            return AnswerEvaluation(
                judgement: .correct,
                normalizedInput: normalized,
                correctAnswerDisplay: correctDisplay
            )
        }

        // 誤答の選択肢に当たっていれば「聞き取れた上での不正解」。
        let distractors = question.choices.filter { !$0.isCorrect }.map(\.spokenText)
        let distractorStrength: FuzzyMatcher.MatchStrength
        switch locale {
        case .japanese:
            distractorStrength = FuzzyMatcher.matchJapanese(input: transcript, candidates: distractors)
        case .englishUS:
            distractorStrength = FuzzyMatcher.matchEnglish(input: transcript, candidates: distractors)
        }
        if distractorStrength != .none {
            return AnswerEvaluation(
                judgement: .incorrect,
                normalizedInput: normalized,
                correctAnswerDisplay: correctDisplay
            )
        }

        // それ以外は、信頼度が低ければ「聞き取れなかった」として学習成績に響かせない。
        let judgement: AnswerJudgement = confidence < SpeechAnswerPolicy.lowConfidenceThreshold
            ? .unclear
            : .incorrect
        return AnswerEvaluation(
            judgement: judgement,
            normalizedInput: normalized,
            correctAnswerDisplay: correctDisplay
        )
    }

    // MARK: - ヘルパー

    static func judgeInteger(_ value: Int, against answer: ExpectedAnswer) -> AnswerJudgement {
        switch answer {
        case .integer(let expected):
            return value == expected ? .correct : .incorrect
        case .time, .text, .trace:
            return .incorrect
        }
    }

    /// 子どもに見せる「こたえ」の文字列。
    public static func correctAnswerDisplay(for question: Question) -> String {
        switch question.answer {
        case .time(let time, _):
            return time.displayJapanese
        case .integer(let value):
            return "\(value)"
        case .text(let canonical, _, _):
            // 画面に出ている表記に合わせる。
            switch question.content {
            case let .kanaCard(card, _):
                return question.subject == .katakana ? card.katakana : card.hiragana
            case let .kanaWord(card, subject):
                return card.character(for: subject)
            case let .alphabetCard(card, _, isUppercase):
                return card.character(isUppercase: isUppercase)
            case let .englishWord(card, _):
                return card.english
            default:
                return canonical
            }
        case .trace:
            return question.choices.first?.label ?? ""
        }
    }
}
