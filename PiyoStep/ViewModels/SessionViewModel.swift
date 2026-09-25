import Foundation
import Observation
import PiyoCore

/// 学習セッション（今日のチャレンジ / 教科ごとの練習）の画面ロジック。
///
/// 3〜6歳が相手なので、「答え方を切り替える」操作を置かない。
/// - タップで答える手段（選ぶ／針を動かす／なぞる）は問題ごとに 1 つに決める。
/// - 声で答えられる問題は、問いかけを読み終えたら **自動で** 聞き取りを始める。
///   マイクのボタンを押させない。押すのは、聞き取りが止まったあとにもう一度聞いてほしいときだけ。
/// - 音は必ず順番に鳴らす（効果音 → 読み上げ → 聞き取り）。重ねると幼児には何も伝わらない。
@MainActor
@Observable
final class SessionViewModel {

    enum Stage: Equatable {
        case asking
        case feedback
        case finished
    }

    /// 声が拾えないまま聞き直す回数。これを超えたらタップに切り替える。
    static let silentListenLimit = 3

    private let environment: AppEnvironment
    private let engine: LearningSessionEngine

    let kind: SessionKind
    let subject: Subject?
    let questions: [Question]

    private(set) var stage: Stage = .asking
    private(set) var feedback: SessionFeedback?
    private(set) var summary: SessionSummary?
    private(set) var currentIndex: Int = 0

    /// タップで答える手段。数字入力は幼児には扱えないので選ばない。
    private(set) var tapMode: AnswerMode = .choice
    /// この問題は「こえで こたえる」が本来の答え方か。
    private(set) var isVoiceFirst = false
    /// 声が拾えず、タップに切り替えたか。
    private(set) var hasFallenBackToTap = false

    /// 時計の針の現在位置
    var draggedTime: ClockTime = ClockTime(hour: 12, minute: 0)
    /// なぞり書き
    var traceStrokes: [[TracePoint]] = []
    /// 数えるときのタップ印
    var countedIndices: Set<Int> = []

    var showsHint: Bool = false
    var showsConfetti: Bool = false
    var selectedChoiceID: UUID?

    /// 正解（または答えを見せたあと）に自動で次へ進むまでの秒数。nil なら進まない。
    /// UI テストでは「つぎへ」を押す導線を確かめるため nil にする。
    var autoAdvanceDelay: TimeInterval?

