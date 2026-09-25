import XCTest
@testable import PiyoCore

final class AnswerGraderTests: XCTestCase {

    private let grader = AnswerGrader()

    // MARK: - タップ回答

    func testChoiceAnswers() {
        let question = Fixture.integerQuestion(correct: 3)
        guard let correctID = Fixture.correctChoiceID(question),
              let wrongID = Fixture.wrongChoiceID(question) else {
            return XCTFail("選択肢が足りない")
        }
        XCTAssertEqual(grader.evaluate(question: question, input: .choice(id: correctID)).judgement, .correct)
        XCTAssertEqual(grader.evaluate(question: question, input: .choice(id: wrongID)).judgement, .incorrect)
        XCTAssertEqual(grader.evaluate(question: question, input: .choice(id: UUID())).judgement, .incorrect)
    }

    func testIntegerAnswers() {
        let question = Fixture.integerQuestion(correct: 7)
        XCTAssertEqual(grader.evaluate(question: question, input: .integer(7)).judgement, .correct)
        XCTAssertEqual(grader.evaluate(question: question, input: .integer(8)).judgement, .incorrect)
    }

    func testSkippedIsIncorrectButNotUnclear() {
        let question = Fixture.integerQuestion()
        XCTAssertEqual(grader.evaluate(question: question, input: .skipped).judgement, .incorrect)
    }

    // MARK: - 時計

    private func clockQuestion(
        hour: Int,
        minute: Int,
        tolerance: Int = 0,
        dragging: Bool = false
    ) -> Question {
        let time = ClockTime(hour: hour, minute: minute)
        return Question(
            skill: dragging ? .clockSet : .clockRead,
            difficulty: .level3,
            prompt: Prompt(displayText: "なんじ？", spokenText: "なんじ かな？"),
            content: dragging
                ? .clockSet(target: time, start: ClockTime(hour: 12, minute: 0), minuteStep: 5)
                : .clockRead(time: time),
            answer: .time(time, toleranceMinutes: tolerance),
            answerModes: dragging ? [.dragHands] : [.choice, .numberPad, .voice],
            choices: []
        )
    }

    func testClockTimeInput() {
        let question = clockQuestion(hour: 3, minute: 30, dragging: true)
        XCTAssertEqual(
            grader.evaluate(question: question, input: .time(ClockTime(hour: 3, minute: 30))).judgement,
            .correct
        )
        XCTAssertEqual(
            grader.evaluate(question: question, input: .time(ClockTime(hour: 3, minute: 35))).judgement,
            .incorrect
        )
    }

    func testClockToleranceIsHonoured() {
        let question = clockQuestion(hour: 3, minute: 30, tolerance: 1, dragging: true)
        XCTAssertEqual(
            grader.evaluate(question: question, input: .time(ClockTime(hour: 3, minute: 31))).judgement,
            .correct
        )
        XCTAssertEqual(
            grader.evaluate(question: question, input: .time(ClockTime(hour: 3, minute: 33))).judgement,
            .incorrect
        )
    }

    func testClockVoiceAnswers() {
        let question = clockQuestion(hour: 3, minute: 30)
        for spoken in ["さんじはん", "3じ30ぷん", "さんじさんじゅっぷん", "えっと、さんじはんです"] {
            XCTAssertEqual(
                grader.evaluate(question: question, input: .speech(transcript: spoken, confidence: 0.9)).judgement,
                .correct,
                "「\(spoken)」が正解にならない"
            )
        }
        XCTAssertEqual(
            grader.evaluate(question: question, input: .speech(transcript: "よじ", confidence: 0.9)).judgement,
            .incorrect
        )
    }

    func testClockVoiceUnrecognisedIsNotCountedAsWrong() {
        let question = clockQuestion(hour: 3, minute: 30)
        for spoken in ["", "わかんない", "うーん"] {
            XCTAssertEqual(
                grader.evaluate(question: question, input: .speech(transcript: spoken, confidence: 0.8)).judgement,
                .unclear,
                "「\(spoken)」は不正解ではなく聞き取れなかった扱いにする"
            )
        }
    }

