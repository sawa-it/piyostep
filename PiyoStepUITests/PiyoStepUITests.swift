import XCTest
import PiyoCore

final class PiyoStepUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: - 起動・プロフィール

    func testLaunchShowsHomeForExistingProfile() {
        let app = UITest.launch()
        XCTAssertTrue(app.element(id: A11yID.home).waitUntilExists())
        XCTAssertTrue(app.tappable(A11yID.homeDailyChallenge).waitUntilExists())
        XCTAssertTrue(app.tappable(A11yID.homeMealTimer).exists)
    }

    func testOnboardingCreatesAChildProfile() {
        let app = UITest.launch(freshInstall: true)

        let nameField = app.textFields[A11yID.onboardingNameField]
        XCTAssertTrue(nameField.waitUntilExists())
        nameField.tap()
        nameField.typeText("ゆい")

        // 横向きではキーボードが画面の半分以上を覆う。閉じないと「つぎへ」に届かない。
        app.dismissKeyboardIfNeeded()
        app.tappable(A11yID.onboardingNext).waitAndTap()
        app.tappable("\(A11yID.onboardingAgeOption)5").waitAndTap()
        app.tappable(A11yID.onboardingNext).waitAndTap()
        app.tappable("\(A11yID.onboardingCharacter)kuma").waitAndTap()
        app.tappable(A11yID.onboardingStart).waitAndTap()

        // マイクの許可はここで聞く。答えようとした瞬間に割り込まないため。
        app.tappable(A11yID.onboardingMicAllow).waitAndTap()

        XCTAssertTrue(app.element(id: A11yID.home).waitUntilExists())
        XCTAssertTrue(app.element(id: A11yID.homeGreeting).waitUntilExists())
    }

    func testOnboardingCanSkipTheNameAndGoBack() {
        let app = UITest.launch(freshInstall: true)

        // キーボードを使わずに進める
        app.tappable(A11yID.onboardingSkipName).waitAndTap()
        app.tappable("\(A11yID.onboardingAgeOption)5").waitAndTap()

        // 押し間違えても戻れる
        app.tappable(A11yID.onboardingBack).waitAndTap()
        XCTAssertTrue(
            app.textFields[A11yID.onboardingNameField].waitUntilExists(),
            "名前のステップに戻れない / \(app.screenSummary(prefix: "onboarding."))"
        )

        app.tappable(A11yID.onboardingSkipName).waitAndTap()
        app.tappable("\(A11yID.onboardingAgeOption)4").waitAndTap()
        app.tappable(A11yID.onboardingNext).waitAndTap()
        app.tappable(A11yID.onboardingStart).waitAndTap()
        app.tappable(A11yID.onboardingMicLater).waitAndTap()

        XCTAssertTrue(app.element(id: A11yID.home).waitUntilExists())
        // 名前を入れなくても呼びかけてもらえる
        XCTAssertTrue(app.element(id: A11yID.homeGreeting).waitUntilExists())
    }

    // MARK: - 今日のチャレンジ

    func testDailyChallengeRunsToTheEndAndReturnsHome() {
        let app = UITest.launch()
        app.tappable(A11yID.homeDailyChallenge).waitAndTap()

        XCTAssertTrue(app.element(id: A11yID.session).waitUntilExists())
        XCTAssertTrue(app.element(id: A11yID.sessionPrompt).waitUntilExists())

        // どの教科が出ても答えられるようにしてある。
        // 最後の問題を終えると、結果画面を挟まずにホームへ戻る。
        var guardCount = 0
        var stuck = 0
        while app.element(id: A11yID.session).exists && guardCount < 60 {
            guardCount += 1
            if app.answerCurrentQuestion(timeout: 3) {
                stuck = 0
                app.continueAfterFeedback(timeout: 6)
            } else {
                stuck += 1
                // 何度やっても答えられないなら、粘らずに失敗させる
                if stuck >= 5 { break }
                RunLoop.current.run(until: Date().addingTimeInterval(0.3))
            }
        }

        let deadline = Date().addingTimeInterval(UITest.defaultTimeout)
        while app.element(id: A11yID.session).exists, Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        XCTAssertFalse(
            app.element(id: A11yID.session).exists,
            "チャレンジを終えてもホームに戻らない / \(app.screenSummary())"
        )
        XCTAssertTrue(app.tappable(A11yID.homeDayEnd).waitUntilExists(), "ホームに「きょうは おしまい」が無い")
    }

    // MARK: - きょうは おしまい

    func testDayEndShowsTodaysStarsAndReturnsHome() {
        let app = UITest.launch()

        // 1 問だけ解いて★を手に入れておく
        app.tappable("\(A11yID.homeSubject)number").waitAndTap()
        app.tappable("\(A11yID.subjectSkill)numberCount").waitAndTap()
        XCTAssertTrue(app.element(id: A11yID.session).waitUntilExists())
        XCTAssertTrue(app.answerCurrentQuestion(), "1 問目に答えられない")
        XCTAssertTrue(app.element(id: A11yID.sessionFeedback).waitUntilExists())
        app.tappable(A11yID.sessionClose).waitAndTap()
        app.buttons["ホームに もどる"].waitAndTap()
        XCTAssertTrue(app.element(id: A11yID.home).waitUntilExists())

        // ★は毎回ではなく、ここでまとめて受け取る
        app.tappable(A11yID.homeDayEnd).waitAndTap()
        XCTAssertTrue(
            app.element(id: A11yID.dayEnd).waitUntilExists(),
            "おしまいの画面が出ない / \(app.screenSummary(prefix: "dayEnd."))"
        )
        XCTAssertTrue(app.element(id: A11yID.dayEndStars).waitUntilExists())

        app.tappable(A11yID.dayEndDone).waitAndTap()
        XCTAssertTrue(app.element(id: A11yID.home).waitUntilExists())
        XCTAssertFalse(app.element(id: A11yID.dayEnd).exists)
    }

    func testAnsweringMovesToTheNextQuestion() {
        let app = UITest.launch()
        app.tappable(A11yID.homeDailyChallenge).waitAndTap()
        XCTAssertTrue(app.element(id: A11yID.session).waitUntilExists())

        XCTAssertTrue(app.answerCurrentQuestion(), "1 問目に答えられない")
        XCTAssertTrue(
            app.element(id: A11yID.sessionFeedback).waitUntilExists(),
            "フィードバックが出ない"
        )
        XCTAssertTrue(app.continueAfterFeedback(), "次に進めない")
    }

    // MARK: - 画面の向きと組み替え

    func testAppRunsInLandscape() {
        let app = UITest.launch()
        XCTAssertTrue(app.element(id: A11yID.home).waitUntilExists())

        // 横向き固定なので、縦に回しても横のままであること。
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .landscapeLeft }

        let frame = app.frame
        XCTAssertGreaterThan(
            frame.width, frame.height,
            "横向きで動いていない（\(frame.width) x \(frame.height)）"
        )
    }

    func testQuestionAndAnswerSitSideBySideInLandscape() {
        let app = UITest.launch()
        app.tappable("\(A11yID.homeSubject)clock").waitAndTap()
        app.tappable("\(A11yID.subjectSkill)clockRead").waitAndTap()
        XCTAssertTrue(app.element(id: A11yID.session).waitUntilExists())

        let prompt = app.element(id: A11yID.sessionPrompt)
        let firstChoice = app.element(id: "\(A11yID.sessionChoice)0")
        XCTAssertTrue(prompt.waitUntilExists())
        XCTAssertTrue(
            firstChoice.waitUntilExists(),
            "選択肢が出ない / \(app.screenSummary(prefix: "session."))"
        )

        // 横向きでは出題が左、回答が右。縦に積むと回答が画面の外に出る。
        XCTAssertLessThan(
            prompt.frame.midX, firstChoice.frame.midX,
            "出題と回答が左右に分かれていない"
        )
        XCTAssertTrue(
            firstChoice.isHittable,
            "回答が画面内に収まっていない / \(app.screenSummary(prefix: "session."))"
        )
    }

    // MARK: - 教科ごとのゲーム

    func testClockGameLetsYouMoveTheHands() {
        let app = UITest.launch()
        app.tappable("\(A11yID.homeSubject)clock").waitAndTap()
        XCTAssertTrue(app.element(id: A11yID.subjectMenu).waitUntilExists())

        app.tappable("\(A11yID.subjectSkill)clockSet").waitAndTap()
        XCTAssertTrue(app.element(id: A11yID.session).waitUntilExists())

        let clockFace = app.element(id: A11yID.sessionClockFace)
        XCTAssertTrue(clockFace.waitUntilExists())

        // 長針を 6 の位置までドラッグする
        let center = clockFace.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let bottom = clockFace.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95))
        center.press(forDuration: 0.05, thenDragTo: bottom)

        app.tappable(A11yID.sessionClockSubmit).waitAndTap()
        XCTAssertTrue(app.element(id: A11yID.sessionFeedback).waitUntilExists())
    }

    func testClockReadingGameHasNoModeSwitching() {
        let app = UITest.launch()
        app.tappable("\(A11yID.homeSubject)clock").waitAndTap()
        app.tappable("\(A11yID.subjectSkill)clockRead").waitAndTap()
        XCTAssertTrue(app.element(id: A11yID.session).waitUntilExists())

        // 回答のしかたを切り替える UI は無い。タップで答えるものが 1 つだけ出る。
        XCTAssertTrue(
            app.tappable("\(A11yID.sessionChoice)0").waitUntilExists(),
            "選択肢が出ない / \(app.screenSummary(prefix: "session."))"
        )
        XCTAssertFalse(app.element(id: "\(A11yID.sessionNumberPadDigit)3").exists)
        XCTAssertFalse(app.element(id: "session.modePicker.choice").exists, "切り替えボタンが残っている")
        XCTAssertFalse(app.element(id: "session.voiceButton").exists, "マイクのボタンが残っている")

        app.tappable("\(A11yID.sessionChoice)0").waitAndTap()
        XCTAssertTrue(app.element(id: A11yID.sessionFeedback).waitUntilExists())
    }

    func testNumberGame() {
        let app = UITest.launch()
        app.tappable("\(A11yID.homeSubject)number").waitAndTap()
        app.tappable("\(A11yID.subjectSkill)numberCount").waitAndTap()
        XCTAssertTrue(app.element(id: A11yID.session).waitUntilExists())

        app.tappable("\(A11yID.sessionChoice)0").waitAndTap()
        XCTAssertTrue(app.element(id: A11yID.sessionFeedback).waitUntilExists())
    }

    func testHiraganaGame() {
        let app = UITest.launch()
        app.tappable("\(A11yID.homeSubject)hiragana").waitAndTap()
        app.tappable("\(A11yID.subjectSkill)hiraganaRead").waitAndTap()
        XCTAssertTrue(app.element(id: A11yID.session).waitUntilExists())

        app.tappable("\(A11yID.sessionChoice)0").waitAndTap()
        XCTAssertTrue(app.element(id: A11yID.sessionFeedback).waitUntilExists())
    }

    func testHiraganaTracing() {
        let app = UITest.launch()
        app.tappable("\(A11yID.homeSubject)hiragana").waitAndTap()
        app.tappable("\(A11yID.subjectSkill)hiraganaWrite").waitAndTap()
        XCTAssertTrue(app.element(id: A11yID.session).waitUntilExists())

        let canvas = app.element(id: A11yID.sessionTraceCanvas)
        XCTAssertTrue(canvas.waitUntilExists())
        app.scribble(on: canvas)
        app.tappable(A11yID.sessionTraceSubmit).waitAndTap()
        XCTAssertTrue(app.element(id: A11yID.sessionFeedback).waitUntilExists())
    }

    // MARK: - 音声回答（押すものは無い）

    func testVoiceAnswerIsHeardWithoutPressingAnything() {
        let app = UITest.launch(voiceScript: "さん")
        app.tappable("\(A11yID.homeSubject)number").waitAndTap()
        app.tappable("\(A11yID.subjectSkill)numberCount").waitAndTap()
        XCTAssertTrue(app.element(id: A11yID.session).waitUntilExists())

        // マイクのボタンも「こえ」への切り替えも無く、聞いているしるしだけが出る
        XCTAssertTrue(
            app.element(id: A11yID.sessionVoiceStatus).waitUntilExists(),
            "聞き取り中のしるしが出ない / \(app.screenSummary(prefix: "session."))"
        )

        // 何も押さなくても、モック認識が結果を返すとフィードバックに進む
        XCTAssertTrue(
            app.element(id: A11yID.sessionFeedback).waitForExistence(timeout: UITest.defaultTimeout),
            "音声回答が判定されない / \(app.screenSummary(prefix: "session."))"
        )
    }

    // MARK: - ご飯タイマー

    func testMealTimerRaceAndFinish() {
        let app = UITest.launch(mealSeconds: 60)
        app.tappable(A11yID.homeMealTimer).waitAndTap()

        XCTAssertTrue(app.element(id: A11yID.mealSetup).waitUntilExists())
        app.tappable(A11yID.mealStart).waitAndTap()

        let race = app.element(id: A11yID.mealRace)
        XCTAssertTrue(race.waitForExistence(timeout: UITest.defaultTimeout), "競争画面が出ない")

        // 「もぐもぐ」を何回か押してから完食する
        let bite = app.tappable(A11yID.mealBite)
        if bite.waitForExistence(timeout: 4) {
            bite.tap()
            bite.tap()
        }

        app.tappable(A11yID.mealFinish).waitAndTap()

        XCTAssertTrue(app.element(id: A11yID.mealResult).waitUntilExists(), "結果が出ない")
        app.tappable(A11yID.mealResultDone).waitAndTap()
        XCTAssertTrue(app.element(id: A11yID.home).waitUntilExists())
    }

    // MARK: - ずかん

    func testCollectionShowsLockedAndUnlockedItems() {
        let app = UITest.launch()
        app.tappable(A11yID.homeCollection).waitAndTap()
        XCTAssertTrue(app.element(id: A11yID.collection).waitUntilExists())
        XCTAssertTrue(app.element(id: "\(A11yID.collectionItem)char.piyo").waitUntilExists())
    }

    // MARK: - 保護者エリア

    func testParentGateAndDashboard() {
        let app = UITest.launch()
        app.tappable(A11yID.homeParent).waitAndTap()

        XCTAssertTrue(app.element(id: A11yID.parentGate).waitUntilExists())
        app.solveParentGate()

        XCTAssertTrue(
            app.element(id: A11yID.parentTabs).waitForExistence(timeout: UITest.defaultTimeout)
                || app.staticTexts["おうちのかた"].waitForExistence(timeout: 3),
            "保護者エリアに入れない"
        )
        XCTAssertTrue(app.staticTexts["学習した日"].waitForExistence(timeout: UITest.defaultTimeout))
    }

    func testParentGateBlocksWrongAnswers() {
        let app = UITest.launch()
        app.tappable(A11yID.homeParent).waitAndTap()
        XCTAssertTrue(app.element(id: A11yID.parentGate).waitUntilExists())

        app.tappable("\(A11yID.parentGateDigit)0").waitAndTap()
        app.tappable(A11yID.parentGateSubmit).waitAndTap()

        XCTAssertTrue(app.element(id: A11yID.parentGate).exists, "誤答では通過できない")
        XCTAssertFalse(app.staticTexts["学習した日"].exists)
    }

    func testRenamingTheAppShowsUpOnHome() {
        let app = UITest.launch(profileName: "たろう")

        // 変える前は既定の名前
        let appName = app.staticTexts[A11yID.homeAppName]
        XCTAssertTrue(appName.waitUntilExists(), "アプリの名前が出ていない")
        XCTAssertEqual(appName.label, AppNaming.defaultName)

        app.tappable(A11yID.homeParent).waitAndTap()
        app.solveParentGate()
        app.tappable("設定").waitAndTap()

        // 子どもの名前から作った候補をそのまま使う
        let suggestion = app.tappable(A11yID.settingsAppNameSuggestion)
        XCTAssertTrue(
            suggestion.scrollUntilExists(),
            "名前の候補が出ない / \(app.screenSummary(prefix: "settings."))"
        )
        suggestion.waitAndTap()

        app.tappable(A11yID.parentClose).waitAndTap()
        XCTAssertTrue(app.element(id: A11yID.home).waitUntilExists())

        let renamed = app.staticTexts[A11yID.homeAppName]
        XCTAssertTrue(renamed.waitUntilExists())
        XCTAssertEqual(renamed.label, "たろうの アプリ", "ホームの名前が変わらない")
    }

    func testChangingASettingIsApplied() {
        let app = UITest.launch()
        app.tappable(A11yID.homeParent).waitAndTap()
        app.solveParentGate()

        app.tappable("設定").waitAndTap()

        let voiceAnswerToggle = app.switches[A11yID.settingsVoiceAnswer]
        XCTAssertTrue(
            voiceAnswerToggle.scrollUntilExists(),
            "設定にトグルが出ない / \(app.screenSummary(prefix: "settings."))"
        )
        XCTAssertTrue(
            voiceAnswerToggle.scrollIntoView(),
            "トグルが画面外のまま / \(app.screenSummary(prefix: "settings."))"
        )
        let before = voiceAnswerToggle.value as? String

        // Form の Toggle は行全体がひとつの要素になるので、中央ではなくスイッチ側（右端）を押す。
        voiceAnswerToggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()

        // 値の反映はアニメーションを挟むので、変わるまで少し待つ。
        let deadline = Date().addingTimeInterval(5)
        while (voiceAnswerToggle.value as? String) == before, Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        XCTAssertNotEqual(
            before,
            voiceAnswerToggle.value as? String,
            "設定が切り替わらない / \(app.screenSummary())"
        )

        // 設定した内容で子ども画面に戻れること
        app.tappable(A11yID.parentClose).waitAndTap()
        XCTAssertTrue(app.element(id: A11yID.home).waitUntilExists())
    }

    func testAdsAreNotShownDuringLearning() {
        // UI テストでは広告を無効にしている。学習中に広告枠が出ないことを確認する。
        let app = UITest.launch()
        app.tappable(A11yID.homeDailyChallenge).waitAndTap()
        XCTAssertTrue(app.element(id: A11yID.session).waitUntilExists())
        XCTAssertFalse(app.element(id: A11yID.parentAd).exists)
    }
}
