import Foundation

/// アプリ設定。保護者画面から変更する。
public struct AppSettings: Codable, Equatable, Sendable {
    public var difficultyMode: DifficultyMode
    /// 効果音・読み上げの音量（0.0 - 1.0）
    public var volume: Double
    /// 読み上げ（音声ガイド）を使うか
    public var voiceGuidanceEnabled: Bool
    /// 音声での回答を使うか
    public var voiceAnswerEnabled: Bool
    /// ご飯タイマーの制限時間（分）
    public var mealDurationMinutes: Int
    /// ご飯タイマーで使うキャラクター
    public var mealCharacterID: String
    /// 1 日の学習量
    public var dailyGoal: DailyGoal
    /// 有効な教科
    public var enabledSubjects: Set<Subject>
    /// 広告解除を購入済みか
    public var adsRemoved: Bool
    /// 触覚フィードバック
    public var hapticsEnabled: Bool
    /// アプリの中で使う呼び名（空なら既定の名前）。
    /// ホーム画面のアプリ名は iOS では変えられないので、変わるのはアプリの中だけ。
    public var appDisplayName: String

    public static let mealDurationPresets = [10, 15, 20, 30]
    public static let mealDurationRange = 3 ... 60

    public init(
        difficultyMode: DifficultyMode = .automatic,
        volume: Double = 0.8,
        voiceGuidanceEnabled: Bool = true,
        voiceAnswerEnabled: Bool = true,
        mealDurationMinutes: Int = 15,
        mealCharacterID: String = CharacterCatalog.defaultCharacterID,
        dailyGoal: DailyGoal = .normal,
        enabledSubjects: Set<Subject> = Set(Subject.allCases),
        adsRemoved: Bool = false,
        hapticsEnabled: Bool = true,
        appDisplayName: String = ""
    ) {
        self.difficultyMode = difficultyMode
        self.volume = min(max(volume, 0), 1)
        self.voiceGuidanceEnabled = voiceGuidanceEnabled
        self.voiceAnswerEnabled = voiceAnswerEnabled
        self.mealDurationMinutes = min(max(mealDurationMinutes, AppSettings.mealDurationRange.lowerBound),
                                       AppSettings.mealDurationRange.upperBound)
        self.mealCharacterID = CharacterCatalog.character(id: mealCharacterID) != nil
            ? mealCharacterID
            : CharacterCatalog.defaultCharacterID
        self.dailyGoal = dailyGoal
        self.enabledSubjects = enabledSubjects.isEmpty ? Set(Subject.allCases) : enabledSubjects
        self.adsRemoved = adsRemoved
        self.hapticsEnabled = hapticsEnabled
        self.appDisplayName = AppNaming.sanitize(appDisplayName)
    }

    public static let `default` = AppSettings()

    /// ご飯タイマーの制限時間（秒）。
    public var mealDuration: TimeInterval {
        TimeInterval(mealDurationMinutes * 60)
    }

    /// 不正な値を正規化した設定を返す（読み込み時に使う）。
    public func sanitized() -> AppSettings {
        AppSettings(
            difficultyMode: difficultyMode,
            volume: volume,
            voiceGuidanceEnabled: voiceGuidanceEnabled,
            voiceAnswerEnabled: voiceAnswerEnabled,
            mealDurationMinutes: mealDurationMinutes,
            mealCharacterID: mealCharacterID,
            dailyGoal: dailyGoal,
            enabledSubjects: enabledSubjects,
            adsRemoved: adsRemoved,
            hapticsEnabled: hapticsEnabled,
            appDisplayName: appDisplayName
        )
    }

    /// 広告を出してよいか（学習中・ご飯タイマー中は呼び出し側で抑止する）。
    public var canShowAds: Bool { !adsRemoved }

    // MARK: - Codable（将来のキー追加に備えてすべて省略可能にする）

