import Foundation
import Observation
import PiyoCore

/// 学習セッション（今日のチャレンジ / 教科ごとの練習）の画面ロジック。
@MainActor
@Observable
final class SessionViewModel {

    enum Stage: Equatable {
        case asking
        case feedback
        case finished
    }

    /// 時刻入力でいま編集している欄。
    enum TimeField: Equatable {
        case hour
        case minute
    }

    private let environment: AppEnvironment
    private let engine: LearningSessionEngine

    let kind: SessionKind
    let subject: Subject?
    let questions: [Question]

    private(set) var stage: Stage = .asking
    private(set) var feedback: SessionFeedback?
    private(set) var summary: SessionSummary?
    private(set) var currentIndex: Int = 0

    /// 画面に出している回答のしかた（タップで答えるもの）。
    /// 音声は「しかた」のひとつではなく、問題を読み上げたあと いつも横で聞いている。
    /// 幼児は回答方法を切り替えられないので、切り替える UI は置かない。
    var answerMode: AnswerMode = .choice
    /// 数字入力
    var numberInput: String = ""
    /// 時刻入力
    var hourInput: String = ""
    var minuteInput: String = ""
    var activeTimeField: TimeField = .hour
    /// 時計の針の現在位置
    var draggedTime: ClockTime = ClockTime(hour: 12, minute: 0)
    /// なぞり書き
    var traceStrokes: [[TracePoint]] = []
    /// 数えるときのタップ印
    var countedIndices: Set<Int> = []

    var showsHint: Bool = false
    var showsConfetti: Bool = false
    var selectedChoiceID: UUID?

    // 音声
    let voiceCoordinator = VoiceAnswerCoordinator()
    private(set) var voiceState: VoiceAnswerState = .idle
    private(set) var voiceLevel: Double = 0
    private(set) var voiceTranscript: String = ""
    private var levelTimer: Timer?
    /// 聞き取りをやり直す予約
    private var relistenWorkItem: DispatchWorkItem?
    /// マイクが開けないなどの失敗が続いた回数。多いときはこの問題では諦める。
    private var consecutiveListenFailures = 0
    /// いまの聞き取りの番号。古い聞き取りの結果が遅れて届いても無視するため。
    private var listenToken = 0
    /// 問題ごとに 1 回だけ「聞き始めた」合図の音を出す。
    private var hasPlayedListenCue = false
    private var isClosed = false

    init(environment: AppEnvironment, kind: SessionKind, subject: Subject?, questions: [Question]) {
        self.environment = environment
        self.kind = kind
        self.subject = subject
        self.questions = questions
        self.engine = LearningSessionEngine(
            kind: kind,
            subject: subject,
            questions: questions,
            clock: environment.clock
        )
    }

    // MARK: - 進行

    var currentQuestion: Question? {
        engine.currentQuestion
    }

    var progressCount: Int { currentIndex }
    var totalCount: Int { questions.count }

    var availableModes: [AnswerMode] {
        guard let question = currentQuestion else { return [] }
        var modes = question.answerModes
        if !environment.canUseVoice(for: question.answer.locale) {
            modes.removeAll { $0 == .voice }
        }
        return modes
    }

    var visibleChoices: [AnswerChoice] {
        guard let question = currentQuestion else { return [] }
        return showsHint ? question.narrowedChoices(to: 2) : question.choices
    }

    func start() {
        environment.adPresenter.isLearningSessionActive = true
        _ = engine.start()
        prepareForCurrentQuestion(speakPrompt: true)
    }

    func close() {
        isClosed = true
        stopVoice()
        environment.adPresenter.isLearningSessionActive = false
        environment.stopSpeaking()
        if !engine.isCompleted {
            let earlySummary = engine.finishEarly()
            if !earlySummary.attempts.isEmpty {
                environment.process(summary: earlySummary)
            }
        }
    }

    func advance() {
        stopVoice()
        showsConfetti = false
        let phase = engine.advance()
        currentIndex = engine.currentIndex
        if case let .completed(result) = phase {
            finish(with: result)
        } else {
            prepareForCurrentQuestion(speakPrompt: true)
        }
    }

    func retryCurrentQuestion() {
        stopVoice()
        _ = engine.retry()
        showsHint = true
        selectedChoiceID = nil
        numberInput = ""
        hourInput = ""
        minuteInput = ""
        activeTimeField = .hour
        traceStrokes = []
        countedIndices = []
        stage = .asking
        feedback = nil
        speakPrompt(includeHint: true)
    }

    /// 問題を読み上げ、読み終えたらマイクを開く。
    /// 読み上げ中はマイクを閉じておく（自分の声を答えとして拾わないように）。
    func speakPrompt(includeHint: Bool = false) {
        guard let question = currentQuestion else { return }
        var text = question.prompt.spokenText
        if includeHint, let hint = question.prompt.hintText {
            text += " " + hint
        }
        stopVoice()
        let token = listenToken
        environment.speak(text, locale: question.answer.locale == .englishUS ? .englishUS : .japanese) { [weak self] in
            guard let self, token == self.listenToken else { return }
            self.listenIfPossible()
        }
    }

