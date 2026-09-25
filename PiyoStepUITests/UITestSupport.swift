import XCTest
import PiyoCore

/// UI テストの共通処理。
enum UITest {
    static let defaultTimeout: TimeInterval = 12

    /// 決定的な状態でアプリを起動する。
    @discardableResult
    static func launch(
        freshInstall: Bool = false,
        profileName: String = "さくら",
        profileAge: Int = 6,
        seed: Int = 20_240_401,
        voiceScript: String? = nil,
        mealSeconds: Int? = nil
    ) -> XCUIApplication {
        let app = XCUIApplication()
        var arguments = ["-uiTestMode", "1", "-uiTestSeed", "\(seed)"]
        if freshInstall {
            arguments += ["-uiTestFreshInstall", "1"]
        } else {
            arguments += ["-uiTestProfile", profileName, "-uiTestProfileAge", "\(profileAge)"]
        }
        if let voiceScript {
            arguments += ["-uiTestVoiceScript", voiceScript]
        }
        if let mealSeconds {
            arguments += ["-uiTestMealSeconds", "\(mealSeconds)"]
        }
        app.launchArguments = arguments
        app.launch()
        return app
    }
}

extension XCUIElement {
    /// 表示されるまで待ってからタップする。
    @discardableResult
    func waitAndTap(timeout: TimeInterval = UITest.defaultTimeout, file: StaticString = #filePath, line: UInt = #line) -> Bool {
        guard waitForExistence(timeout: timeout) else {
            XCTFail("要素が見つかりません: \(self)", file: file, line: line)
            return false
        }
        // 画面外にある場合はスクロールを促すため、ヒットできるまで少し待つ。
        let hittableDeadline = Date().addingTimeInterval(3)
        while !isHittable && Date() < hittableDeadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        tap()
        return true
    }

    func waitUntilExists(timeout: TimeInterval = UITest.defaultTimeout) -> Bool {
        waitForExistence(timeout: timeout)
    }
}

extension XCUIApplication {

    /// SwiftUI のコンテナにつけた識別子は種類が一定しないので、種類を問わず探す。
    func element(id: String) -> XCUIElement {
        descendants(matching: .any).matching(identifier: id).firstMatch
    }

    /// ボタンとして見つからない場合は種類を問わず探し直す。
    func tappable(_ id: String) -> XCUIElement {
        let button = buttons[id]
        return button.exists ? button : element(id: id)
    }

    /// 画面に出ている問題に、種類を問わず答える。
    /// どの教科が出ても 1 つのヘルパーで進められるようにする。
    @discardableResult
    func answerCurrentQuestion(timeout: TimeInterval = UITest.defaultTimeout) -> Bool {
        // 1) 時計の針を合わせる問題
        let clockSubmit = tappable(A11yID.sessionClockSubmit)
        if clockSubmit.exists && clockSubmit.isHittable {
            clockSubmit.tap()
            return true
        }

        // 2) なぞり書き
        let traceCanvas = element(id: A11yID.sessionTraceCanvas)
        if traceCanvas.exists && traceCanvas.isHittable {
            scribble(on: traceCanvas)
            let traceSubmit = tappable(A11yID.sessionTraceSubmit)
            if traceSubmit.exists && traceSubmit.isHittable {
                traceSubmit.tap()
                return true
            }
        }

        // 3) 選択肢
        let firstChoice = tappable("\(A11yID.sessionChoice)0")
        if firstChoice.waitForExistence(timeout: 2) && firstChoice.isHittable {
            firstChoice.tap()
            return true
        }

        // 4) 数字入力
        let digit = tappable("\(A11yID.sessionNumberPadDigit)1")
        if digit.exists && digit.isHittable {
            digit.tap()
            let submit = tappable(A11yID.sessionNumberPadSubmit)
            if submit.exists && submit.isHittable {
                submit.tap()
                return true
            }
        }

        return false
    }

    /// なぞり書きキャンバスに線を引く。
    func scribble(on element: XCUIElement) {
        for row in stride(from: 0.15, through: 0.85, by: 0.1) {
            let start = element.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: row))
            let end = element.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: row))
            start.press(forDuration: 0.01, thenDragTo: end)
        }
    }

    /// フィードバックが出たら「つぎへ」または「もういっかい」を押して進む。
    @discardableResult
    func continueAfterFeedback(timeout: TimeInterval = UITest.defaultTimeout) -> Bool {
        let next = tappable(A11yID.sessionNext)
        if next.waitForExistence(timeout: timeout) && next.isHittable {
            next.tap()
            return true
        }
        let retry = tappable(A11yID.sessionRetry)
        if retry.exists && retry.isHittable {
            retry.tap()
            return true
        }
        return false
    }

    /// 保護者ゲートの問題を解く。
    func solveParentGate() {
        let question = element(id: A11yID.parentGateQuestion)
        guard question.waitForExistence(timeout: UITest.defaultTimeout) else {
            XCTFail("保護者ゲートが表示されません")
            return
        }
        guard let answer = UITest.solve(question: question.label) else {
            XCTFail("ゲートの問題を解釈できません: \(question.label)")
            return
        }
        for character in "\(answer)" {
            guard let digit = character.wholeNumberValue else { continue }
            tappable("\(A11yID.parentGateDigit)\(digit)").waitAndTap()
        }
        tappable(A11yID.parentGateSubmit).waitAndTap()
    }
}

extension UITest {
    /// 「23 + 15 は？」のような文字列を解く。
    static func solve(question: String) -> Int? {
        let cleaned = question.replacingOccurrences(of: "は？", with: "")
        let isSubtraction = cleaned.contains("−") || cleaned.contains("-")
        let separator: Character = isSubtraction ? (cleaned.contains("−") ? "−" : "-") : "+"
        let parts = cleaned.split(separator: separator)
        guard parts.count == 2,
              let left = Int(parts[0].trimmingCharacters(in: .whitespaces)),
              let right = Int(parts[1].trimmingCharacters(in: .whitespaces)) else {
            return nil
        }
        return isSubtraction ? left - right : left + right
    }
}
