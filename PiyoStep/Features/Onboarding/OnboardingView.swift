import SwiftUI
import PiyoCore

/// はじめての起動。子ども本人でも進められるよう、短く・戻れるようにする。
struct OnboardingView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.piyoLayout) private var layout
    @FocusState private var isNameFocused: Bool

    /// 進む順番。名前は飛ばせる。
    enum Step: Int, CaseIterable {
        case name
        case age
        case character
        case microphone
    }

    @State private var step: Step = .name
    @State private var nickname = ""
    @State private var age = 4
    @State private var characterID = CharacterCatalog.defaultCharacterID
    @State private var isAskingMicrophone = false

    private let ageOptions = [3, 4, 5, 6]

    /// 横向きは横に並べられるので列を増やす。
    private var onboardingColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: CGFloat(layout.sized(16))),
            count: layout.shape.isLandscape ? 4 : 2
        )
    }

    var body: some View {
        ZStack {
            PiyoBackground(tint: PiyoTheme.primary)

            VStack(spacing: 0) {
                progressHeader
                stepLayout
                    .padding(CGFloat(layout.sized(20)))
                    .piyoContentWidth(layout)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: step)
        .onAppear {
            environment.speak("なまえを おしえてね")
        }
    }

    /// いま何番目か、そして戻れることを見せる。
    /// 押し間違えても直せると分かっているほうが、思い切って押せる。
    private var progressHeader: some View {
        HStack(spacing: 12) {
            if step != .name {
                Button(action: goBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: CGFloat(layout.fontSize(20)), weight: .bold))
                        .foregroundStyle(PiyoTheme.textSoft)
                        .frame(width: 52, height: 52)
                        .background(Circle().fill(PiyoTheme.surface.opacity(0.9)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("もどる")
                .accessibilityIdentifier(A11yID.onboardingBack)
            }

            Spacer()

            HStack(spacing: 8) {
                ForEach(Step.allCases, id: \.rawValue) { item in
                    Capsule()
                        .fill(item == step ? PiyoTheme.primary : PiyoTheme.outline.opacity(0.6))
                        .frame(width: item == step ? 26 : 10, height: 10)
                }
            }

            Spacer()

            Color.clear.frame(width: 52, height: 52)
        }
        .padding(.horizontal, CGFloat(layout.sized(20)))
        .padding(.top, 12)
    }

    /// 横向きは、キャラクターを左に置いて縦を空ける。
    /// 縦に積むと、キーボードが出たときに「つぎへ」がその下に隠れてしまう。
    @ViewBuilder
    private var stepLayout: some View {
        if layout.shape.isLandscape {
            HStack(spacing: CGFloat(layout.spacing)) {
                buddy
                ScrollView { stepContent.padding(.vertical, 4) }
                    .frame(maxWidth: .infinity)
            }
        } else {
            VStack(spacing: CGFloat(layout.sized(24))) {
                buddy
                stepContent
            }
        }
    }

    private var buddy: some View {
        CharacterArtView(
            character: CharacterCatalog.character(id: characterID) ?? CharacterCatalog.fallback,
            mood: .happy,
            size: CGFloat(layout.artSized(150))
        )
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .name: nameStep
        case .age: ageStep
        case .character: characterStep
        case .microphone: microphoneStep
        }
    }

    // MARK: - ステップ

    private var nameStep: some View {
        VStack(spacing: CGFloat(layout.sized(18))) {
            Text("なまえは なにかな？")
                .piyoFont(.title)
                .foregroundStyle(PiyoTheme.text)

            TextField("なまえ", text: $nickname)
                .piyoFont(.headline)
                .multilineTextAlignment(.center)
                .textFieldStyle(.plain)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: PiyoTheme.smallCornerRadius)
                        .fill(PiyoTheme.surface)
                        .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
                )
                .accessibilityIdentifier(A11yID.onboardingNameField)
                .keyboardDoneButton(isFocused: $isNameFocused)

            BigButton(color: PiyoTheme.primary, action: goToAgeStep) {
                Text("つぎへ")
                    .piyoFont(.headline)
            }
            .accessibilityIdentifier(A11yID.onboardingNext)

            // 3〜6歳にキーボードは扱えない。飛ばせることを画面に出しておく。
            Button(action: skipName) {
                Text("なまえは あとで")
                    .piyoFont(.body)
                    .foregroundStyle(PiyoTheme.primaryDeep)
                    .frame(maxWidth: .infinity, minHeight: CGFloat(layout.sized(56)))
                    .background(Capsule().fill(PiyoTheme.primary.opacity(0.14)))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(A11yID.onboardingSkipName)

            Text("おうちのかたが あとから かえられます")
                .piyoFont(.caption)
                .foregroundStyle(PiyoTheme.textSoft)
                .multilineTextAlignment(.center)
        }
    }

    /// マイクの許可をここで取る。
    ///
    /// 答えようとした瞬間に許可ダイアログが割り込むと、子どもはもう話し始めていて
    /// 流れが切れてしまう。先に取っておき、断られてもタップで遊べる。
    private var microphoneStep: some View {
        VStack(spacing: CGFloat(layout.sized(18))) {
            Text("こえで こたえてみる？")
                .piyoFont(.title)
                .foregroundStyle(PiyoTheme.text)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)

            Image(systemName: "mic.fill")
                .font(.system(size: CGFloat(layout.artSized(56)), weight: .bold))
                .foregroundStyle(.white)
                .frame(width: CGFloat(layout.artSized(110)), height: CGFloat(layout.artSized(110)))
                .background(Circle().fill(PiyoTheme.primary))
                .shadow(color: PiyoTheme.primary.opacity(0.4), radius: 14, y: 6)

            Text("マイクを つかうと、こえで こたえられます。\nきいた ことばは この なかだけで つかいます。")
                .piyoFont(.caption)
                .foregroundStyle(PiyoTheme.textSoft)
                .multilineTextAlignment(.center)

            BigButton(color: PiyoTheme.success, isEnabled: !isAskingMicrophone, action: allowMicrophone) {
                HStack(spacing: 10) {
                    Image(systemName: "play.fill")
                    Text("はじめる！")
                        .piyoFont(.headline)
                }
            }
            .accessibilityIdentifier(A11yID.onboardingMicAllow)

            Button(action: finish) {
                Text("こえは つかわない")
                    .piyoFont(.body)
                    .foregroundStyle(PiyoTheme.textSoft)
                    .frame(maxWidth: .infinity, minHeight: CGFloat(layout.sized(56)))
            }
            .buttonStyle(.plain)
            .disabled(isAskingMicrophone)
            .accessibilityIdentifier(A11yID.onboardingMicLater)
        }
    }

    private var ageStep: some View {
        VStack(spacing: 24) {
            Text("なんさい？")
                .piyoFont(.title)
                .foregroundStyle(PiyoTheme.text)

            LazyVGrid(columns: onboardingColumns, spacing: CGFloat(layout.sized(16))) {
                ForEach(ageOptions, id: \.self) { option in
                    ChoiceCardButton(
                        isHighlighted: age == option,
                        highlightColor: PiyoTheme.primary
                    ) {
                        age = option
                        environment.speak("\(option)さい")
                        environment.haptics.tap()
                    } content: {
                        VStack(spacing: 4) {
                            Text("\(option)")
                                .piyoFont(size: 56, weight: .heavy)
                                .foregroundStyle(PiyoTheme.primaryDeep)
                            Text("さい")
                                .piyoFont(.body)
                                .foregroundStyle(PiyoTheme.textSoft)
                        }
                    }
                    .accessibilityIdentifier("\(A11yID.onboardingAgeOption)\(option)")
                }
            }

            BigButton(color: PiyoTheme.primary, action: goToCharacterStep) {
                Text("つぎへ")
                    .piyoFont(.headline)
            }
            .accessibilityIdentifier(A11yID.onboardingNext)
        }
    }

    private var characterStep: some View {
        VStack(spacing: 24) {
            Text("あいぼうを えらぼう")
                .piyoFont(.title)
                .foregroundStyle(PiyoTheme.text)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(environment.availableCharacters) { character in
                        Button {
                            characterID = character.id
                            environment.speak(character.name)
                            environment.haptics.tap()
                        } label: {
                            VStack(spacing: 8) {
                                CharacterArtView(character: character, mood: .idle, size: CGFloat(layout.artSized(92)), isAnimated: false)
                                Text(character.name)
                                    .piyoFont(.caption)
                                    .foregroundStyle(PiyoTheme.text)
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: PiyoTheme.smallCornerRadius)
                                    .fill(PiyoTheme.surface)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: PiyoTheme.smallCornerRadius)
                                            .stroke(
                                                characterID == character.id ? PiyoTheme.primary : PiyoTheme.outline,
                                                lineWidth: characterID == character.id ? 5 : 2
                                            )
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("\(A11yID.onboardingCharacter)\(character.id)")
                    }
                }
                .padding(.horizontal, 4)
            }

            BigButton(color: PiyoTheme.primary, action: goToMicrophoneStep) {
                Text("つぎへ")
                    .piyoFont(.headline)
            }
            .accessibilityIdentifier(A11yID.onboardingStart)
        }
    }

    // MARK: - 操作

    private func goToAgeStep() {
        isNameFocused = false
        environment.haptics.tap()
        step = .age
        environment.speak("なんさい？")
    }

    private func skipName() {
        nickname = ""
        goToAgeStep()
    }

    private func goToCharacterStep() {
        environment.haptics.tap()
        step = .character
        environment.speak("あいぼうを えらぼう")
    }

    private func goToMicrophoneStep() {
        environment.haptics.tap()
        step = .microphone
        environment.speak("こえで こたえてみる？")
    }

    private func goBack() {
        isNameFocused = false
        environment.haptics.tap()
        guard let previous = Step(rawValue: step.rawValue - 1) else { return }
        step = previous
    }

    /// マイクを許可してから始める。断られても、そのまま始める。
    private func allowMicrophone() {
        environment.haptics.tap()
        let recognizer = environment.speechRecognizer
        guard recognizer.authorizationStatus == .notDetermined else {
            finish()
            return
        }
        isAskingMicrophone = true
        recognizer.requestAuthorization { _ in
            Task { @MainActor in
                isAskingMicrophone = false
                finish()
            }
        }
    }

    private func finish() {
        let profile = ChildProfile(
            nickname: nickname.isEmpty ? "きみ" : nickname,
            age: age,
            buddyCharacterID: characterID,
            createdAt: environment.clock.now
        )
        environment.save(profile: profile)
        var settings = environment.settings
        settings.mealCharacterID = characterID
        environment.update(settings: settings)
        environment.play(.star)
        // ここでは読まない。この直後にホームが出て挨拶するので、そこで 1 回だけ読む。
        environment.pendingGreeting = "\(profile.callName)、よろしくね！ なにで あそぶ？"
    }
}