    func testBareNumberAcceptedForWholeHours() {
        let question = clockQuestion(hour: 5, minute: 0)
        XCTAssertEqual(
            grader.evaluate(question: question, input: .speech(transcript: "ご", confidence: 0.9)).judgement,
            .correct
        )
        // ちょうどの時刻でなければ、数字だけでは判断しない
        let halfPast = clockQuestion(hour: 5, minute: 30)
        XCTAssertEqual(
            grader.evaluate(question: halfPast, input: .speech(transcript: "ご", confidence: 0.9)).judgement,
            .unclear
        )
    }

    // MARK: - 数字

    func testNumberVoiceAnswers() {
        let question = Fixture.integerQuestion(correct: 3)
        for spoken in ["さん", "3", "さんこ", "３", "えっと、さんだとおもう"] {
            XCTAssertEqual(
                grader.evaluate(question: question, input: .speech(transcript: spoken, confidence: 0.9)).judgement,
                .correct,
                "「\(spoken)」が正解にならない"
            )
        }
        XCTAssertEqual(
            grader.evaluate(question: question, input: .speech(transcript: "ご", confidence: 0.9)).judgement,
            .incorrect
        )
        XCTAssertEqual(
            grader.evaluate(question: question, input: .speech(transcript: "わかんない", confidence: 0.9)).judgement,
            .unclear
        )
    }

    // MARK: - ひらがな / カタカナ

    private func kanaQuestion(for hiragana: String, subject: Subject = .hiragana) -> Question {
        guard let card = KanaCatalog.card(forHiragana: hiragana) else {
            fatalError("テストデータが不正: \(hiragana)")
        }
        let distractors = KanaCatalog.teachable.filter { $0.hiragana != hiragana }.prefix(3)
        let choices = ([card] + distractors).map { item in
            AnswerChoice(
                label: item.character(for: subject),
                spokenText: item.hiragana,
                display: .text(item.character(for: subject)),
                isCorrect: item.hiragana == hiragana
            )
        }
        return Question(
            skill: subject == .katakana ? .katakanaRead : .hiraganaRead,
            difficulty: .level1,
            prompt: Prompt(displayText: "どれ？", spokenText: "どれ かな？"),
            content: .kanaCard(card: card, task: .read),
            answer: .text(
                canonical: card.hiragana,
                accepted: [card.hiragana, card.katakana, card.romaji, card.word(for: subject)],
                locale: .japanese
            ),
            answerModes: [.choice, .voice],
            choices: choices
        )
    }

    func testKanaVoiceAcceptsCharacterWordAndKatakana() {
        let question = kanaQuestion(for: "あ")
        for spoken in ["あ", "ア", "あひる", "アヒル", "あひるです"] {
            XCTAssertEqual(
                grader.evaluate(question: question, input: .speech(transcript: spoken, confidence: 0.9)).judgement,
                .correct,
                "「\(spoken)」が正解にならない"
            )
        }
    }

    func testKanaVoiceRejectsDifferentCharacter() {
        let question = kanaQuestion(for: "あ")
        let evaluation = grader.evaluate(
            question: question,
            input: .speech(transcript: "い", confidence: 0.95)
        )
        XCTAssertEqual(evaluation.judgement, .incorrect)
    }

    func testLowConfidenceUnknownSpeechBecomesUnclear() {
        let question = kanaQuestion(for: "あ")
        let evaluation = grader.evaluate(
            question: question,
            input: .speech(transcript: "ぶろろろ", confidence: 0.1)
        )
        XCTAssertEqual(evaluation.judgement, .unclear, "認識精度の低さを不正解にしない")
    }

    func testHighConfidenceUnknownSpeechIsIncorrect() {
        let question = kanaQuestion(for: "あ")
        let evaluation = grader.evaluate(
            question: question,
            input: .speech(transcript: "ぶろろろ", confidence: 0.95)
        )
        XCTAssertEqual(evaluation.judgement, .incorrect)
    }

    func testCorrectAnswerDisplayUsesShownScript() {
        let hiragana = kanaQuestion(for: "か", subject: .hiragana)
        XCTAssertEqual(AnswerGrader.correctAnswerDisplay(for: hiragana), "か")

        let katakanaCard = KanaCatalog.card(forHiragana: "か")!
        let katakana = Question(
            skill: .katakanaRead,
            difficulty: .level1,
            prompt: Prompt(displayText: "どれ？", spokenText: "どれ かな？"),
            content: .kanaCard(card: katakanaCard, task: .read),
            answer: .text(canonical: "か", accepted: [], locale: .japanese),
            answerModes: [.choice],
            choices: []
        )
        XCTAssertEqual(AnswerGrader.correctAnswerDisplay(for: katakana), "カ")
    }

