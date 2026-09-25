import XCTest
@testable import PiyoCore

/// 実際の端末の大きさで、意図した形になることを固定する。
/// このアプリは iPhone・iPad とも横向きで使う。
final class LayoutMetricsTests: XCTestCase {

    // 実機のポイント数（横向き）
    private let iPhoneSE = (width: 667.0, height: 375.0)
    private let iPhone16 = (width: 852.0, height: 393.0)
    private let iPhone16ProMax = (width: 932.0, height: 430.0)
    private let iPadMini = (width: 1133.0, height: 744.0)
    private let iPad11 = (width: 1180.0, height: 820.0)
    private let iPadPro13 = (width: 1366.0, height: 1024.0)

    func testPhonesInLandscapeAreCompactWideEvenWhenTheyAreWiderThanAnIPadIsTall() {
        for size in [iPhoneSE, iPhone16, iPhone16ProMax] {
            let metrics = LayoutCalculator.metrics(width: size.width, height: size.height)
            XCTAssertEqual(metrics.shape, .compactWide, "\(size) が iPhone 横向きとして扱われない")
        }
    }

    func testPadsInLandscapeAreWide() {
        for size in [iPadMini, iPad11, iPadPro13] {
            let metrics = LayoutCalculator.metrics(width: size.width, height: size.height)
            XCTAssertEqual(metrics.shape, .wide, "\(size) が iPad 横向きとして扱われない")
        }
    }

    func testPortraitShapesAreStillRecognised() {
        XCTAssertEqual(LayoutCalculator.shape(width: 393, height: 852), .compact)
        XCTAssertEqual(LayoutCalculator.shape(width: 820, height: 1180), .regular)
    }

    func testIPadSplitViewIsTreatedAsRegularNotAsAPhone() {
        // iPad の 1/2 分割（およそ 507pt 幅）。iPhone 扱いにしてはいけない。
        XCTAssertEqual(LayoutCalculator.shape(width: 507, height: 1024), .regular)
    }

    func testIPadSlideOverIsTreatedAsAPhone() {
        // Slide Over は 320pt 幅。iPhone と同じ組み方でよい。
        XCTAssertEqual(LayoutCalculator.shape(width: 320, height: 1024), .compact)
    }

    // MARK: - 左右分割

    func testLandscapeSplitsTheQuestionAndTheAnswer() {
        for size in [iPhone16, iPadPro13, iPadMini] {
            let metrics = LayoutCalculator.metrics(width: size.width, height: size.height)
            XCTAssertTrue(metrics.usesSideBySideAnswer, "\(size) で左右に分かれない")
        }
    }

    func testPortraitStacksTheQuestionAboveTheAnswer() {
        let phone = LayoutCalculator.metrics(width: 393, height: 852)
        let pad = LayoutCalculator.metrics(width: 820, height: 1180)
        XCTAssertFalse(phone.usesSideBySideAnswer)
        XCTAssertFalse(pad.usesSideBySideAnswer)
    }

    func testVeryNarrowLandscapeDoesNotSplit() {
        // 分割表示で横に潰れた場合。左右に分けると両方とも読めなくなる。
        let metrics = LayoutCalculator.metrics(width: 600, height: 400)
        XCTAssertFalse(metrics.usesSideBySideAnswer)
    }

    // MARK: - 大きさ

    func testPadsGetBiggerArtThanPhones() {
        let phone = LayoutCalculator.metrics(width: iPhone16.width, height: iPhone16.height)
        let pad = LayoutCalculator.metrics(width: iPad11.width, height: iPad11.height)
        XCTAssertGreaterThan(pad.scale, phone.scale)
        XCTAssertGreaterThan(pad.sized(100), phone.sized(100))
        XCTAssertGreaterThan(pad.contentMaxWidth, phone.contentMaxWidth)
    }

    func testTapTargetsNeverShrinkBelowTheChildFriendlyMinimum() {
        for shape in ScreenShape.allCases {
            let size: (Double, Double)
            switch shape {
            case .compact: size = (393, 852)
            case .compactWide: size = (667, 375)
            case .regular: size = (820, 1180)
            case .wide: size = (1366, 1024)
            }
            let metrics = LayoutCalculator.metrics(width: size.0, height: size.1)
            XCTAssertGreaterThanOrEqual(metrics.minimumTapSize, 88, "\(shape) でタップ領域が小さい")
        }
    }

    func testFontSizeHasAFloorSoTextStaysReadable() {
        let phone = LayoutCalculator.metrics(width: iPhoneSE.width, height: iPhoneSE.height)
        XCTAssertGreaterThanOrEqual(phone.fontSize(11), 11)
        XCTAssertGreaterThanOrEqual(phone.fontSize(34), 30)
    }

    func testShortPadLandscapeDoesNotScaleUpTooMuch() {
        // iPad の横持ちでも、分割などで高さが減っているときは控えめにする。
        let tall = LayoutCalculator.metrics(width: 1180, height: 820)
        let short = LayoutCalculator.metrics(width: 1180, height: 640)
        XCTAssertLessThan(short.scale, tall.scale)
    }

    func testDegenerateSizesDoNotCrashOrProduceZeroes() {
        let metrics = LayoutCalculator.metrics(width: 0, height: 0)
        XCTAssertGreaterThan(metrics.contentMaxWidth, 0)
        XCTAssertGreaterThan(metrics.minimumTapSize, 0)
        XCTAssertGreaterThan(metrics.subjectColumns, 0)
    }

    // MARK: - 大きな絵

    func testBigArtShrinksOnAPhoneInLandscapeSoItFitsTheHeight() {
        let metrics = LayoutCalculator.metrics(width: iPhone16.width, height: iPhone16.height)
        // 250pt の時計が、高さ 393pt の画面に収まる大きさになること
        XCTAssertLessThan(metrics.artSized(250), 200)
        // 文字は絵ほど縮めない
        XCTAssertGreaterThan(metrics.scale, metrics.artScale)
    }

    func testBigArtGrowsOnAPad() {
        let phone = LayoutCalculator.metrics(width: iPhone16.width, height: iPhone16.height)
        let pad = LayoutCalculator.metrics(width: iPad11.width, height: iPad11.height)
        XCTAssertGreaterThan(pad.artSized(250), phone.artSized(250))
        XCTAssertGreaterThan(pad.artSized(250), 250, "iPad では絵を大きくする")
    }

    func testBigArtIsHeldBackOnShorterPads() {
        let tall = LayoutCalculator.metrics(width: 1366, height: 1024)
        let short = LayoutCalculator.metrics(width: 1133, height: 744)
        XCTAssertLessThan(short.artScale, tall.artScale)
    }

    func testDefaultMetricsMatchAPhoneInLandscape() {
        XCTAssertEqual(LayoutMetrics.default.shape, .compactWide)
    }
}
