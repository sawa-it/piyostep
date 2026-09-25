import Foundation

/// 保護者画面に入る前の簡単なゲート。子どもが偶然突破しないようにする。
public struct ParentGateChallenge: Equatable, Sendable {
    public let leftOperand: Int
    public let rightOperand: Int
    public let isAddition: Bool

    public init(leftOperand: Int, rightOperand: Int, isAddition: Bool) {
        self.leftOperand = leftOperand
        self.rightOperand = rightOperand
        self.isAddition = isAddition
    }

    public var answer: Int {
        isAddition ? leftOperand + rightOperand : leftOperand - rightOperand
    }

    /// 「7 + 5 は？」のように表示する。
    public var questionText: String {
        "\(leftOperand) \(isAddition ? "+" : "−") \(rightOperand) は？"
    }

    public func isCorrect(_ input: Int) -> Bool {
        input == answer
    }
}

public enum ParentGate {
    /// 大人には簡単で、未就学児には難しい範囲の計算をつくる。
    public static func makeChallenge(random: RandomSource) -> ParentGateChallenge {
        let isAddition = random.nextInt(upperBound: 2) == 0
        if isAddition {
            // 繰り上がりのある 2 桁の足し算
            let left = random.nextInt(in: 11 ... 29)
            let right = random.nextInt(in: 12 ... 29)
            return ParentGateChallenge(leftOperand: left, rightOperand: right, isAddition: true)
        }
        // 繰り下がりのある引き算
        let left = random.nextInt(in: 21 ... 49)
        let right = random.nextInt(in: 6 ... 19)
        return ParentGateChallenge(leftOperand: left, rightOperand: right, isAddition: false)
    }

    public static let instructionText = "おうちのかたへ：計算して数字を入力してください"
}
