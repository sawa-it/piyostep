import Foundation
import AVFoundation
import AudioToolbox
import UIKit
import PiyoCore

/// 読み上げと聞き取りで共有するオーディオセッション。
///
/// 読み上げのたびに `.playback`、聞き取りのたびに `.playAndRecord` へ切り替えると、
/// 切り替えのたびに音が途切れ、読み上げの頭が欠ける。幼児向けアプリは
/// 「読み上げ → すぐ聞き取り」を繰り返すので、はじめから両方できる設定に固定する。
enum PiyoAudioSession {
    private static var isConfigured = false

    static func activate() {
        let session = AVAudioSession.sharedInstance()
        if !isConfigured {
            // `.measurement` はマイクの自動調整を切るので、幼児の小さな声が拾いにくくなる。
            try? session.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.defaultToSpeaker, .duckOthers, .allowBluetoothA2DP]
            )
            isConfigured = true
        }
        try? session.setActive(true, options: [])
    }
}

/// AVSpeechSynthesizer による読み上げ。
final class SystemSpeechSynthesizer: NSObject, SpeechSynthesizing, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    /// 発話ごとの完了コールバック。打ち切られても必ず 1 回呼ぶ。
    private var completions: [ObjectIdentifier: () -> Void] = [:]

    var isSpeaking: Bool { synthesizer.isSpeaking }

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String, locale: RecognitionLocale, volume: Double, completion: (() -> Void)?) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            if let completion {
                DispatchQueue.main.async(execute: completion)
            }
            return
        }
        stop()
        PiyoAudioSession.activate()

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: locale.rawValue)
        // 幼児が聞き取りやすいよう、標準よりゆっくりにする。
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.86
        utterance.pitchMultiplier = 1.1
        utterance.volume = Float(min(max(volume, 0), 1))
        utterance.preUtteranceDelay = 0.05
        if let completion {
            completions[ObjectIdentifier(utterance)] = completion
        }
        synthesizer.speak(utterance)
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    // MARK: - AVSpeechSynthesizerDelegate

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        finish(utterance)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        finish(utterance)
    }

    private func finish(_ utterance: AVSpeechUtterance) {
        guard let completion = completions.removeValue(forKey: ObjectIdentifier(utterance)) else { return }
        DispatchQueue.main.async(execute: completion)
    }
}

/// 効果音。画像・音声アセットを持たない方針のため、iOS のシステムサウンドを使う。
final class SystemSoundPlayer: SoundPlaying {
    private static let soundIDs: [SoundEffect: SystemSoundID] = [
        .tap: 1104,
        .correct: 1025,
        .incorrect: 1113,
        .star: 1057,
        .unlock: 1035,
        .listenStart: 1110,
        .listenEnd: 1111,
        .mealStart: 1113,
        .mealFinish: 1025
    ]

    init() {}

    func play(_ effect: SoundEffect, volume: Double) {
        guard volume > 0.01 else { return }
        guard let soundID = SystemSoundPlayer.soundIDs[effect] else { return }
        AudioServicesPlaySystemSound(soundID)
    }
}

/// 触覚フィードバック。UIKit の API を使うため MainActor に固定する。
@MainActor
protocol HapticFeedbackProviding: AnyObject {
    func tap()
    func success()
    func softNudge()
}

@MainActor
final class SystemHapticsService: HapticFeedbackProviding {
    private let impact = UIImpactFeedbackGenerator(style: .medium)
    private let soft = UIImpactFeedbackGenerator(style: .soft)
    private let notification = UINotificationFeedbackGenerator()

    var isEnabled: Bool = true

    init() {}

    func tap() {
        guard isEnabled else { return }
        impact.impactOccurred()
    }

    func success() {
        guard isEnabled else { return }
        notification.notificationOccurred(.success)
    }

    func softNudge() {
        guard isEnabled else { return }
        soft.impactOccurred(intensity: 0.6)
    }
}

/// テスト・プレビュー用。
@MainActor
final class NoopHapticsService: HapticFeedbackProviding {
    private(set) var tapCount = 0
    private(set) var successCount = 0

    init() {}

    func tap() { tapCount += 1 }
    func success() { successCount += 1 }
    func softNudge() {}
}
