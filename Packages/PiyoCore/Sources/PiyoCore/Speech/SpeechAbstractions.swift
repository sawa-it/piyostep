import Foundation

/// 音声認識の権限状態。
public enum SpeechAuthorizationStatus: String, Equatable, Sendable {
    case notDetermined
    case authorized
    case denied
    case restricted
    /// 端末・OS が対応していない
    case unavailable
}

/// 音声認識の途中／最終結果。
public struct SpeechRecognitionResult: Equatable, Sendable {
    public let transcript: String
    /// 0.0 - 1.0。取得できない場合は 1.0 を入れる実装もある。
    public let confidence: Double
    public let isFinal: Bool

    public init(transcript: String, confidence: Double, isFinal: Bool) {
        self.transcript = transcript
        self.confidence = min(max(confidence, 0), 1)
        self.isFinal = isFinal
    }
}

/// 音声認識の失敗理由。
public enum SpeechRecognitionFailure: Error, Equatable, Sendable {
    case notAuthorized
    case unavailable
    case audioEngineFailed
    case noSpeechDetected
    case cancelled
    case other(String)
}

/// 音声認識の抽象。テストではモックを注入する。
public protocol SpeechRecognizing: AnyObject {
    var authorizationStatus: SpeechAuthorizationStatus { get }
    /// この端末・言語で認識が使えるか
    func isAvailable(for locale: RecognitionLocale) -> Bool
    /// マイクと音声認識の権限をまとめて要求する
    func requestAuthorization(completion: @escaping (SpeechAuthorizationStatus) -> Void)
    /// 認識を開始する
    func startListening(
        locale: RecognitionLocale,
        onResult: @escaping (SpeechRecognitionResult) -> Void,
        onFailure: @escaping (SpeechRecognitionFailure) -> Void
    )
    func stopListening()
    /// 波形表示のための入力レベル（0.0 - 1.0）
    var audioLevel: Double { get }
}

/// 読み上げの抽象。
///
/// 読み上げが終わったことを知らせる `completion` を持つ。
/// 幼児向けには「読み上げ → 聞き取り開始」「効果音 → 読み上げ」のように
/// 音を順番に鳴らす必要があり、重ねると何を言われたか分からなくなる。
public protocol SpeechSynthesizing: AnyObject {
    var isSpeaking: Bool { get }
    /// 読み上げる。前の読み上げは打ち切る。
    /// `completion` は読み上げが終わったとき・打ち切られたとき・読めなかったときに 1 回だけ呼ぶ。
    func speak(_ text: String, locale: RecognitionLocale, volume: Double, completion: (() -> Void)?)
    func stop()
}

public extension SpeechSynthesizing {
    func speak(_ text: String, locale: RecognitionLocale, volume: Double) {
        speak(text, locale: locale, volume: volume, completion: nil)
    }
}

/// 効果音の抽象。
public enum SoundEffect: String, CaseIterable, Sendable {
    case tap
    case correct
    case incorrect
    case star
    case unlock
    case listenStart
    case listenEnd
    case mealStart
    case mealFinish
}

public protocol SoundPlaying: AnyObject {
    func play(_ effect: SoundEffect, volume: Double)
}

// MARK: - テスト用の実装

/// 与えられた台本を順に返すモック。
public final class MockSpeechRecognizer: SpeechRecognizing {
    public var authorizationStatus: SpeechAuthorizationStatus
    public var available: Bool
    public var audioLevel: Double = 0.5
    /// 呼ばれるたびに先頭から消費される台本
    public var script: [SpeechRecognitionResult]
    public var failureToEmit: SpeechRecognitionFailure?
    public private(set) var startCount = 0
    public private(set) var stopCount = 0
    public private(set) var lastLocale: RecognitionLocale?

    public init(
        authorizationStatus: SpeechAuthorizationStatus = .authorized,
        available: Bool = true,
        script: [SpeechRecognitionResult] = []
    ) {
        self.authorizationStatus = authorizationStatus
        self.available = available
        self.script = script
    }

    public func isAvailable(for locale: RecognitionLocale) -> Bool { available }

    public func requestAuthorization(completion: @escaping (SpeechAuthorizationStatus) -> Void) {
        if authorizationStatus == .notDetermined {
            authorizationStatus = .authorized
        }
        completion(authorizationStatus)
    }

    public func startListening(
        locale: RecognitionLocale,
        onResult: @escaping (SpeechRecognitionResult) -> Void,
        onFailure: @escaping (SpeechRecognitionFailure) -> Void
    ) {
        startCount += 1
        lastLocale = locale
        if let failure = failureToEmit {
            onFailure(failure)
            return
        }
        guard !script.isEmpty else {
            onFailure(.noSpeechDetected)
            return
        }
        let result = script.removeFirst()
        onResult(result)
    }

    public func stopListening() {
        stopCount += 1
    }
}

/// 読み上げた内容を記録するモック。
public final class MockSpeechSynthesizer: SpeechSynthesizing {
    public private(set) var spokenTexts: [String] = []
    public private(set) var stopCount = 0
    public var isSpeaking: Bool = false

    public init() {}

    public func speak(_ text: String, locale: RecognitionLocale, volume: Double, completion: (() -> Void)?) {
        spokenTexts.append(text)
        // 実機と同じく「終わってから」呼ぶ。同期で呼ぶと呼び出し側の順序が実機と変わる。
        if let completion {
            DispatchQueue.main.async(execute: completion)
        }
    }

    public func stop() {
        stopCount += 1
        isSpeaking = false
    }
}

/// 再生要求を記録するモック。
public final class MockSoundPlayer: SoundPlaying {
    public private(set) var played: [SoundEffect] = []

    public init() {}

    public func play(_ effect: SoundEffect, volume: Double) {
        played.append(effect)
    }
}
