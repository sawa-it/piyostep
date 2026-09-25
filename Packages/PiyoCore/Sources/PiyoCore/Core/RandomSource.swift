import Foundation

/// 乱数の供給源。テストでは決定的な実装を注入する。
public protocol RandomSource: AnyObject {
    /// `0 ..< upperBound` の整数を返す。`upperBound <= 0` のときは 0 を返す。
    func nextInt(upperBound: Int) -> Int
    /// `0.0 ..< 1.0` の実数を返す。
    func nextDouble() -> Double
}

extension RandomSource {
    /// 閉区間 `range` から 1 つ選ぶ。
    public func nextInt(in range: ClosedRange<Int>) -> Int {
        let span = range.upperBound - range.lowerBound + 1
        return range.lowerBound + nextInt(upperBound: span)
    }

    /// 閉区間の実数を返す。
    public func nextDouble(in range: ClosedRange<Double>) -> Double {
        range.lowerBound + nextDouble() * (range.upperBound - range.lowerBound)
    }

    /// 要素を 1 つ選ぶ。空配列では nil。
    public func pick<T>(_ elements: [T]) -> T? {
        guard !elements.isEmpty else { return nil }
        return elements[nextInt(upperBound: elements.count)]
    }

    /// Fisher-Yates でシャッフルした新しい配列を返す。
    public func shuffled<T>(_ elements: [T]) -> [T] {
        var result = elements
        guard result.count > 1 else { return result }
        for index in stride(from: result.count - 1, to: 0, by: -1) {
            let swapIndex = nextInt(upperBound: index + 1)
            result.swapAt(index, swapIndex)
        }
        return result
    }

    /// 重み付き抽選。重みは 0 以上。すべて 0 なら均等抽選にフォールバックする。
    public func pickWeighted<T>(_ elements: [T], weight: (T) -> Double) -> T? {
        guard !elements.isEmpty else { return nil }
        let weights = elements.map { max(0, weight($0)) }
        let total = weights.reduce(0, +)
        guard total > 0 else { return pick(elements) }
        var threshold = nextDouble() * total
        for (index, value) in weights.enumerated() {
            threshold -= value
            if threshold <= 0 { return elements[index] }
        }
        return elements[elements.count - 1]
    }
}

/// 本番用。システム乱数を使う。
public final class SystemRandomSource: RandomSource {
    public init() {}

    public func nextInt(upperBound: Int) -> Int {
        guard upperBound > 0 else { return 0 }
        return Int.random(in: 0 ..< upperBound)
    }

    public func nextDouble() -> Double {
        Double.random(in: 0 ..< 1)
    }
}

/// テスト用。SplitMix64 による決定的な擬似乱数。
public final class SeededRandomSource: RandomSource {
    private var state: UInt64

    public init(seed: UInt64) {
        // seed が 0 でも偏らないようにオフセットを足す。
        self.state = seed &+ 0x9E37_79B9_7F4A_7C15
    }

    private func next() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    public func nextInt(upperBound: Int) -> Int {
        guard upperBound > 0 else { return 0 }
        return Int(next() % UInt64(upperBound))
    }

    public func nextDouble() -> Double {
        // 上位 53bit を使って [0, 1) に写す。
        Double(next() >> 11) * (1.0 / 9_007_199_254_740_992.0)
    }
}
