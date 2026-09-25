import Foundation

/// 広告表示の抽象。
///
/// 方針:
/// - 表示するのは **アプリ起動時のみ**
/// - 学習中・ご飯タイマー中は絶対に表示しない
/// - 閉じるボタンは十分に大きく、誤タップしにくい位置に置く
/// - 購入で完全に無効化できる
@MainActor
protocol AdPresenting: AnyObject {
    /// 起動時広告を出してよいか
    func shouldPresentLaunchAd(adsRemoved: Bool) -> Bool
    /// 表示したことを記録する
    func markLaunchAdPresented()
    /// 学習・食事中は必ず false になる
    var isLearningSessionActive: Bool { get set }
}

@MainActor
final class LaunchAdPresenter: AdPresenting {
    /// 同じ起動で二度出さない
    private var hasPresentedThisLaunch = false
    /// 強制的に無効化（UI テストなど）
    private let isDisabled: Bool

    var isLearningSessionActive: Bool = false

    init(isDisabled: Bool = false) {
        self.isDisabled = isDisabled
    }

    func shouldPresentLaunchAd(adsRemoved: Bool) -> Bool {
        guard !isDisabled else { return false }
        guard !adsRemoved else { return false }
        guard !isLearningSessionActive else { return false }
        return !hasPresentedThisLaunch
    }

    func markLaunchAdPresented() {
        hasPresentedThisLaunch = true
    }
}

/// テスト用。要求内容を記録する。
@MainActor
final class MockAdPresenter: AdPresenting {
    private(set) var requestCount = 0
    private(set) var presentedCount = 0
    var allow = true
    var isLearningSessionActive: Bool = false

    init(allow: Bool = true) {
        self.allow = allow
    }

    func shouldPresentLaunchAd(adsRemoved: Bool) -> Bool {
        requestCount += 1
        guard allow, !adsRemoved, !isLearningSessionActive else { return false }
        return true
    }

    func markLaunchAdPresented() {
        presentedCount += 1
    }
}