    /// 選択肢や文字を読み上げる（子どもが文字を読めなくても分かるように）。
    func speak(choice: AnswerChoice) {
        guard let question = currentQuestion else { return }
        environment.speak(choice.spokenText, locale: question.answer.locale)
    }

    private func prepareForCurrentQuestion(speakPrompt shouldSpeak: Bool) {
        currentIndex = engine.currentIndex
        stage = .asking
        feedback = nil
        showsHint = false
        selectedChoiceID = nil
        numberInput = ""
        hourInput = ""
        minuteInput = ""
        activeTimeField = .hour
        traceStrokes = []
        countedIndices = []
        voiceCoordinator.reset()
        voiceState = .idle
        voiceTranscript = ""
        consecutiveListenFailures = 0
        hasPlayedListenCue = false

        if let question = currentQuestion {
            answerMode = availableModes.first(where: { $0 != .voice })
                ?? question.answerModes.first(where: { $0 != .voice })
                ?? .choice
            if case let .clockSet(_, start, _) = question.content {
                draggedTime = start
            } else {
                draggedTime = ClockTime(hour: 12, minute: 0)
            }
        }
        if shouldSpeak {
            speakPrompt()
        }
    }

    /// 最後の問題を終えた。結果画面は出さず、ひとこと ねぎらってホームへ戻る。
    /// ★やアンロックは「きょうは おしまい」でまとめて受け取る。
    private func finish(with result: SessionSummary) {
        stopVoice()
        summary = result
        stage = .finished
        environment.adPresenter.isLearningSessionActive = false
        environment.process(summary: result)
        environment.play(.star)
        environment.speak(result.childMessage)
    }

    // MARK: - 回答

    func select(choice: AnswerChoice) {
        selectedChoiceID = choice.id
        environment.haptics.tap()
        submit(.choice(id: choice.id))
    }

    func submitNumberInput() {
        guard let value = Int(numberInput) else { return }
        submit(.integer(value))
    }

    func submitTimeInput() {
        guard let hour = Int(hourInput.isEmpty ? "0" : hourInput) else { return }
        let minute = Int(minuteInput.isEmpty ? "0" : minuteInput) ?? 0
        submit(.time(ClockTime(hour: hour, minute: minute)))
    }

    func submitDraggedTime() {
        submit(.time(draggedTime))
    }

    func submitTrace() {
        guard let question = currentQuestion else { return }
        let text = AnswerGrader.correctAnswerDisplay(for: question)
        let mask = GlyphMaskRenderer.mask(for: text)
        let evaluation = TraceEvaluator.evaluate(mask: mask, strokes: traceStrokes, brushRadius: 0.075)
        submit(.trace(coverage: evaluation.score))
    }

    func skip() {
        submit(.skipped)
    }

    func appendDigit(_ digit: Int) {
        environment.haptics.tap()
        guard let question = currentQuestion else { return }
        if question.subject == .clock {
            switch activeTimeField {
            case .hour:
                hourInput = String((hourInput + "\(digit)").suffix(2))
            case .minute:
                minuteInput = String((minuteInput + "\(digit)").suffix(2))
            }
        } else {
            numberInput = String((numberInput + "\(digit)").suffix(3))
        }
    }

    func clearInput() {
        numberInput = ""
        hourInput = ""
        minuteInput = ""
        activeTimeField = .hour
    }

    func toggleCounted(index: Int) {
        if countedIndices.contains(index) {
            countedIndices.remove(index)
        } else {
            countedIndices.insert(index)
            environment.haptics.softNudge()
        }
    }

    private func submit(_ input: AnswerInput) {
        guard currentQuestion != nil, stage == .asking else { return }
        // 答えが決まったらマイクを閉じる。遅れて届く聞き取り結果も無視する。
        stopVoice()
        let result = engine.submit(input)
        feedback = result
        stage = .feedback

        switch result.judgement {
        case .correct:
            showsConfetti = true
            environment.play(.correct)
            environment.haptics.success()
        case .incorrect:
            environment.play(.incorrect)
            environment.haptics.softNudge()
        case .unclear:
            break
        }
        environment.speak(result.message)
    }

    // MARK: - 音声

    var isVoiceAvailable: Bool {
        guard let question = currentQuestion else { return false }
        return question.answerModes.contains(.voice)
            && environment.canUseVoice(for: question.answer.locale)
    }

    /// いまマイクが開いているか（画面の「きいているよ」のしるしに使う）。
    var isListening: Bool {
        voiceState.isListening
    }

