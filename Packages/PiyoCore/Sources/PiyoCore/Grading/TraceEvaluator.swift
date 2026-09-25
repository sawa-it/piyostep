import Foundation

/// 正規化された座標（0.0 - 1.0）の点。
public struct TracePoint: Equatable, Sendable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

/// お手本の文字を格子状のマスクで表したもの。
/// アプリ側は文字をレンダリングして不透明ピクセルから生成する。
public struct GlyphMask: Equatable, Sendable {
    public let width: Int
    public let height: Int
    /// 行優先。true が「文字の上」。
    public let cells: [Bool]

    public init(width: Int, height: Int, cells: [Bool]) {
        self.width = max(0, width)
        self.height = max(0, height)
        let expected = self.width * self.height
        if cells.count == expected {
            self.cells = cells
        } else if cells.count > expected {
            self.cells = Array(cells.prefix(expected))
        } else {
            self.cells = cells + Array(repeating: false, count: expected - cells.count)
        }
    }

    public var filledCount: Int {
        cells.reduce(0) { $0 + ($1 ? 1 : 0) }
    }

    public func isFilled(x: Int, y: Int) -> Bool {
        guard x >= 0, y >= 0, x < width, y < height else { return false }
        return cells[y * width + x]
    }

    /// 単純な矩形マスク（テスト用）。
    public static func rectangle(width: Int, height: Int, rect: (x: Int, y: Int, w: Int, h: Int)) -> GlyphMask {
        var cells = [Bool](repeating: false, count: width * height)
        for y in rect.y ..< min(height, rect.y + rect.h) {
            for x in rect.x ..< min(width, rect.x + rect.w) {
                if x >= 0 && y >= 0 { cells[y * width + x] = true }
            }
        }
        return GlyphMask(width: width, height: height, cells: cells)
    }
}

/// なぞり書きの評価結果。
public struct TraceEvaluation: Equatable, Sendable {
    /// お手本のうち、なぞれた割合（0.0 - 1.0）
    public let coverage: Double
    /// 描いた線のうち、お手本の上にあった割合（0.0 - 1.0）
    public let precision: Double

    public init(coverage: Double, precision: Double) {
        self.coverage = min(max(coverage, 0), 1)
        self.precision = min(max(precision, 0), 1)
    }

    /// 判定に使う総合スコア。はみ出しには寛容にする（幼児の運筆のため）。
    public var score: Double {
        coverage * (0.75 + 0.25 * precision)
    }
}

public enum TraceEvaluator {

    /// 正規化ストロークをマスク解像度でラスタライズし、被覆率を求める。
    /// - Parameter brushRadius: 正規化座標系での筆の半径（0.0 - 1.0）。
    public static func evaluate(
        mask: GlyphMask,
        strokes: [[TracePoint]],
        brushRadius: Double = 0.06
    ) -> TraceEvaluation {
        let total = mask.filledCount
        guard total > 0, mask.width > 0, mask.height > 0 else {
            return TraceEvaluation(coverage: 0, precision: 0)
        }

        var painted = [Bool](repeating: false, count: mask.width * mask.height)
        let radiusInCells = max(1.0, brushRadius * Double(max(mask.width, mask.height)))

        for stroke in strokes {
            guard !stroke.isEmpty else { continue }
            if stroke.count == 1 {
                stamp(&painted, mask: mask, point: stroke[0], radius: radiusInCells)
                continue
            }
            for index in 0 ..< (stroke.count - 1) {
                let start = stroke[index]
                let end = stroke[index + 1]
                let dx = (end.x - start.x) * Double(mask.width)
                let dy = (end.y - start.y) * Double(mask.height)
                let distance = (dx * dx + dy * dy).squareRoot()
                let steps = max(1, Int(distance.rounded(.up)))
                for step in 0 ... steps {
                    let t = Double(step) / Double(steps)
                    let point = TracePoint(
                        x: start.x + (end.x - start.x) * t,
                        y: start.y + (end.y - start.y) * t
                    )
                    stamp(&painted, mask: mask, point: point, radius: radiusInCells)
                }
            }
        }

        var covered = 0
        var paintedCount = 0
        for index in 0 ..< painted.count where painted[index] {
            paintedCount += 1
            if mask.cells[index] { covered += 1 }
        }

        let coverage = Double(covered) / Double(total)
        let precision = paintedCount > 0 ? Double(covered) / Double(paintedCount) : 0
        return TraceEvaluation(coverage: coverage, precision: precision)
    }

    private static func stamp(
        _ painted: inout [Bool],
        mask: GlyphMask,
        point: TracePoint,
        radius: Double
    ) {
        let centerX = point.x * Double(mask.width)
        let centerY = point.y * Double(mask.height)
        let minX = max(0, Int((centerX - radius).rounded(.down)))
        let maxX = min(mask.width - 1, Int((centerX + radius).rounded(.up)))
        let minY = max(0, Int((centerY - radius).rounded(.down)))
        let maxY = min(mask.height - 1, Int((centerY + radius).rounded(.up)))
        guard minX <= maxX, minY <= maxY else { return }

        let radiusSquared = radius * radius
        for y in minY ... maxY {
            for x in minX ... maxX {
                let dx = Double(x) + 0.5 - centerX
                let dy = Double(y) + 0.5 - centerY
                if dx * dx + dy * dy <= radiusSquared {
                    painted[y * mask.width + x] = true
                }
            }
        }
    }
}

/// なぞり書きキャンバスに「うすい お手本」を出すかどうか。
///
/// - なぞり（trace）: いつも出す。
/// - かきとり（write）: ふだんは出さない。まちがえて 2 回目に入ったときだけ、ヒントとして出す。
///   ヒント文が「うすい もじの うえを なぞってね」なのに お手本が無い、という食い違いを防ぐ。
public enum TraceTemplatePolicy {
    public static func showsTemplate(for content: QuestionContent, hintShown: Bool) -> Bool {
        switch content {
        case .kanaCard(_, let task), .alphabetCard(_, let task, _):
            switch task {
            case .trace: return true
            case .write: return hintShown
            case .read: return true
            }
        case .clockRead, .clockSet, .countObjects, .numberRead, .placeValue, .kanaWord, .englishWord:
            return true
        }
    }
}
