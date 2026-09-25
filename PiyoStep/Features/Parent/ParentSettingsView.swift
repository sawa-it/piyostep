import SwiftUI
import PhotosUI
import PiyoCore

/// 保護者向けの設定。
struct ParentSettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var model: SettingsViewModel?

    var body: some View {
        Form {
            if let model {
                ChildSettingsSection(model: model)
                AppearanceSettingsSection(model: model)
                LearningSettingsSection(model: model)
                SoundSettingsSection(model: model)
                MealSettingsSection(model: model)
                SubjectSettingsSection(model: model)
                CreditsSection()
            }
        }
        .onAppear {
            if model == nil {
                model = SettingsViewModel(environment: environment)
            }
        }
        .onDisappear {
            model?.apply()
        }
    }
}

private struct ChildSettingsSection: View {
    @Bindable var model: SettingsViewModel
    @FocusState private var isNameFocused: Bool

    var body: some View {
        Section {
            TextField("なまえ", text: $model.childName)
                .accessibilityIdentifier(A11yID.settingsChildName)
                .keyboardDoneButton(isFocused: $isNameFocused)
                .onChange(of: isNameFocused) { _, focused in
                    if !focused { model.apply() }
                }

            Picker("年齢", selection: $model.childAge) {
                ForEach(3 ... 6, id: \.self) { age in
                    Text("\(age)さい").tag(age)
                }
            }
            .accessibilityIdentifier(A11yID.settingsAge)
            .onChange(of: model.childAge) { _, _ in model.apply() }

            Picker("あいぼう", selection: $model.buddyCharacterID) {
                ForEach(model.availableCharacters) { character in
                    Text(character.name).tag(character.id)
                }
            }
            .onChange(of: model.buddyCharacterID) { _, _ in model.apply() }
        } header: {
            Text("おこさま")
        }
    }
}

/// アプリの呼び名と、じぶんの アイコン。
private struct AppearanceSettingsSection: View {
    @Bindable var model: SettingsViewModel
    @FocusState private var isAppNameFocused: Bool
    @State private var photoItem: PhotosPickerItem?
    @State private var isImporting = false

    var body: some View {
        Section {
            TextField(AppNaming.defaultName, text: $model.draft.appDisplayName)
                .accessibilityIdentifier(A11yID.settingsAppName)
                .keyboardDoneButton(isFocused: $isAppNameFocused)
                .onChange(of: isAppNameFocused) { _, focused in
                    if !focused { model.apply() }
                }

            if let suggestion = model.appNameSuggestion {
                Button("「\(suggestion)」に する") {
                    model.useSuggestedAppName()
                }
                .accessibilityIdentifier(A11yID.settingsAppNameSuggestion)
            }

            if !model.isUsingDefaultAppName {
                Button("もとの なまえに もどす", role: .destructive) {
                    model.resetAppName()
                }
                .accessibilityIdentifier(A11yID.settingsAppNameReset)
            }

            HStack(spacing: 16) {
                AvatarView(avatar: model.avatar, photoData: model.avatarPhotoData, size: 64)

                VStack(alignment: .leading, spacing: 8) {
                    PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
                        Text(model.isUsingPhotoAvatar ? "しゃしんを えらびなおす" : "しゃしんを えらぶ")
                    }
                    .accessibilityIdentifier(A11yID.settingsAvatarPick)
                    .disabled(isImporting)

                    if model.isUsingPhotoAvatar {
                        Button("あいぼうの えに もどす", role: .destructive) {
                            model.useCharacterAvatar()
                        }
                        .accessibilityIdentifier(A11yID.settingsAvatarClear)
                    }
                }
            }

            if let error = model.avatarError {
                Text(error)
                    .piyoFont(.caption)
                    .foregroundStyle(PiyoTheme.primary)
            }
        } header: {
            Text("アプリの みため")
        } footer: {
            Text("ここで決めた なまえと アイコンは、アプリの中のホーム画面に出ます。iPhone のホーム画面に並ぶアプリ名とアイコンは、iOS のきまりで変えられません。えらんだ写真はこの端末の中だけに保存され、外には送られません。")
        }
        .onChange(of: photoItem) { _, newItem in
            guard let newItem else { return }
            isImporting = true
            Task {
                let data = await Self.loadAvatarData(from: newItem)
                model.useAvatarPhoto(data: data)
                isImporting = false
                photoItem = nil
            }
        }
    }

    /// 選ばれた写真を読み、アイコン用に整えた JPEG にする。
    private static func loadAvatarData(from item: PhotosPickerItem) async -> Data? {
        guard let original = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: original) else {
            return nil
        }
        return AvatarImageProcessor.makeAvatarData(from: image)
    }
}

