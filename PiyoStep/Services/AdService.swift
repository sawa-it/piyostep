import Foundation

/// 広告表示の抽象。
///
/// 方針:
/// - 表示するのは **保護者エリアの中だけ**（ペアレンタルゲートの先）
/// - 子ども向けの画面には一切出さない。学習中・ご飯タイマー中はなおさら出さない
/// - 購入で完全に無効化できる
@MainActor
protocol AdPresenting: AnyObject {
    /// 保護者エリアに広告枠を出してよいか
    func shouldPresentAd(adsRemoved: Bool) -> Bool
    /// 学習・食事中か。子ども向け画面に出さないための保険として見る
    var isLearningSessionActive: Bool { get set }
}

@MainActor
final class ParentAreaAdPresenter: AdPresenting {
    /// 強制的に無効化（UI テストなど）
    private let isDisabled: Bool

    var isLearningSessionActive: Bool = false

    init(isDisabled: Bool = false) {
        self.isDisabled = isDisabled
    }

    func shouldPresentAd(adsRemoved: Bool) -> Bool {
        guard !isDisabled else { return false }
        guard !adsRemoved else { return false }
        guard !isLearningSessionActive else { return false }
        return true
    }
}

/// テスト用。要求内容を記録する。
@MainActor
final class MockAdPresenter: AdPresenting {
    private(set) var requestCount = 0
    var allow = true
    var isLearningSessionActive: Bool = false

    init(allow: Bool = true) {
        self.allow = allow
    }

    func shouldPresentAd(adsRemoved: Bool) -> Bool {
        requestCount += 1
        guard allow, !adsRemoved, !isLearningSessionActive else { return false }
        return true
    }
}
