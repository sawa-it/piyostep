import Foundation

/// UI テストから要素を特定するための識別子をひとまとめにする。
/// アプリ本体と UI テストターゲットの両方から参照できるよう PiyoCore に置く。
public enum A11yID {
    // オンボーディング
    public static let onboardingNameField = "onboarding.nameField"
    public static let onboardingNext = "onboarding.next"
    public static let onboardingAgeOption = "onboarding.age"        // + "\(age)"
    public static let onboardingCharacter = "onboarding.character"  // + characterID
    public static let onboardingStart = "onboarding.start"
    public static let onboardingBack = "onboarding.back"
    public static let onboardingSkipName = "onboarding.skipName"
    public static let onboardingMicAllow = "onboarding.mic.allow"
    public static let onboardingMicLater = "onboarding.mic.later"

    // ホーム
    public static let home = "home.root"
    public static let homeGreeting = "home.greeting"
    public static let homeDailyChallenge = "home.dailyChallenge"
    public static let homeMealTimer = "home.mealTimer"
    public static let homeCollection = "home.collection"
    public static let homeParent = "home.parent"
    public static let homeSubject = "home.subject"                  // + subject.rawValue
    public static let homeStarCount = "home.starCount"
    public static let homeAppName = "home.appName"

    // じぶんの アイコン
    public static let avatar = "avatar"

    // 教科メニュー
    public static let subjectMenu = "subject.menu"
    public static let subjectSkill = "subject.skill"                // + skill.rawValue

    // セッション
    public static let session = "session.root"
    public static let sessionPrompt = "session.prompt"
    public static let sessionProgress = "session.progress"
    public static let sessionChoice = "session.choice"              // + index
    /// 聞き取りの様子（きいているよ／はなしてね）。声が使える問題では常に出る。
    public static let sessionVoiceStatus = "session.voiceStatus"
    /// 聞き取りが止まっているときに、もういちど聞いてもらうボタン。
    public static let sessionVoiceButton = "session.voiceButton"
    /// 「こえで こたえる」問題で、声が拾えないときに出るタップへの切り替え。
    public static let sessionTapFallback = "session.tapFallback"
    public static let sessionFeedback = "session.feedback"
    public static let sessionNext = "session.next"
    public static let sessionRetry = "session.retry"
    public static let sessionClose = "session.close"
    public static let sessionClockSubmit = "session.clock.submit"
    public static let sessionClockHourHand = "session.clock.hourHand"
    public static let sessionClockMinuteHand = "session.clock.minuteHand"
    public static let sessionClockFace = "session.clock.face"
    public static let sessionTraceCanvas = "session.trace.canvas"
    public static let sessionTraceSubmit = "session.trace.submit"
    public static let sessionTraceClear = "session.trace.clear"
    /// 「やめる？」の確認。文字が読めなくても分かるよう、絵つきの大きな 2 択にする。
    public static let sessionQuitDialog = "session.quit"
    public static let sessionQuitConfirm = "session.quit.confirm"
    public static let sessionQuitCancel = "session.quit.cancel"

    // 結果
    public static let result = "result.root"
    public static let resultStars = "result.stars"
    public static let resultDone = "result.done"

    // ご飯タイマー
    public static let mealSetup = "meal.setup"
    public static let mealStart = "meal.start"
    public static let mealRace = "meal.race"
    public static let mealBite = "meal.bite"
    public static let mealFinish = "meal.finish"
    public static let mealClose = "meal.close"
    public static let mealResult = "meal.result"
    public static let mealResultDone = "meal.result.done"
    public static let mealCharacterProgress = "meal.characterProgress"
    public static let mealChildProgress = "meal.childProgress"

    // コレクション
    public static let collection = "collection.root"
    public static let collectionItem = "collection.item"            // + item.id

    // 保護者
    public static let parentGate = "parent.gate"
    public static let parentGateQuestion = "parent.gate.question"
    public static let parentGateDigit = "parent.gate.digit"         // + digit
    public static let parentGateSubmit = "parent.gate.submit"
    public static let parentGateCancel = "parent.gate.cancel"
    public static let parentTabs = "parent.tabs"
    public static let parentDashboard = "parent.dashboard"
    public static let parentSettings = "parent.settings"
    public static let parentPurchase = "parent.purchase"
    public static let parentClose = "parent.close"

    // 設定
    public static let settingsChildName = "settings.childName"
    public static let settingsAge = "settings.age"
    public static let settingsDifficulty = "settings.difficulty"
    public static let settingsVolume = "settings.volume"
    public static let settingsVoiceGuidance = "settings.voiceGuidance"
    public static let settingsVoiceAnswer = "settings.voiceAnswer"
    public static let settingsMealMinutes = "settings.mealMinutes"
    public static let settingsMealCharacter = "settings.mealCharacter"  // + characterID
    public static let settingsDailyGoal = "settings.dailyGoal"
    public static let settingsSubject = "settings.subject"          // + subject.rawValue
    public static let settingsAppName = "settings.appName"
    public static let settingsAppNameSuggestion = "settings.appName.suggestion"
    public static let settingsAppNameReset = "settings.appName.reset"
    public static let settingsAvatarPick = "settings.avatar.pick"
    public static let settingsAvatarClear = "settings.avatar.clear"

    /// 文字入力中にキーボードの上へ出す「かんりょう」。
    /// 横向きではキーボードが画面の大半を覆うので、閉じる手段が要る。
    public static let keyboardDone = "keyboard.done"

    // 広告（保護者画面に入るときだけ出す）
    public static let parentAd = "ad.parent"
    public static let parentAdClose = "ad.parent.close"
}