private struct LearningSettingsSection: View {
    @Bindable var model: SettingsViewModel

    var body: some View {
        Section {
            Picker("難易度", selection: $model.draft.difficultyMode) {
                ForEach(DifficultyMode.allCases) { mode in
                    Text(mode.parentTitle).tag(mode)
                }
            }
            .accessibilityIdentifier(A11yID.settingsDifficulty)
            .onChange(of: model.draft.difficultyMode) { _, _ in model.apply() }

            Picker("1日の学習量", selection: $model.draft.dailyGoal) {
                ForEach(DailyGoal.allCases) { goal in
                    Text(goal.parentTitle).tag(goal)
                }
            }
            .accessibilityIdentifier(A11yID.settingsDailyGoal)
            .onChange(of: model.draft.dailyGoal) { _, _ in model.apply() }
        } header: {
            Text("がくしゅう")
        } footer: {
            Text("「じどう」にすると、正答率に応じて出題の難しさが自動で調整されます。")
        }
    }
}

private struct SoundSettingsSection: View {
    @Bindable var model: SettingsViewModel

    var body: some View {
        Section {
            HStack {
                Image(systemName: "speaker.fill")
                Slider(value: $model.draft.volume, in: 0 ... 1)
                    .accessibilityIdentifier(A11yID.settingsVolume)
                    .onChange(of: model.draft.volume) { _, _ in model.apply() }
                Image(systemName: "speaker.wave.3.fill")
            }
            Toggle("よみあげ（音声ガイド）", isOn: $model.draft.voiceGuidanceEnabled)
                .accessibilityIdentifier(A11yID.settingsVoiceGuidance)
                .onChange(of: model.draft.voiceGuidanceEnabled) { _, _ in model.apply() }
            Toggle("こえで答える", isOn: $model.draft.voiceAnswerEnabled)
                .accessibilityIdentifier(A11yID.settingsVoiceAnswer)
                .onChange(of: model.draft.voiceAnswerEnabled) { _, _ in model.apply() }
            Toggle("しんどうフィードバック", isOn: $model.draft.hapticsEnabled)
                .onChange(of: model.draft.hapticsEnabled) { _, _ in model.apply() }
        } header: {
            Text("おと")
        } footer: {
            Text("こえで答える機能には、マイクと音声認識の許可が必要です。許可がなくてもタップで学習を続けられます。")
        }
    }
}

private struct MealSettingsSection: View {
    @Bindable var model: SettingsViewModel

    var body: some View {
        Section {
            Picker("せいげん時間", selection: $model.draft.mealDurationMinutes) {
                ForEach(model.mealDurationPresets, id: \.self) { minutes in
                    Text("\(minutes)分").tag(minutes)
                }
                if !model.mealDurationPresets.contains(model.draft.mealDurationMinutes) {
                    Text("\(model.draft.mealDurationMinutes)分").tag(model.draft.mealDurationMinutes)
                }
            }
            .accessibilityIdentifier(A11yID.settingsMealMinutes)

            Stepper(
                "こまかく調整： \(model.draft.mealDurationMinutes)分",
                value: $model.draft.mealDurationMinutes,
                in: AppSettings.mealDurationRange
            )
            .onChange(of: model.draft.mealDurationMinutes) { _, _ in model.apply() }

            Picker("キャラクター", selection: $model.draft.mealCharacterID) {
                ForEach(model.availableCharacters) { character in
                    Text(character.name).tag(character.id)
                }
            }
            .onChange(of: model.draft.mealCharacterID) { _, _ in model.apply() }
        } header: {
            Text("ごはんタイマー")
        } footer: {
            Text("キャラクターは、設定した時間を目安に食べ終わります。毎回少しだけ変化します。")
        }
    }
}

