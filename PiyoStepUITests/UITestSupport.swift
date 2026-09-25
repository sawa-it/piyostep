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
        let hittableDeadline = Date().addingTimeInterval(1.5)
        while !isHittable && Date() < hittableDeadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        // それでも届かないなら、入れ物をスクロールして画面内に入れる。
        scrollIntoView()
        tap()
        return true
    }

    /// スクロールの外にある要素を画面内まで運ぶ。
    /// 画面中央をなぞると時計の針やなぞり書きに触れてしまうので、左端を使う。
    @discardableResult
    func scrollIntoView(maxAttempts: Int = 4) -> Bool {
        if isHittable { return true }
        let app = XCUIApplication()

        // まずキーボードをどける。届かない原因はたいていこれ。
        if app.dismissKeyboardIfNeeded(), isHittable { return true }

        for container in app.scrollContainers {
            for _ in 0 ..< maxAttempts {
                app.scrollContent(up: true, in: container)
                if isHittable { return true }
            }
            for _ in 0 ..< maxAttempts * 2 {
                app.scrollContent(up: false, in: container)
                if isHittable { return true }
            }
        }
        return isHittable
    }

    func waitUntilExists(timeout: TimeInterval = UITest.defaultTimeout) -> Bool {
        waitForExistence(timeout: timeout)
    }

    /// SwiftUI の Form / List は行を遅延生成するので、画面の外にある行は
    /// 「ヒットできない」ではなく「存在しない」。出てくるまでスクロールする。
    @discardableResult
    func scrollUntilExists(maxAttempts: Int = 8) -> Bool {
        if waitForExistence(timeout: 2) { return true }
        let app = XCUIApplication()
        app.dismissKeyboardIfNeeded()
        for container in app.scrollContainers {
            for _ in 0 ..< maxAttempts {
                app.scrollContent(up: true, in: container)
                if exists { return true }
            }
            for _ in 0 ..< maxAttempts {
                app.scrollContent(up: false, in: container)
                if exists { return true }
            }
        }
        return exists
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

    /// スクロールできそうな入れ物を、手前にあるものから順に返す。
    ///
    /// 画面に複数の入れ物がある（保護者エリアはタブごとに持つ）ので、
    /// 1 つに決め打ちすると、見えていないほうを動かして空振りする。
    var scrollContainers: [XCUIElement] {
        var result: [XCUIElement] = []
        for query in [collectionViews, tables, scrollViews] {
            for element in query.allElementsBoundByIndex
            where element.exists && element.isHittable {
                result.append(element)
            }
        }
        result.append(self)
        return result
    }

    /// 入れ物の左端をドラッグしてスクロールする。
    /// 中央から引くと、時計の針・なぞり書き・スライダーを操作してしまう。
    func scrollContent(up: Bool, in container: XCUIElement? = nil) {
        let target = container ?? scrollContainers.first ?? self
        guard target.exists else { return }
        let from = target.coordinate(withNormalizedOffset: CGVector(dx: 0.06, dy: up ? 0.85 : 0.2))
        let to = target.coordinate(withNormalizedOffset: CGVector(dx: 0.06, dy: up ? 0.2 : 0.85))
        from.press(forDuration: 0.05, thenDragTo: to)
    }

    /// キーボードが出ていると、その下のボタンには手が届かない。
    /// 横向きではキーボードが画面の半分以上を覆うので、必ず閉じてから触る。
    @discardableResult
    func dismissKeyboardIfNeeded() -> Bool {
        guard keyboards.element.exists else { return false }
        let done = buttons[A11yID.keyboardDone]
        if done.exists && done.isHittable {
            done.tap()
            return true
        }
        return false
    }

    /// 失敗メッセージに添える画面の要約。
    /// CI ではログ本体を読めず annotation（＝アサーションの文言）しか見えないので、
    /// 何が出ていたのかを 1 行に畳んで残す。括弧付きはタップできない要素。
    ///
    /// - Parameter prefix: 見たい画面の接頭辞（"session." など）。
    ///   指定しないとアプリが付けた識別子だけに絞る。SF Symbol の名前は
    ///   自動で識別子になってしまい、枠を食い潰すので落とす。
    func screenSummary(prefix: String? = nil, limit: Int = 26) -> String {
        var hittable: [String] = []
        var hidden: [String] = []

        for element in descendants(matching: .any).allElementsBoundByIndex {
            let identifier = element.identifier
            guard !identifier.isEmpty else { continue }
            if let prefix {
                guard identifier.hasPrefix(prefix) else { continue }
            } else {
                guard UITest.isAppIdentifier(identifier) else { continue }
            }
            if element.isHittable {
                if !hittable.contains(identifier) { hittable.append(identifier) }
            } else {
                if !hidden.contains("(\(identifier))") { hidden.append("(\(identifier))") }
            }
            if hittable.count + hidden.count >= limit * 2 { break }
        }

        // 手前にあるもの（押せるもの）から並べる。後ろの画面で埋まらないように。
        let entries = Array((hittable + hidden).prefix(limit))
        return entries.isEmpty ? "識別子なし" : entries.joined(separator: " ")
    }

    /// 回答方法を切り替える。切り替えられたら true。
    @discardableResult
    func switchAnswerMode(to mode: String) -> Bool {
        let button = tappable("\(A11yID.sessionModePicker)\(mode)")
        guard button.exists else { return false }
        guard button.scrollIntoView() else { return false }
        button.tap()
        return true
    }

    /// 画面に出ている問題に、種類を問わず答える。
    /// どの教科が出ても 1 つのヘルパーで進められるようにする。
    @discardableResult
    func answerCurrentQuestion(timeout: TimeInterval = UITest.defaultTimeout) -> Bool {
        // 0) 「こえ」が既定で選ばれている問題は、タップで答えられるモードに切り替える。
        //    かずの よみかた などは answerModes の先頭が .voice なので、
        //    音声が使える端末では最初から音声パネルが出ている。
        if !element(id: "\(A11yID.sessionChoice)0").exists,
           !element(id: "\(A11yID.sessionNumberPadDigit)1").exists {
            if !switchAnswerMode(to: "choice") {
                switchAnswerMode(to: "numberPad")
            }
        }

        // 1) 時計の針を合わせる問題
        let clockSubmit = tappable(A11yID.sessionClockSubmit)
        if clockSubmit.exists && clockSubmit.scrollIntoView() {
            clockSubmit.tap()
            return true
        }

        // 2) なぞり書き
        let traceCanvas = element(id: A11yID.sessionTraceCanvas)
        if traceCanvas.exists && traceCanvas.scrollIntoView() {
            scribble(on: traceCanvas)
            let traceSubmit = tappable(A11yID.sessionTraceSubmit)
            if traceSubmit.exists && traceSubmit.scrollIntoView() {
                traceSubmit.tap()
                return true
            }
        }

        // 3) 選択肢
        let firstChoice = tappable("\(A11yID.sessionChoice)0")
        if firstChoice.waitForExistence(timeout: 2) && firstChoice.scrollIntoView() {
            firstChoice.tap()
            return true
        }

        // 4) 数字入力
        let digit = tappable("\(A11yID.sessionNumberPadDigit)1")
        if digit.exists && digit.scrollIntoView() {
            digit.tap()
            let submit = tappable(A11yID.sessionNumberPadSubmit)
            if submit.exists && submit.scrollIntoView() {
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
    /// アプリが自分で付けた識別子か。
    /// `Image(systemName:)` は SF Symbol 名がそのまま識別子になるので、それを除く。
    static let identifierPrefixes = [
        "home.", "session.", "result.", "meal.", "collection.",
        "parent.", "settings.", "onboarding.", "subject.", "ad.", "avatar"
    ]

    static func isAppIdentifier(_ identifier: String) -> Bool {
        identifierPrefixes.contains { identifier.hasPrefix($0) }
    }

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