    /// 「きいているよ」のしるしを出すか。
    /// 許可が無い・端末が対応していないときは、出しても嘘になるので出さない。
    var showsListeningIndicator: Bool {
        guard isVoiceAvailable else { return false }
        if case .unavailable = voiceState { return false }
        return true
    }

    var voiceGuidanceText: String {
        voiceCoordinator.guidanceText
    }

    /// 問題を読み終えたあと、問題がまだ答え待ちなら自動でマイクを開く。
    /// マイクのボタンは無い。幼児に「押してから話す」はできないため。
    private func listenIfPossible() {
        guard !isClosed, stage == .asking, isVoiceAvailable else { return }
        startVoice()
    }

    /// マイクを開く。ふつうは読み上げの完了から自動で呼ばれる。
    func startVoice() {
        guard let question = currentQuestion, stage == .asking, !isClosed else { return }

        let locale = question.answer.locale
        let recognizer = environment.speechRecognizer
        let state = voiceCoordinator.begin(
            authorization: recognizer.authorizationStatus,
            isAvailable: recognizer.isAvailable(for: locale)
        )

        switch state {
        case .listening:
            voiceState = state
            beginListening(locale: locale)
        case .requestingPermission:
            // 許可はオンボーディングで頼む。答える場面でダイアログを割り込ませない。
            // 断られていれば、そのままタップで答えられる。
            voiceState = .unavailable(.notDetermined)
        case .idle, .processing, .finished, .unavailable:
            voiceState = state
        }
    }

    private func beginListening(locale: RecognitionLocale) {
        listenToken += 1
        let token = listenToken
        if !hasPlayedListenCue {
            hasPlayedListenCue = true
            environment.play(.listenStart)
        }
        voiceTranscript = ""
        startLevelTimer()

        environment.speechRecognizer.startListening(
            locale: locale,
            onResult: { [weak self] result in
                Task { @MainActor in
                    guard let self, token == self.listenToken else { return }
                    if result.isFinal {
                        self.handleFinalTranscript(result)
                    } else {
                        self.voiceCoordinator.handlePartial(transcript: result.transcript)
                        self.voiceTranscript = result.transcript
                    }
                }
            },
            onFailure: { [weak self] failure in
                Task { @MainActor in
                    guard let self, token == self.listenToken else { return }
                    self.stopLevelTimer()
                    self.voiceState = self.voiceCoordinator.handleFailure(failure)
                    switch failure {
                    case .notAuthorized, .unavailable:
                        // この問題では使えない。タップで答えられるので何も言わない。
                        break
                    case .noSpeechDetected:
                        // 黙っていただけ。静かに聞き直す。
                        self.scheduleRelisten(afterFailure: false)
                    case .audioEngineFailed, .cancelled, .other:
                        self.scheduleRelisten(afterFailure: true)
                    }
                }
            }
        )
    }

    private func handleFinalTranscript(_ result: SpeechRecognitionResult) {
        guard let question = currentQuestion, stage == .asking else { return }
        stopLevelTimer()
        voiceTranscript = result.transcript
        consecutiveListenFailures = 0

        let evaluation = voiceCoordinator.handleFinal(
            transcript: result.transcript,
            confidence: result.confidence,
            question: question
        )
        voiceState = .finished(evaluation.judgement)

        if evaluation.judgement == .unclear {
            // 認識できなかっただけなので、学習の不正解にはしない。
            // まわりの話し声も拾うので、いちいち言い返さず静かに聞き直す。
            scheduleRelisten(afterFailure: false)
            return
        }
        environment.play(.listenEnd)
        submit(.speech(transcript: result.transcript, confidence: result.confidence))
    }

    /// 少し間をおいてから、また聞き始める。
    private func scheduleRelisten(afterFailure: Bool) {
        if afterFailure {
            consecutiveListenFailures += 1
            // マイクが開けないのを繰り返しても仕方がないので、この問題では諦める。
            guard consecutiveListenFailures < 3 else { return }
        }
        relistenWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.listenIfPossible()
        }
        relistenWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: item)
    }

    /// マイクを閉じる。遅れて届く結果は、番号が変わるので無視される。
    func stopVoice() {
        relistenWorkItem?.cancel()
        relistenWorkItem = nil
        listenToken += 1
        stopLevelTimer()
        environment.speechRecognizer.stopListening()
        if case .listening = voiceState {
            voiceState = .idle
        }
    }

    private func startLevelTimer() {
        stopLevelTimer()
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.voiceLevel = self.environment.speechRecognizer.audioLevel
            }
        }
    }

    private func stopLevelTimer() {
        levelTimer?.invalidate()
        levelTimer = nil
        voiceLevel = 0
    }
}

extension ExpectedAnswer {
    /// 回答に使う言語。
    var locale: RecognitionLocale {
        switch self {
        case .text(_, _, let locale): return locale
        case .time, .integer, .trace: return .japanese
        }
    }
}
