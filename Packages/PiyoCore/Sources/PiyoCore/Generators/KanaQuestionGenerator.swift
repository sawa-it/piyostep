import Foundation

/// ひらがな・カタカナの「読み」（文字と音の対応）
public struct KanaReadQuestionGenerator: QuestionGenerating {
    public let skill: Skill
    private let subject: Subject

    public init(subject: Subject) {
        self.subject = subject == .katakana ? .katakana : .hiragana
        self.skill = subject == .katakana ? .katakanaRead : .hiraganaRead
    }

    /// 声で答えられるとき、「もじを みて よむ」問題にする割合。
    /// 「おとを きいて えらぶ」だけだと、文字を見て読む練習にならない。
    public static func usesReadingAloud(level: DifficultyLevel, allowVoice: Bool, random: RandomSource) -> Bool {
        guard allowVoice else { return false }
        // Lv1 は聞いて選ぶことから。Lv2 以上は半々。
        return level.raw >= 2 && random.nextInt(upperBound: 2) == 0
    }

    public func generate(level: DifficultyLevel, random: RandomSource, allowVoice: Bool) -> Question {
        let pool = KanaCatalog.cards(for: level)
        let card = random.pick(pool) ?? KanaCatalog.teachable[0]
        let readsAloud = KanaReadQuestionGenerator.usesReadingAloud(level: level, allowVoice: allowVoice, random: random)

        let choices = ChoiceBuilder.choices(
            correct: card,
            pool: pool,
            count: 4,
            random: random,
            label: { $0.character(for: subject) },
            spokenText: { $0.hiragana },
            display: { .text($0.character(for: subject)) }
        )

        let prompt: Prompt
        if readsAloud {
            // 文字を見せて読ませる。読み上げで答えを言ってはいけない。
            prompt = Prompt(
                displayText: "なんて よむ？",
                spokenText: "この もじは なんて よむ かな？",
                hintText: "「\(card.hiraganaWord)」の さいしょの もじ だよ",
                tapFallbackSpokenText: "「\(card.hiragana)」は どれ かな？"
            )
        } else {
            prompt = Prompt(
                displayText: "どれかな？",
                spokenText: "「\(card.hiragana)」は どれ かな？",
                hintText: "「\(card.hiraganaWord)」の さいしょの もじ だよ"
            )
        }
        return Question(
            skill: skill,
            difficulty: level,
            prompt: prompt,
            content: .kanaCard(card: card, task: .read),
            answer: .text(
                canonical: card.hiragana,
                accepted: [card.hiragana, card.katakana, card.romaji, card.word(for: subject)],
                locale: .japanese
            ),
            answerModes: answerModes(readsAloud ? [.voice, .choice] : [.choice, .voice], allowVoice: allowVoice),
            choices: choices
        )
    }

    /// 音声回答時に画面へ出す文字（View が使う）。
    public static func displayedCharacter(for content: QuestionContent, subject: Subject) -> String? {
        if case let .kanaCard(card, _) = content {
            return card.character(for: subject)
        }
        return nil
    }
}

/// ひらがな・カタカナの「なぞり書き / 自由書き」
public struct KanaWriteQuestionGenerator: QuestionGenerating {
    public let skill: Skill
    private let subject: Subject

    public init(subject: Subject) {
        self.subject = subject == .katakana ? .katakana : .hiragana
        self.skill = subject == .katakana ? .katakanaWrite : .hiraganaWrite
    }

    /// Lv4 以上は お手本なしの自由書き。
    public static func task(for level: DifficultyLevel) -> CharacterTask {
        level.raw >= 4 ? .write : .trace
    }

    /// 難易度ごとに必要ななぞり達成率。
    public static func requiredCoverage(for level: DifficultyLevel) -> Double {
        switch level.raw {
        case 1: return 0.55
        case 2: return 0.62
        case 3: return 0.68
        case 4: return 0.72
        default: return 0.78
        }
    }

    public func generate(level: DifficultyLevel, random: RandomSource, allowVoice: Bool) -> Question {
        let pool = KanaCatalog.cards(for: level)
        let card = random.pick(pool) ?? KanaCatalog.teachable[0]
        let task = KanaWriteQuestionGenerator.task(for: level)
        let character = card.character(for: subject)

        let prompt = Prompt(
            displayText: task == .trace ? "なぞってみよう" : "かいてみよう",
            spokenText: task == .trace
                ? "「\(card.hiragana)」を ゆびで なぞってみよう"
                : "「\(card.hiragana)」を かいてみよう",
            hintText: "うすい もじの うえを なぞってね"
        )
        return Question(
            skill: skill,
            difficulty: level,
            prompt: prompt,
            content: .kanaCard(card: card, task: task),
            answer: .trace(requiredCoverage: KanaWriteQuestionGenerator.requiredCoverage(for: level)),
            answerModes: [.trace],
            choices: [
                AnswerChoice(
                    label: character,
                    spokenText: card.hiragana,
                    display: .text(character),
                    isCorrect: true
                )
            ]
        )
    }
}

/// 「ことばあわせ」（イラスト → はじめの もじ）
public struct KanaWordQuestionGenerator: QuestionGenerating {
    public let skill: Skill
    private let subject: Subject

    public init(subject: Subject = .hiragana) {
        self.subject = subject == .katakana ? .katakana : .hiragana
        self.skill = subject == .katakana ? .katakanaWord : .hiraganaWord
    }

    public func generate(level: DifficultyLevel, random: RandomSource, allowVoice: Bool) -> Question {
        let pool = KanaCatalog.cards(for: level).filter { $0.illustration != "particle" }
        let card = random.pick(pool) ?? KanaCatalog.teachable[0]
        let word = card.word(for: subject)

        let choices = ChoiceBuilder.choices(
            correct: card,
            pool: pool,
            count: 4,
            random: random,
            label: { $0.character(for: subject) },
            spokenText: { $0.hiragana },
            display: { .text($0.character(for: subject)) }
        )

        let prompt = Prompt(
            displayText: "はじめの もじは？",
            spokenText: "「\(word)」の はじめの もじは どれ かな？",
            hintText: "ゆっくり 「\(word)」と いってみよう"
        )
        return Question(
            skill: skill,
            difficulty: level,
            prompt: prompt,
            content: .kanaWord(card: card, subject: subject),
            answer: .text(
                canonical: card.hiragana,
                accepted: [card.hiragana, card.katakana, card.romaji, word],
                locale: .japanese
            ),
            answerModes: answerModes([.choice, .voice], allowVoice: allowVoice),
            choices: choices
        )
    }
}
