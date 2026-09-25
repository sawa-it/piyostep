import Foundation

/// 画面の形のおおまかな区分。
///
/// 端末の種類ではなく「いまアプリに与えられている幅と高さ」で決める。
/// iPad の Split View では iPad でも細くなるため、端末名では判断できない。
///
/// このアプリは iPhone・iPad とも **横向き** で使う前提なので、
/// ふだん出てくるのは `.compactWide`（iPhone 横）と `.wide`（iPad 横）の 2 つ。
/// 縦の 2 つは、分割表示や将来の縦解禁のための保険。
public enum ScreenShape: String, Equatable, Sendable, CaseIterable {
    /// iPhone の縦持ち。
    case compact
    /// iPhone の横持ち。幅はあるが高さが足りない。
    case compactWide
    /// iPad の縦持ち、または iPad の分割表示。
    case regular
    /// iPad の横持ち。
    case wide

    /// 横に広いか（出題と回答を左右に並べられるか）。
    public var isLandscape: Bool {
        self == .compactWide || self == .wide
    }
}

/// 画面の形から決まる寸法。View はこれを見て組み替える。
public struct LayoutMetrics: Equatable, Sendable {
    public let shape: ScreenShape
    /// 文字と小物の倍率。
    public let scale: Double
    /// 時計やイラストなど「大きな絵」の倍率。
    /// 横向きは高さが足りないので、文字より強く縮める。
    public let artScale: Double
    /// 本文を並べる最大幅。
    public let contentMaxWidth: Double
    /// ホームの教科グリッドの列数。
    public let subjectColumns: Int
    /// バッジ画面の列数。
    public let collectionColumns: Int
    /// 出題と回答を左右に並べるか。
    public let usesSideBySideAnswer: Bool
    /// 余白。
    public let spacing: Double
    /// 幼児がタップしやすい最小サイズ。画面が狭くても縮めない。
    public let minimumTapSize: Double

    public init(
        shape: ScreenShape,
        scale: Double,
        artScale: Double,
        contentMaxWidth: Double,
        subjectColumns: Int,
        collectionColumns: Int,
        usesSideBySideAnswer: Bool,
        spacing: Double,
        minimumTapSize: Double
    ) {
        self.shape = shape
        self.scale = scale
        self.artScale = artScale
        self.contentMaxWidth = contentMaxWidth
        self.subjectColumns = subjectColumns
        self.collectionColumns = collectionColumns
        self.usesSideBySideAnswer = usesSideBySideAnswer
        self.spacing = spacing
        self.minimumTapSize = minimumTapSize
    }

    /// 倍率をかけた大きさ。絵やボタンの寸法に使う。
    public func sized(_ base: Double) -> Double {
        (base * scale).rounded()
    }

    /// 倍率をかけた文字の大きさ。小さくなりすぎないように下限を置く。
    public func fontSize(_ base: Double) -> Double {
        max(11, (base * scale).rounded())
    }

    /// 大きな絵の大きさ。
    public func artSized(_ base: Double) -> Double {
        (base * artScale).rounded()
    }

    /// 横向きの iPhone を基準にした既定値（プレビューやテストの出発点）。
    public static let `default` = LayoutCalculator.metrics(width: 852, height: 393)
}

/// 幅と高さから寸法を決める。View から切り離してテストできるようにしてある。
public enum LayoutCalculator {

    /// 短いほうの辺がこれ未満なら iPhone とみなす。
    /// iPhone は最大でも 440pt 程度、iPad は最小でも 740pt 程度なので、
    /// この 1 本で端末名を見ずに分けられる。
    public static let smallDeviceLimit: Double = 500

    /// 出題と回答を左右に並べるのに要る幅。
    public static let sideBySideMinimumWidth: Double = 660

    public static func metrics(width: Double, height: Double) -> LayoutMetrics {
        let safeWidth = max(width, 1)
        let safeHeight = max(height, 1)
        let shape = self.shape(width: safeWidth, height: safeHeight)

        let scale: Double
        switch shape {
        case .compact:
            scale = 1.0
        case .compactWide:
            // 高さが 390pt ほどしかないので、大きくせずむしろ少し詰める。
            scale = 0.95
        case .regular:
            scale = 1.20
        case .wide:
            // iPad の横持ち。高さが足りないときは上げすぎない。
            scale = safeHeight < 700 ? 1.15 : 1.30
        }

        // 大きな絵は、横向きでは高さに収めるほうを優先して強めに縮める。
        let artScale: Double
        switch shape {
        case .compact:
            artScale = 1.0
        case .compactWide:
            artScale = 0.72
        case .regular:
            artScale = 1.20
        case .wide:
            artScale = isShortForArt(safeHeight) ? 1.05 : 1.25
        }

        let contentMaxWidth: Double
        switch shape {
        case .compact: contentMaxWidth = 640
        case .compactWide: contentMaxWidth = 920
        case .regular: contentMaxWidth = 780
        case .wide: contentMaxWidth = 1180
        }

        let subjectColumns: Int
        switch shape {
        case .compact: subjectColumns = 2
        case .compactWide: subjectColumns = 3
        case .regular: subjectColumns = 3
        case .wide: subjectColumns = 3
        }

        let collectionColumns: Int
        switch shape {
        case .compact: collectionColumns = 3
        case .compactWide: collectionColumns = 5
        case .regular: collectionColumns = 4
        case .wide: collectionColumns = 5
        }

        // 横向きは縦に余裕が無いので、出題と回答を左右に分ける。
        let usesSideBySideAnswer = shape.isLandscape && safeWidth >= sideBySideMinimumWidth

        return LayoutMetrics(
            shape: shape,
            scale: scale,
            artScale: artScale,
            contentMaxWidth: contentMaxWidth,
            subjectColumns: subjectColumns,
            collectionColumns: collectionColumns,
            usesSideBySideAnswer: usesSideBySideAnswer,
            spacing: (20 * scale).rounded(),
            // 倍率が 1 未満でも、指の大きさは変わらないので縮めない。
            minimumTapSize: max(88, (88 * scale).rounded())
        )
    }

    /// 大きな絵を縮めたほうがよい高さか。
    static func isShortForArt(_ height: Double) -> Bool { height < 760 }

    public static func shape(width: Double, height: Double) -> ScreenShape {
        let isSmallDevice = min(width, height) < smallDeviceLimit
        let isLandscape = width > height
        switch (isSmallDevice, isLandscape) {
        case (true, true): return .compactWide
        case (true, false): return .compact
        case (false, true): return .wide
        case (false, false): return .regular
        }
    }
}