    // MARK: - アルファベット / 英単語

    private func alphabetQuestion(for letter: String) -> Question {
        guard let card = AlphabetCatalog.card(for: letter) else {
            fatalError("テストデータが不正: \(letter)")
        }
        return Question(
            skill: .alphabetRead,
            difficulty: .level1,
            prompt: Prompt(displayText: "どれ？", spokenText: "どれ かな？"),
            content: .alphabetCard(card: card, task: .read, isUppercase: true),
            answer: .text(
                canonical: card.uppercase.lowercased(),
                accepted: card.acceptedSpokenForms,
                locale: .englishUS
            ),
            answerModes: [.choice, .voice],
            choices: [
                AnswerChoice(label: card.uppercase, spokenText: card.letterName, display: .text(card.uppercase), isCorrect: true)
            ]
        )
    }

    func testAlphabetVoiceAcceptsLetterNames() {
        let question = alphabetQuestion(for: "B")
        for spoken in ["B", "b", "bee", "Bee."] {
            XCTAssertEqual(
                grader.evaluate(question: question, input: .speech(transcript: spoken, confidence: 0.9)).judgement,
                .correct,
                "「\(spoken)」が正解にならない"
            )
        }
    }

    func testAlphabetVoiceRejectsOtherLetters() {
        let question = alphabetQuestion(for: "B")
        XCTAssertEqual(
            grader.evaluate(question: question, input: .speech(transcript: "zebra", confidence: 0.95)).judgement,
            .incorrect
        )
    }

    private func englishWordQuestion(for id: String) -> Question {
        guard let card = EnglishWordCatalog.card(for: id) else {
            fatalError("テストデータが不正: \(id)")
        }
        return Question(
            skill: .englishWordRead,
            difficulty: .level1,
            prompt: Prompt(displayText: "えいごで いってみよう", spokenText: "えいごで いってみよう"),
            content: .englishWord(card: card, task: .speakWord),
            answer: .text(canonical: card.english, accepted: card.acceptedSpellings, locale: .englishUS),
            answerModes: [.voice, .choice],
            choices: []
        )
    }

    func testEnglishWordVoiceIsForgiving() {
        let question = englishWordQuestion(for: "apple")
        for spoken in ["apple", "Apple!", "an apple", "apples", "aple"] {
            XCTAssertEqual(
                grader.evaluate(question: question, input: .speech(transcript: spoken, confidence: 0.8)).judgement,
                .correct,
                "「\(spoken)」が正解にならない"
            )
        }
    }

    func testEnglishWordVoiceRejectsDifferentWord() {
        let question = englishWordQuestion(for: "apple")
        XCTAssertEqual(
            grader.evaluate(question: question, input: .speech(transcript: "banana", confidence: 0.9)).judgement,
            .incorrect
        )
    }

    // MARK: - なぞり書き

    func testTraceAnswer() {
        let question = Question(
            skill: .hiraganaWrite,
            difficulty: .level1,
            prompt: Prompt(displayText: "なぞろう", spokenText: "なぞろう"),
            content: .kanaCard(card: KanaCatalog.teachable[0], task: .trace),
            answer: .trace(requiredCoverage: 0.6),
            answerModes: [.trace],
            choices: []
        )
        XCTAssertEqual(grader.evaluate(question: question, input: .trace(coverage: 0.75)).judgement, .correct)
        XCTAssertEqual(grader.evaluate(question: question, input: .trace(coverage: 0.6)).judgement, .correct)
        XCTAssertEqual(grader.evaluate(question: question, input: .trace(coverage: 0.3)).judgement, .incorrect)
        // なぞり書きに音声回答は使えないが、不正解にはしない
        XCTAssertEqual(
            grader.evaluate(question: question, input: .speech(transcript: "あ", confidence: 0.9)).judgement,
            .unclear
        )
    }
}
