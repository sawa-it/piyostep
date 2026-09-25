import Foundation
import AVFoundation
import AudioToolbox
import UIKit
import PiyoCore

/// AVSpeechSynthesizer による読み上げ。
final class SystemSpeechSynthesizer: NSObject, SpeechSynthesizing {
    private let synthesizer = AVSpeechSynthesizer()

    var isSpeaking: Bool { synthesizer.isSpeaking }

    override init() {
        super.init()
    }

    func speak(_ text: String, locale: RecognitionLocale, volume: Double) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        stop()
        configureSessionForPlayback()

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: locale.rawValue)
        // 幼児が聞き取りやすいよう、標準よりゆっくりにする。
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.86
        utterance.pitchMultiplier = 1.1
        utterance.volume = Float(min(max(volume, 0), 1))
        utterance.preUtteranceDelay = 0.05
        synthesizer.speak(utterance)
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    private func configureSessionForPlayback() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true, options: [])
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
