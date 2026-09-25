import XCTest
import UIKit
import PiyoCore
@testable import PiyoStep

/// アプリの呼び名と「じぶんの アイコン」。
@MainActor
final class AppNameAndAvatarTests: XCTestCase {

    private func jpegLikeData() -> Data {
        // 中身は問わない。保存・読み出しの経路だけを見る。
        Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10])
    }

    // MARK: - 呼び名

    func testHomeShowsTheDefaultNameUntilTheParentChangesIt() {
        let environment = TestEnvironment.make()
        XCTAssertEqual(environment.appDisplayName, AppNaming.defaultName)
    }

    func testChangingTheNameIsReflectedAndSaved() {
        let environment = TestEnvironment.make()
        let model = SettingsViewModel(environment: environment)

        model.draft.appDisplayName = "たろうの アプリ"
        model.apply()

        XCTAssertEqual(environment.appDisplayName, "たろうの アプリ")
        XCTAssertEqual(environment.settingsStore.load().appDisplayName, "たろうの アプリ")
    }

    func testSuggestionComesFromTheChildsName() {
        let environment = TestEnvironment.make(profile: ChildProfile(nickname: "たろう", age: 5))
        let model = SettingsViewModel(environment: environment)

        XCTAssertEqual(model.appNameSuggestion, "たろうの アプリ")
        model.useSuggestedAppName()
        XCTAssertEqual(environment.appDisplayName, "たろうの アプリ")
        // 同じ名前になったら、もう候補は出さない
        XCTAssertNil(model.appNameSuggestion)
    }

    func testResettingGoesBackToTheDefaultName() {
        let environment = TestEnvironment.make()
        let model = SettingsViewModel(environment: environment)

        model.draft.appDisplayName = "たろうの アプリ"
        model.apply()
        model.resetAppName()

        XCTAssertTrue(model.isUsingDefaultAppName)
        XCTAssertEqual(environment.appDisplayName, AppNaming.defaultName)
    }

    func testOverlyLongNamesAreTrimmedBeforeBeingSaved() {
        let environment = TestEnvironment.make()
        let model = SettingsViewModel(environment: environment)

        model.draft.appDisplayName = String(repeating: "な", count: 40)
        model.apply()

        XCTAssertEqual(environment.appDisplayName.count, AppNaming.maxLength)
    }

    // MARK: - アイコン

    func testAvatarStartsAsTheBuddyCharacter() {
        let environment = TestEnvironment.make()
        XCTAssertNil(environment.avatar.photoFileName)
        XCTAssertNil(environment.avatarImageData())
    }

    func testChoosingAPhotoStoresItAndUsesIt() {
        let store = InMemoryProfileImageStore()
        let environment = TestEnvironment.make(profileImageStore: store)
        let model = SettingsViewModel(environment: environment)

        model.useAvatarPhoto(data: jpegLikeData())

        XCTAssertTrue(model.isUsingPhotoAvatar)
        XCTAssertNil(model.avatarError)
        XCTAssertEqual(environment.avatarImageData(), jpegLikeData())
        XCTAssertEqual(store.storedCount, 1)
    }

    func testAPhotoSurvivesOtherSettingsChanges() {
        let environment = TestEnvironment.make()
        let model = SettingsViewModel(environment: environment)
        model.useAvatarPhoto(data: jpegLikeData())

        // 名前や年齢を変えてもアイコンは消えない
        model.childName = "はなこ"
        model.childAge = 6
        model.apply()

        XCTAssertTrue(model.isUsingPhotoAvatar)
        XCTAssertEqual(environment.profile?.nickname, "はなこ")
    }

    func testGoingBackToTheCharacterRemovesTheStoredPhoto() {
        let store = InMemoryProfileImageStore()
        let environment = TestEnvironment.make(profileImageStore: store)
        let model = SettingsViewModel(environment: environment)

        model.useAvatarPhoto(data: jpegLikeData())
        XCTAssertEqual(store.storedCount, 1)

        model.useCharacterAvatar()

        XCTAssertFalse(model.isUsingPhotoAvatar)
        XCTAssertNil(environment.avatarImageData())
        XCTAssertEqual(store.storedCount, 0, "使わなくなった写真は端末に残さない")
    }

    func testReplacingAPhotoKeepsOnlyTheNewOne() {
        let store = InMemoryProfileImageStore()
        let environment = TestEnvironment.make(profileImageStore: store)
        let model = SettingsViewModel(environment: environment)

        model.useAvatarPhoto(data: jpegLikeData())
        let newData = Data([0xFF, 0xD8, 0x01, 0x02])
        model.useAvatarPhoto(data: newData)

        XCTAssertEqual(store.storedCount, 1)
        XCTAssertEqual(environment.avatarImageData(), newData)
    }

    func testEmptyPhotoDataIsReportedInsteadOfBeingSaved() {
        let store = InMemoryProfileImageStore()
        let environment = TestEnvironment.make(profileImageStore: store)
        let model = SettingsViewModel(environment: environment)

        model.useAvatarPhoto(data: Data())

        XCTAssertFalse(model.isUsingPhotoAvatar)
        XCTAssertNotNil(model.avatarError)
        XCTAssertEqual(store.storedCount, 0)
    }

    func testTheAvatarIsRestoredWhenTheAppStartsAgain() {
        let store = InMemoryProfileImageStore()
        let keyValueStore = InMemoryKeyValueStore()
        let settingsStore = CodableSettingsStore(store: keyValueStore)
        settingsStore.saveProfile(ChildProfile(nickname: "たろう", age: 5))

        let first = AppEnvironment(
            settingsStore: settingsStore,
            historyStore: InMemoryLearningHistoryStore(),
            speechRecognizer: ScriptedSpeechRecognizer(transcripts: []),
            speechSynthesizer: MockSpeechSynthesizer(),
            soundPlayer: MockSoundPlayer(),
            haptics: NoopHapticsService(),
            purchaseService: MockPurchaseService(),
            adPresenter: MockAdPresenter(allow: true),
            profileImageStore: store,
            launchArguments: TestEnvironment.makeLaunchArguments()
        )
        first.bootstrap()
        XCTAssertTrue(first.updateAvatarPhoto(data: jpegLikeData()))

        // 同じ保存先から作り直す＝アプリを起動し直したのと同じ状態
        let second = AppEnvironment(
            settingsStore: CodableSettingsStore(store: keyValueStore),
            historyStore: InMemoryLearningHistoryStore(),
            speechRecognizer: ScriptedSpeechRecognizer(transcripts: []),
            speechSynthesizer: MockSpeechSynthesizer(),
            soundPlayer: MockSoundPlayer(),
            haptics: NoopHapticsService(),
            purchaseService: MockPurchaseService(),
            adPresenter: MockAdPresenter(allow: true),
            profileImageStore: store,
            launchArguments: TestEnvironment.makeLaunchArguments()
        )
        second.bootstrap()

        XCTAssertNotNil(second.avatar.photoFileName)
        XCTAssertEqual(second.avatarImageData(), jpegLikeData())
    }

    // MARK: - 写真の整形

    func testAvatarImageIsCroppedToASquareAndShrunk() throws {
        let wide = UIGraphicsImageRenderer(size: CGSize(width: 1200, height: 600)).image { context in
            UIColor.orange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1200, height: 600))
        }
        let square = try XCTUnwrap(AvatarImageProcessor.squareImage(from: wide))
        XCTAssertEqual(square.size.width, square.size.height, "正方形になっていない")
        XCTAssertLessThanOrEqual(Double(square.size.width), AvatarImageGeometry.targetSide)

        let data = try XCTUnwrap(AvatarImageProcessor.makeAvatarData(from: wide))
        XCTAssertFalse(data.isEmpty)
        // 元の画像より小さくなっていること（端末に巨大な写真を置かない）
        XCTAssertLessThan(data.count, 2_000_000)
    }
}
