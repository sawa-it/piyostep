import XCTest
@testable import PiyoCore

final class AppNamingTests: XCTestCase {

    func testFallsBackToTheDefaultNameWhenNothingIsSet() {
        let profile = ChildProfile(nickname: "たろう", age: 5)
        XCTAssertEqual(AppNaming.displayName(custom: ""), AppNaming.defaultName)
        XCTAssertEqual(AppNaming.displayName(custom: "   "), AppNaming.defaultName)
        XCTAssertEqual(AppNaming.displayName(custom: ""), AppNaming.defaultName)
    }

    func testUsesTheNameTheParentTyped() {
        let profile = ChildProfile(nickname: "たろう", age: 5)
        XCTAssertEqual(AppNaming.displayName(custom: "たろうの アプリ"), "たろうの アプリ")
        XCTAssertEqual(profile.callName, "たろう")
    }

    func testTrimsAndLimitsTheLength() {
        XCTAssertEqual(AppNaming.sanitize("  ぴよ  "), "ぴよ")
        let long = String(repeating: "あ", count: 30)
        XCTAssertEqual(AppNaming.sanitize(long).count, AppNaming.maxLength)
        // 切り詰めた名前でも表示名として使える（既定に落ちない）
        XCTAssertEqual(
            AppNaming.displayName(custom: long).count,
            AppNaming.maxLength
        )
    }

    func testSuggestsANameMadeFromTheChildsName() {
        let profile = ChildProfile(nickname: "たろう", age: 5)
        XCTAssertEqual(AppNaming.suggestion(for: profile), "たろうの アプリ")
    }

    func testSuggestionStaysWithinTheLimitForLongNames() {
        // ニックネーム自体が 8 文字まで。それでも収まるように詰める。
        let profile = ChildProfile(nickname: "あいうえおかきく", age: 6)
        guard let suggestion = AppNaming.suggestion(for: profile) else {
            return XCTFail("候補が作られない")
        }
        XCTAssertLessThanOrEqual(suggestion.count, AppNaming.maxLength)
        XCTAssertTrue(suggestion.hasPrefix("あいうえお"))
    }

    func testNoSuggestionWithoutAName() {
        XCTAssertNil(AppNaming.suggestion(for: nil))
        XCTAssertNil(AppNaming.suggestion(for: ChildProfile(nickname: "   ", age: 4)))
    }

    func testSettingsKeepTheNameAcrossSaveAndLoad() throws {
        var settings = AppSettings.default
        settings.appDisplayName = "たろうの アプリ"
        let store = CodableSettingsStore(store: InMemoryKeyValueStore())
        store.save(settings)
        XCTAssertEqual(store.load().appDisplayName, "たろうの アプリ")
    }

    func testSettingsWithoutTheNewKeyStillLoad() throws {
        // 名前の項目が無い、古い保存データ。
        let json = """
        {"difficultyMode":"automatic","volume":0.5,"voiceGuidanceEnabled":true,
         "voiceAnswerEnabled":false,"mealDurationMinutes":20,"mealCharacterID":"piyo",
         "dailyGoal":"light","enabledSubjects":["clock"],"adsRemoved":false,"hapticsEnabled":true}
        """
        let settings = try JSONDecoder().decode(AppSettings.self, from: Data(json.utf8))
        XCTAssertEqual(settings.appDisplayName, "")
        XCTAssertEqual(settings.mealDurationMinutes, 20)
        XCTAssertFalse(settings.voiceAnswerEnabled)
    }
}

final class ProfileAvatarTests: XCTestCase {

    func testDefaultsToTheBuddyCharacter() {
        let profile = ChildProfile(nickname: "たろう", age: 5, buddyCharacterID: CharacterCatalog.defaultCharacterID)
        XCTAssertEqual(profile.avatar, .character(CharacterCatalog.defaultCharacterID))
        XCTAssertNil(profile.avatar.photoFileName)
    }

    func testKeepsAPhotoAvatarAcrossSaveAndLoad() throws {
        let profile = ChildProfile(nickname: "たろう", age: 5, avatar: .photo("avatar-1.jpg"))
        let store = CodableSettingsStore(store: InMemoryKeyValueStore())
        store.saveProfile(profile)
        let loaded = store.loadProfile()
        XCTAssertEqual(loaded?.avatar, .photo("avatar-1.jpg"))
        XCTAssertEqual(loaded?.avatar.photoFileName, "avatar-1.jpg")
    }

    func testOldProfileWithoutAnAvatarStillLoads() throws {
        // アイコンの項目が無い、古い保存データ。オンボーディングに戻されないこと。
        let json = """
        {"id":"7B2C4A7E-0000-4000-8000-000000000001","nickname":"たろう","age":5,
         "buddyCharacterID":"piyo","createdAt":"2024-04-01T00:00:00Z"}
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let profile = try decoder.decode(ChildProfile.self, from: Data(json.utf8))
        XCTAssertEqual(profile.nickname, "たろう")
        XCTAssertEqual(profile.avatar, .character("piyo"))
    }

    func testBrokenAvatarFallsBackInsteadOfFailing() throws {
        let json = """
        {"nickname":"たろう","age":5,"avatar":{"kind":"hologram","value":"???"}}
        """
        let profile = try JSONDecoder().decode(ChildProfile.self, from: Data(json.utf8))
        XCTAssertEqual(profile.avatar, .default)
    }

    func testImageStoreKeepsAndRemovesData() {
        let store = InMemoryProfileImageStore()
        let data = Data([0xFF, 0xD8, 0xFF, 0xE0])
        guard let name = store.save(imageData: data) else {
            return XCTFail("保存できない")
        }
        XCTAssertEqual(store.imageData(named: name), data)
        store.delete(named: name)
        XCTAssertNil(store.imageData(named: name))
        XCTAssertEqual(store.storedCount, 0)
    }

    func testImageStoreRejectsEmptyData() {
        let store = InMemoryProfileImageStore()
        XCTAssertNil(store.save(imageData: Data()))
    }

    func testSquareCropTakesTheMiddleOfAWidePhoto() {
        let rect = AvatarImageGeometry.squareCropRect(width: 400, height: 200)
        XCTAssertEqual(rect.side, 200)
        XCTAssertEqual(rect.x, 100)
        XCTAssertEqual(rect.y, 0)
    }

    func testSquareCropTakesSlightlyAboveTheMiddleOfATallPhoto() {
        let rect = AvatarImageGeometry.squareCropRect(width: 200, height: 400)
        XCTAssertEqual(rect.side, 200)
        XCTAssertEqual(rect.x, 0)
        XCTAssertLessThan(rect.y, 100, "縦長の写真は中央より上を採る")
        XCTAssertGreaterThanOrEqual(rect.y, 0, "画像の外に出ない")
    }

    func testSquareCropStaysInsideANearlySquarePhoto() {
        let rect = AvatarImageGeometry.squareCropRect(width: 100, height: 101)
        XCTAssertGreaterThanOrEqual(rect.y, 0)
        XCTAssertLessThanOrEqual(rect.y + rect.side, 101)
    }

    func testSquareCropOfAnEmptySizeIsEmpty() {
        XCTAssertEqual(AvatarImageGeometry.squareCropRect(width: 0, height: 100), .zero)
    }
}