    private enum CodingKeys: String, CodingKey {
        case difficultyMode, volume, voiceGuidanceEnabled, voiceAnswerEnabled
        case mealDurationMinutes, mealCharacterID, dailyGoal, enabledSubjects
        case adsRemoved, hapticsEnabled, appDisplayName
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = AppSettings.default
        self.init(
            difficultyMode: (try? container.decode(DifficultyMode.self, forKey: .difficultyMode)) ?? fallback.difficultyMode,
            volume: (try? container.decode(Double.self, forKey: .volume)) ?? fallback.volume,
            voiceGuidanceEnabled: (try? container.decode(Bool.self, forKey: .voiceGuidanceEnabled)) ?? fallback.voiceGuidanceEnabled,
            voiceAnswerEnabled: (try? container.decode(Bool.self, forKey: .voiceAnswerEnabled)) ?? fallback.voiceAnswerEnabled,
            mealDurationMinutes: (try? container.decode(Int.self, forKey: .mealDurationMinutes)) ?? fallback.mealDurationMinutes,
            mealCharacterID: (try? container.decode(String.self, forKey: .mealCharacterID)) ?? fallback.mealCharacterID,
            dailyGoal: (try? container.decode(DailyGoal.self, forKey: .dailyGoal)) ?? fallback.dailyGoal,
            enabledSubjects: (try? container.decode(Set<Subject>.self, forKey: .enabledSubjects)) ?? fallback.enabledSubjects,
            adsRemoved: (try? container.decode(Bool.self, forKey: .adsRemoved)) ?? fallback.adsRemoved,
            hapticsEnabled: (try? container.decode(Bool.self, forKey: .hapticsEnabled)) ?? fallback.hapticsEnabled,
            appDisplayName: (try? container.decode(String.self, forKey: .appDisplayName)) ?? fallback.appDisplayName
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(difficultyMode, forKey: .difficultyMode)
        try container.encode(volume, forKey: .volume)
        try container.encode(voiceGuidanceEnabled, forKey: .voiceGuidanceEnabled)
        try container.encode(voiceAnswerEnabled, forKey: .voiceAnswerEnabled)
        try container.encode(mealDurationMinutes, forKey: .mealDurationMinutes)
        try container.encode(mealCharacterID, forKey: .mealCharacterID)
        try container.encode(dailyGoal, forKey: .dailyGoal)
        try container.encode(enabledSubjects, forKey: .enabledSubjects)
        try container.encode(adsRemoved, forKey: .adsRemoved)
        try container.encode(hapticsEnabled, forKey: .hapticsEnabled)
        try container.encode(appDisplayName, forKey: .appDisplayName)
    }
}

/// 設定の保存先。
public protocol SettingsStoring: AnyObject {
    func load() -> AppSettings
    func save(_ settings: AppSettings)
    func loadProfile() -> ChildProfile?
    func saveProfile(_ profile: ChildProfile?)
    /// 子どもが最後に「きょうは おしまい」をしたとき。まだなら nil。
    func loadDayEndDate() -> Date?
    func saveDayEndDate(_ date: Date?)
}

/// キーバリューストアの最小インターフェース（UserDefaults などを包む）。
public protocol KeyValueStoring: AnyObject {
    func data(forKey key: String) -> Data?
    func set(_ data: Data?, forKey key: String)
}

/// テスト・プレビュー用のインメモリ実装。
public final class InMemoryKeyValueStore: KeyValueStoring {
    private var storage: [String: Data] = [:]

    public init() {}

    public func data(forKey key: String) -> Data? { storage[key] }

    public func set(_ data: Data?, forKey key: String) {
        if let data {
            storage[key] = data
        } else {
            storage.removeValue(forKey: key)
        }
    }
}

/// JSON にして KeyValueStoring へ保存する設定ストア。
public final class CodableSettingsStore: SettingsStoring {
    public static let settingsKey = "piyo.settings"
    public static let profileKey = "piyo.profile"
    public static let dayEndKey = "piyo.dayEnd"

    private let store: KeyValueStoring
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(store: KeyValueStoring) {
        self.store = store
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    public func load() -> AppSettings {
        guard let data = store.data(forKey: CodableSettingsStore.settingsKey),
              let settings = try? decoder.decode(AppSettings.self, from: data) else {
            return .default
        }
        return settings.sanitized()
    }

    public func save(_ settings: AppSettings) {
        guard let data = try? encoder.encode(settings.sanitized()) else { return }
        store.set(data, forKey: CodableSettingsStore.settingsKey)
    }

    public func loadProfile() -> ChildProfile? {
        guard let data = store.data(forKey: CodableSettingsStore.profileKey) else { return nil }
        return try? decoder.decode(ChildProfile.self, from: data)
    }

    public func saveProfile(_ profile: ChildProfile?) {
        guard let profile else {
            store.set(nil, forKey: CodableSettingsStore.profileKey)
            return
        }
        guard let data = try? encoder.encode(profile) else { return }
        store.set(data, forKey: CodableSettingsStore.profileKey)
    }

    public func loadDayEndDate() -> Date? {
        guard let data = store.data(forKey: CodableSettingsStore.dayEndKey) else { return nil }
        return try? decoder.decode(Date.self, from: data)
    }

    public func saveDayEndDate(_ date: Date?) {
        guard let date else {
            store.set(nil, forKey: CodableSettingsStore.dayEndKey)
            return
        }
        guard let data = try? encoder.encode(date) else { return }
        store.set(data, forKey: CodableSettingsStore.dayEndKey)
    }
}
