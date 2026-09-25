import Foundation

/// 音声回答 UI の状態。
public enum VoiceAnswerState: Equatable, Sendable {
    case idle
    case requestingPermission
    /// 「はなしてね」
    case listening
    case processing
    case finished(AnswerJudgement)
    /// 使えないので、タップ回答で続ける
    case unavailable(SpeechAuthorizationStatus)

    public var isListening: Bool { self == .listening }
}

/// 音声回答の進行を司る純粋なステートマシン。
/// OS への依存はすべて呼び出し側（ViewModel）が担当する。
public final class VoiceAnswerCoordinator {
    private let grader: AnswerGrader

    public private(set) var state: VoiceAnswerState = .idle
    /// 連続して聞き取れなかった回数
    public private(set) var consecutiveUnclearCount: Int = 0
    /// 直近の認識テキスト（画面に薄く出す）
    public private(set) var lastTranscript: String = ""

    public init(grader: AnswerGrader = AnswerGrader()) {
        self.grader = grader
    }

    /// タップ回答をすすめるべきか。
    public var shouldSuggestTapAnswer: Bool {
        consecutiveUnclearCount >= SpeechAnswerPolicy.unclearStreakBeforeFallback
    }

    /// 聞き取りを始めるときに遷移する状態を返す。
    /// マイクのボタンは無く、問題を読み上げたあとに自動で呼ばれる。
    public func begin(
        authorization: SpeechAuthorizationStatus,
        isAvailable: Bool
    ) -> VoiceAnswerState {
        guard isAvailable else {
            state = .unavailable(.unavailable)
            return state
        }
        switch authorization {
        case .authorized:
            state = .listening
        case .notDetermined:
            state = .requestingPermission
        case .denied, .restricted, .unavailable:
            state = .unavailable(authorization)
        }
        return state
    }

    /// 権限要求の結果を反映する。
    public func handleAuthorization(_ status: SpeechAuthorizationStatus) -> VoiceAnswerState {
        switch status {
        case .authorized:
            state = .listening
        case .notDetermined, .denied, .restricted, .unavailable:
            state = .unavailable(status)
        }
        return state
    }

    /// 認識の途中結果。
    public func handlePartial(transcript: String) {
        lastTranscript = transcript
    }

    /// 最終結果を判定する。
    public func handleFinal(
        transcript: String,
        confidence: Double,
        question: Question
    ) -> AnswerEvaluation {
        state = .processing
        lastTranscript = transcript
        let evaluation = grader.evaluate(
            question: question,
            input: .speech(transcript: transcript, confidence: confidence)
        )
        if evaluation.judgement == .unclear {
            consecutiveUnclearCount += 1
        } else {
            consecutiveUnclearCount = 0
        }
        state = .finished(evaluation.judgement)
        return evaluation
    }

    /// 認識に失敗した（声が拾えなかったなど）。学習上の不正解にはしない。
    public func handleFailure(_ failure: SpeechRecognitionFailure) -> VoiceAnswerState {
        switch failure {
        case .notAuthorized:
            state = .unavailable(.denied)
        case .unavailable:
            state = .unavailable(.unavailable)
        case .noSpeechDetected, .audioEngineFailed, .cancelled, .other:
            consecutiveUnclearCount += 1
            state = .finished(.unclear)
        }
        return state
    }

    /// 次の問題に進むときなどにリセットする。
    public func reset(clearUnclearStreak: Bool = true) {
        state = .idle
        lastTranscript = ""
        if clearUnclearStreak {
            consecutiveUnclearCount = 0
        }
    }

    /// 聞き取れなかったときに出すことば。ネガティブ表現は使わない。
    public func retryMessage() -> String {
        switch consecutiveUnclearCount {
        case 0, 1:
            return "もういちど いってみよう！"
        case 2:
            return "おおきな こえで いってみよう！"
        default:
            return "タップで こたえても いいよ！"
        }
    }

    /// 現在の状態に応じた案内文。
    public var guidanceText: String {
        switch state {
        case .idle:
            return "こえでも こたえられるよ"
        case .requestingPermission:
            return "マイクを つかっても いい？"
        case .listening:
            return "きいているよ"
        case .processing:
            return "きいているよ…"
        case .finished(let judgement):
            switch judgement {
            case .correct: return "せいかい！"
            case .incorrect: return "おしい！ もういっかい！"
            case .unclear: return retryMessage()
            }
        case .unavailable:
            return "タップで こたえてね"
        }
    }
}