    // 音声
    let voiceCoordinator = VoiceAnswerCoordinator()
    private(set) var voiceState: VoiceAnswerState = .idle
    private(set) var voiceLevel: Double = 0
    private(set) var voiceTranscript: String = ""
    private var levelTimer: Timer?
    /// 声が拾えないまま聞き直した回数（問題ごと）
    private(set) var silentListenCycles = 0
    /// 権限拒否などで声が使えないと分かったら、このセッション中は聞き取りをしない。
    private var isVoiceUnavailableThisSession = false
    /// 古い読み上げ完了・古い聞き取り結果を無視するための番号
    private var promptToken = 0
    private var listenToken = 0
    private var relistenWork: DispatchWorkItem?
    private var autoAdvanceWork: DispatchWorkItem?

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
        self.autoAdvanceDelay = environment.launchArguments.isUITest ? nil : 1.4
    }

    // MARK: - 進行

    var currentQuestion: Question? {
        engine.currentQuestion
    }

    var progressCount: Int { currentIndex }
    var totalCount: Int { questions.count }

    var visibleChoices: [AnswerChoice] {
        guard let question = currentQuestion else { return [] }
        return showsHint ? question.narrowedChoices(to: 2) : question.choices
    }

    func start() {
        environment.adPresenter.isLearningSessionActive = true
        _ = engine.start()
        prepareForCurrentQuestion()
    }

    func close() {
        cancelScheduledWork()
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
        cancelScheduledWork()
        stopVoice()
        showsConfetti = false
        let phase = engine.advance()
        currentIndex = engine.currentIndex
        if case let .completed(result) = phase {
            finish(with: result)
        } else {
            prepareForCurrentQuestion()
        }
    }

    func retryCurrentQuestion() {
        cancelScheduledWork()
        stopVoice()
        _ = engine.retry()
        showsHint = true
        selectedChoiceID = nil
        traceStrokes = []
        countedIndices = []
        stage = .asking
        feedback = nil
        // 聞き直しの回数は問題ごとに数える。再挑戦でもう一度聞いてあげる。
        silentListenCycles = 0
        speakPromptThenListen(includeHint: true)
    }

    /// 問いかけを読み上げ、読み終わったら（声が使えるなら）聞き取りを始める。
    /// 画面の「もういちど きく」からも呼ぶ。
    func speakPrompt(includeHint: Bool = false) {
        speakPromptThenListen(includeHint: includeHint)
    }

    /// 選択肢や文字を読み上げる（子どもが文字を読めなくても分かるように）。
    func speak(choice: AnswerChoice) {
        guard let question = currentQuestion else { return }
        environment.speak(choice.spokenText, locale: question.answer.locale)
    }

    /// いま読み上げるべき問いかけ。タップに切り替えたあとは、そのための言い方にする
    /// （「なんて よむ？」→「「あ」は どれ かな？」）。
    var spokenPrompt: String {
        guard let question = currentQuestion else { return "" }
        return hasFallenBackToTap ? question.prompt.spokenTextForTap : question.prompt.spokenText
    }

    private func speakPromptThenListen(includeHint: Bool) {
        guard let question = currentQuestion else { return }
        stopVoice()
        var text = spokenPrompt
        if includeHint, let hint = question.prompt.hintText {
            text += " " + hint
        }
        promptToken += 1
        let token = promptToken
        let locale: RecognitionLocale = question.answer.locale == .englishUS ? .englishUS : .japanese
        environment.speak(text, locale: locale) { [weak self] in
            guard let self, token == self.promptToken else { return }
            self.startVoiceIfAppropriate(playsStartSound: true)
        }
    }

    private func prepareForCurrentQuestion() {
        currentIndex = engine.currentIndex
        stage = .asking
        feedback = nil
        showsHint = false
        selectedChoiceID = nil
        traceStrokes = []
        countedIndices = []
        voiceCoordinator.reset()
        voiceState = .idle
        voiceTranscript = ""
        silentListenCycles = 0
        hasFallenBackToTap = false

        if let question = currentQuestion {
            tapMode = question.tapMode ?? .choice
            isVoiceFirst = question.isVoiceFirst
            if case let .clockSet(_, start, _) = question.content {
                draggedTime = start
            } else {
                draggedTime = ClockTime(hour: 12, minute: 0)
            }
            // 声がまったく使えない問題（なぞり書きなど）や、声が使えない端末では
            // はじめからタップで答える形にしておく。
            if isVoiceFirst && !isVoiceUsable {
                hasFallenBackToTap = true
            }
        }
        speakPromptThenListen(includeHint: false)
    }

    private func finish(with result: SessionSummary) {
        cancelScheduledWork()
        summary = result
        stage = .finished
        environment.adPresenter.isLearningSessionActive = false
        environment.process(summary: result)
        environment.play(.star)
    }

    private func cancelScheduledWork() {
        relistenWork?.cancel()
        relistenWork = nil
        autoAdvanceWork?.cancel()
        autoAdvanceWork = nil
        promptToken += 1
    }

    // MARK: - 回答

    func select(choice: AnswerChoice) {
        selectedChoiceID = choice.id
        environment.haptics.tap()
        submit(.choice(id: choice.id))
    }

    func submitDraggedTime() {
        submit(.time(draggedTime))
    }

    func submitTrace() {
        guard let question = currentQuestion else { return }
        submit(.trace(coverage: traceEvaluation(for: question).score))
    }

    /// 線を引き終えるたびに呼ぶ。十分になぞれていれば「できた！」を押さなくても進む。
    /// 幼児は「なぞり終えた」ことに自分で気づきにくい。
    @discardableResult
    func autoSubmitTraceIfComplete() -> Bool {
        guard stage == .asking, tapMode == .trace, let question = currentQuestion else { return false }
        guard case let .trace(required) = question.answer else { return false }
        guard traceEvaluation(for: question).score >= required else { return false }
        submitTrace()
        return true
    }

    private func traceEvaluation(for question: Question) -> TraceEvaluation {
        let text = AnswerGrader.correctAnswerDisplay(for: question)
        let mask = GlyphMaskRenderer.mask(for: text)
        return TraceEvaluator.evaluate(mask: mask, strokes: traceStrokes, brushRadius: 0.075)
    }

    func skip() {
        submit(.skipped)
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
        cancelScheduledWork()
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
        // 効果音が鳴り終わってから話す。読み終えたら、押さなくても次へ進む。
        environment.speakAfterSound(result.message) { [weak self] in
            self?.scheduleAutoAdvanceIfNeeded()
        }
    }

    private func scheduleAutoAdvanceIfNeeded() {
        guard stage == .feedback, let feedback, !feedback.canRetry, let delay = autoAdvanceDelay else { return }
        autoAdvanceWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.stage == .feedback else { return }
            self.advance()
        }
        autoAdvanceWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    // MARK: - 音声

    /// この問題で声が使えるか（問題が対応し、設定が ON で、端末で認識でき、拒否されていない）。
    var isVoiceUsable: Bool {
        guard let question = currentQuestion, !isVoiceUnavailableThisSession else { return false }
        return question.supportsVoice && environment.canUseVoice(for: question.answer.locale)
    }

    /// タップで答える UI を出すか。
    /// 「こえで こたえる」問題は、声が使えるあいだは選択肢を隠す（見せると答えが分かってしまう）。
    var showsTapInput: Bool {
        !(isVoiceFirst && isVoiceUsable && !hasFallenBackToTap)
    }

    /// 聞き取りの様子（きいているよ など）を出すか。
    var showsVoiceStatus: Bool {
        isVoiceUsable && stage == .asking
    }

    var isListening: Bool {
        voiceState.isListening
    }

    /// 聞き取りが止まっていて、マイクを押せばもう一度聞いてもらえる状態か。
    var canRestartVoice: Bool {
        isVoiceUsable && stage == .asking && !isListening && voiceState != .requestingPermission
    }

    var shouldSuggestTapAnswer: Bool {
        voiceCoordinator.shouldSuggestTapAnswer
    }

    /// 画面に出す短い案内。読めない子のために、絵（キャラクターと波形）と一緒に出す。
    var voiceGuidanceText: String {
        switch voiceState {
        case .listening:
            return isVoiceFirst ? "はなしてね" : "こえで いっても いいよ"
        case .processing:
            return "きいているよ…"
        case .requestingPermission:
            return voiceCoordinator.guidanceText
        case .finished(let judgement):
            return judgement == .unclear ? voiceCoordinator.retryMessage() : voiceCoordinator.guidanceText
        case .unavailable:
            return "タップで こたえてね"
        case .idle:
            return "マイクを おすと きいてくれるよ"
        }
    }

    /// マイクのボタン。止まっていた聞き取りをもう一度始める。
    func startVoice() {
        startVoice(playsStartSound: true)
    }

    /// 「タップで こたえる」ボタン。声をやめて選択肢に切り替える（戻さない）。
    func chooseTapAnswer() {
        environment.haptics.tap()
        fallBackToTap(announce: true)
    }

    private func startVoiceIfAppropriate(playsStartSound: Bool) {
        guard isVoiceUsable, stage == .asking, !isListening else { return }
        startVoice(playsStartSound: playsStartSound)
    }

    private func startVoice(playsStartSound: Bool) {
        guard let question = currentQuestion, stage == .asking, isVoiceUsable else { return }
        environment.stopSpeaking()

        let locale = question.answer.locale
        let recognizer = environment.speechRecognizer
        let state = voiceCoordinator.begin(
            authorization: recognizer.authorizationStatus,
            isAvailable: recognizer.isAvailable(for: locale)
        )
        voiceState = state

        switch state {
        case .requestingPermission:
            recognizer.requestAuthorization { [weak self] status in
                Task { @MainActor in
                    guard let self, self.stage == .asking else { return }
                    self.voiceState = self.voiceCoordinator.handleAuthorization(status)
                    if self.voiceState == .listening {
                        self.beginListening(locale: locale, playsStartSound: playsStartSound)
                    } else {
                        self.handleVoiceUnavailable()
                    }
                }
            }
        case .listening:
            beginListening(locale: locale, playsStartSound: playsStartSound)
        case .unavailable:
            handleVoiceUnavailable()
        case .idle, .processing, .finished:
            break
        }
    }

    private func beginListening(locale: RecognitionLocale, playsStartSound: Bool) {
        if playsStartSound {
            environment.play(.listenStart)
        }
        voiceTranscript = ""
        voiceState = .listening
        startLevelTimer()
        listenToken += 1
        let token = listenToken

        environment.speechRecognizer.startListening(
            locale: locale,
            onResult: { [weak self] result in
                Task { @MainActor in
                    guard let self, token == self.listenToken, self.isListening else { return }
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
                    guard let self, token == self.listenToken, self.isListening else { return }
                    self.handleVoiceFailure(failure)
                }
            }
        )
    }

    private func handleFinalTranscript(_ result: SpeechRecognitionResult) {
        guard let question = currentQuestion, stage == .asking else { return }
        stopLevelTimer()
        environment.play(.listenEnd)
        voiceTranscript = result.transcript

        let evaluation = voiceCoordinator.handleFinal(
            transcript: result.transcript,
            confidence: result.confidence,
            question: question
        )
        voiceState = .finished(evaluation.judgement)

        if evaluation.judgement == .unclear {
            // 認識できなかっただけなので、学習の不正解にはしない。
            handleUnclearSpeech()
            return
        }
        submit(.speech(transcript: result.transcript, confidence: result.confidence))
    }

    private func handleVoiceFailure(_ failure: SpeechRecognitionFailure) {
        stopLevelTimer()
        switch failure {
        case .notAuthorized, .unavailable:
            voiceState = voiceCoordinator.handleFailure(failure)
            handleVoiceUnavailable()
        case .noSpeechDetected:
            // 黙っているだけ。何も言わずにもう少し聞く。
            voiceState = .idle
            silentListenCycles += 1
            if silentListenCycles < SessionViewModel.silentListenLimit {
                scheduleRelisten(playsStartSound: false)
            } else if isVoiceFirst {
                fallBackToTap(announce: true)
            }
        case .audioEngineFailed, .cancelled, .other:
            voiceState = voiceCoordinator.handleFailure(failure)
            environment.play(.listenEnd)
            handleUnclearSpeech()
        }
    }

    /// 聞こえたが分からなかった。ことばをかけて、もう一度聞く。3 回続いたらタップをすすめる。
    private func handleUnclearSpeech() {
        let message = voiceCoordinator.retryMessage()
        if voiceCoordinator.shouldSuggestTapAnswer {
            hasFallenBackToTap = true
            environment.speak(message) { [weak self] in
                guard let self, self.isVoiceFirst else { return }
                self.environment.speak(self.spokenPrompt)
            }
            return
        }
        promptToken += 1
        let token = promptToken
        environment.speak(message) { [weak self] in
            guard let self, token == self.promptToken else { return }
            self.startVoiceIfAppropriate(playsStartSound: true)
        }
    }

    private func scheduleRelisten(playsStartSound: Bool) {
        relistenWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.startVoiceIfAppropriate(playsStartSound: playsStartSound)
        }
        relistenWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
    }

    private func handleVoiceUnavailable() {
        isVoiceUnavailableThisSession = true
        stopLevelTimer()
        if case .listening = voiceState {
            voiceState = .idle
        }
        fallBackToTap(announce: isVoiceFirst)
    }

    /// タップで答える形に切り替える。「こえで こたえる」問題なら、そのための問いかけを読む。
    private func fallBackToTap(announce: Bool) {
        guard !hasFallenBackToTap else { return }
        hasFallenBackToTap = true
        stopVoice()
        guard announce, stage == .asking else { return }
        environment.speak("タップで こたえても いいよ！ " + spokenPrompt)
    }

    func stopVoice() {
        relistenWork?.cancel()
        relistenWork = nil
        stopLevelTimer()
        listenToken += 1
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