private struct SubjectSettingsSection: View {
    @Bindable var model: SettingsViewModel

    var body: some View {
        Section {
            ForEach(Subject.allCases) { subject in
                Button {
                    model.toggle(subject: subject)
                } label: {
                    HStack {
                        Text(subject.parentTitle)
                            .foregroundStyle(Color.primary)
                        Spacer()
                        Image(systemName: model.isEnabled(subject: subject) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(model.isEnabled(subject: subject) ? PiyoTheme.success : Color.secondary)
                    }
                }
                .accessibilityIdentifier("\(A11yID.settingsSubject)\(subject.rawValue)")
            }
        } header: {
            Text("あそぶジャンル")
        } footer: {
            Text("すべてオフにはできません。年齢に合わないジャンルは自動的に出題されません。")
        }
    }
}

/// 広告解除の購入。
struct PurchaseView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var message: String?
    @State private var isWorking = false

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Label("広告について", systemImage: "info.circle")
                        .font(.headline)
                    Text("広告はアプリの起動時にだけ表示されます。学習中とごはんタイマー中には表示されません。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }

            Section {
                if environment.settings.adsRemoved {
                    Label("広告は解除されています", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                } else {
                    Button {
                        Task { await purchase() }
                    } label: {
                        HStack {
                            Text("広告を解除する")
                            Spacer()
                            Text(environment.purchaseService.displayPrice ?? "—")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .disabled(isWorking)

                    Button("購入を復元する") {
                        Task { await restore() }
                    }
                    .disabled(isWorking)
                }
            }

            if let message {
                Section {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .task {
            await environment.purchaseService.loadProducts()
        }
    }

    private func purchase() async {
        isWorking = true
        defer { isWorking = false }
        apply(outcome: await environment.purchaseService.purchaseAdFree())
    }

    private func restore() async {
        isWorking = true
        defer { isWorking = false }
        apply(outcome: await environment.purchaseService.restorePurchases())
    }

    private func apply(outcome: PurchaseOutcome) {
        switch outcome {
        case .purchased:
            var settings = environment.settings
            settings.adsRemoved = true
            environment.update(settings: settings)
            message = "ありがとうございます。広告を解除しました。"
        case .cancelled:
            message = nil
        case .pending:
            message = "承認待ちです。完了すると自動で反映されます。"
        case .nothingToRestore:
            message = "復元できる購入は見つかりませんでした。"
        case .failed(let reason):
            message = "うまくいきませんでした：\(reason)"
        }
    }
}

/// つかっている素材のクレジット。ライセンスの条件で、全文を読めるようにしておく。
private struct CreditsSection: View {
    @State private var isExpanded = false

    var body: some View {
        Section {
            HStack(spacing: 12) {
                ArtImage(asset: .chick, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text("イラスト: Fluent Emoji")
                        .font(.subheadline)
                    Text("© Microsoft Corporation（MIT License）")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            DisclosureGroup("ライセンス全文", isExpanded: $isExpanded) {
                Text(licenseText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        } header: {
            Text("つかっている素材")
        }
    }

    private var licenseText: String {
        guard let url = Bundle.main.url(forResource: "FluentEmoji-LICENSE", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return "MIT License — Copyright (c) Microsoft Corporation."
        }
        return text
    }
}
