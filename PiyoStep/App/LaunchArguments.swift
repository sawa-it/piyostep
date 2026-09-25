import Foundation

/// UI テストから挙動を固定するための起動引数。
struct LaunchArguments {
    let isUITest: Bool
    /// 永続化をメモリ上だけにする
    let useInMemoryStore: Bool
    /// オンボーディングを飛ばすために自動作成するプロフィール名
    let seededProfileName: String?
    let seededProfileAge: Int
    /// プロフィール未作成状態から始める
    let forceFreshInstall: Bool
    /// 問題生成の乱数シード
    let randomSeed: UInt64?
    /// モック音声認識が返す文字列
    let voiceScript: [String]
    /// 広告を出さない
    let disableAds: Bool
    /// アニメーションを短縮する
    let reduceAnimations: Bool
    /// ご飯タイマーの時間（秒）を短くしてテストしやすくする
    let mealDurationSeconds: Int?

    static func parse(_ arguments: [String] = ProcessInfo.processInfo.arguments) -> LaunchArguments {
        func flag(_ name: String) -> Bool {
            value(name) == "1" || arguments.contains(name)
        }
        func value(_ name: String) -> String? {
            guard let index = arguments.firstIndex(of: name), index + 1 < arguments.count else { return nil }
            let next = arguments[index + 1]
            return next.hasPrefix("-") ? nil : next
        }

        let isUITest = flag("-uiTestMode")
        return LaunchArguments(
            isUITest: isUITest,
            useInMemoryStore: isUITest,
            seededProfileName: value("-uiTestProfile"),
            seededProfileAge: Int(value("-uiTestProfileAge") ?? "5") ?? 5,
            forceFreshInstall: flag("-uiTestFreshInstall"),
            randomSeed: value("-uiTestSeed").flatMap { UInt64($0) },
            voiceScript: value("-uiTestVoiceScript").map { [$0] } ?? [],
            disableAds: isUITest || flag("-uiTestNoAds"),
            reduceAnimations: isUITest,
            mealDurationSeconds: Int(value("-uiTestMealSeconds") ?? "")
        )
    }

    static let none = LaunchArguments(
        isUITest: false,
        useInMemoryStore: false,
        seededProfileName: nil,
        seededProfileAge: 5,
        forceFreshInstall: false,
        randomSeed: nil,
        voiceScript: [],
        disableAds: false,
        reduceAnimations: false,
        mealDurationSeconds: nil
    )
}
