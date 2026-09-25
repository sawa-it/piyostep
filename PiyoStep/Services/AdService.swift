import Foundation

/// 広告表示の抽象。
///
/// 方針:
/// - 表示するのは **保護者画面に入るときだけ**。子どもの画面には一切出さない
/// - 学習中・ご飯タイマー中は絶対に表示しない
/// - 閉じるボタンは十分に大きく、誤タップしにくい位置に置く
/// - 購入で完全に無効化できる
///
/// ペアレンタルゲートの向こう側でだけ出すので、広告を見るのは必ず大人になる。
/// 起動時に出すと、アプリを初めて開いた子どもが最初に見るものが広告になってしまう。
@MainActor
protocol AdPresenting: AnyObject {
    /// 保護者画面に入るときの広告を出してよいか
    func shouldPresentParentAd(adsRemoved: Bool) -> Bool
    /// 表示したことを記録する
    func markParentAdPresented()
    /// 学習・食事中は必ず false になる
    var isLearningSessionActive: Bool { get set }
}

@MainActor
final class ParentAreaAdPresenter: AdPresenting {
    /// 同じ起動で二度出さない。保護者が何度も出入りしても 1 回だけ。
    private var hasPresentedThisLaunch = false
    /// 強制的に無効化（UI テストなど）
    private let isDisabled: Bool

    var isLearningSessionActive: Bool = false

    init(isDisabled: Bool = false) {
        self.isDisabled = isDisabled
    }

    func shouldPresentParentAd(adsRemoved: Bool) -> Bool {
        guard !isDisabled else { return false }
        guard !adsRemoved else { return false }
        // 保護者画面は学習中には開けないが、念のため守っておく。
        guard !isLearningSessionActive else { return false }
        return !hasPresentedThisLaunch
    }

    func markParentAdPresented() {
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

    func shouldPresentParentAd(adsRemoved: Bool) -> Bool {
        requestCount += 1
        guard allow, !adsRemoved, !isLearningSessionActive else { return false }
        return true
    }

    func markParentAdPresented() {
        presentedCount += 1
    }
}
