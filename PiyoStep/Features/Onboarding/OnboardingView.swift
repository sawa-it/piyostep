import SwiftUI
import PiyoCore

/// はじめての起動。子ども本人でも進められるよう、3 ステップだけにする。
///
/// なまえ と ねんれい は字が読めなくても進められるように、最初から声で入れられる。
/// キーボードや数字ボタンでの入力も残してあるので、保護者が代わりに入れてもよい。
struct OnboardingView: View {
    @Environment(AppEnvironment.self) private var environment

    @State private var step = 0
    @State private var nickname = ""
    @State private var age = 4
    @State private var characterID = CharacterCatalog.defaultCharacterID
    @State private var voice: OnboardingVoiceModel?

    private let ageOptions = [3, 4, 5, 6]

    var body: some View {
        PiyoLayoutReader { metrics in
            ZStack {
                PiyoBackground(tint: PiyoTheme.primary)

                // 横向きでは相棒キャラと入力欄を左右に分ける。縦向きでは今までどおり上下。
                AdaptivePanes(spacing: 24) {
                    buddy(metrics)
                } trailing: {
                    stepContent
                }
                .padding(24)
            }
        }
        .onAppear(perform: setUpVoice)
        .onDisappear { voice?.stop() }
    }

    private func buddy(_ metrics: PiyoLayoutMetrics) -> some View {
        CharacterArtView(
            character: CharacterCatalog.character(id: characterID) ?? CharacterCatalog.fallback,
            mood: voice?.isListening == true ? .listening : .happy,
            size: metrics.scaled(150, minimum: 100)
        )
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 0: nameStep
        case 1: ageStep
        default: characterStep
        }
    }

    // MARK: - ステップ

    private var nameStep: some View {
        VStack(spacing: 20) {
            Text("なまえは なにかな？")
                .font(PiyoTheme.titleFont)
                .foregroundStyle(PiyoTheme.text)

            if let voice {
                OnboardingVoicePanel(voice: voice)
            }

            TextField("なまえ", text: $nickname)
                .font(PiyoTheme.headlineFont)
                .multilineTextAlignment(.center)
                .textFieldStyle(.plain)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: PiyoTheme.smallCornerRadius)
                        .fill(PiyoTheme.surface)
                        .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
                )
                .accessibilityIdentifier(A11yID.onboardingNameField)

            BigButton(color: PiyoTheme.primary, action: goToAgeStep) {
                Text("つぎへ")
                    .font(PiyoTheme.headlineFont)
            }
            .accessibilityIdentifier(A11yID.onboardingNext)

            Text("あとから かえられます")
                .font(PiyoTheme.captionFont)
                .foregroundStyle(PiyoTheme.textSoft)
        }
    }

    private var ageStep: some View {
        VStack(spacing: 20) {
            Text("なんさい？")
                .font(PiyoTheme.titleFont)
                .foregroundStyle(PiyoTheme.text)

            if let voice {
                OnboardingVoicePanel(voice: voice)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
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
                                .font(PiyoTheme.childFont(size: 56, weight: .heavy))
                                .foregroundStyle(PiyoTheme.primaryDeep)
                            Text("さい")
                                .font(PiyoTheme.bodyFont)
                                .foregroundStyle(PiyoTheme.textSoft)
                        }
                    }
                    .accessibilityIdentifier("\(A11yID.onboardingAgeOption)\(option)")
                }
            }

            BigButton(color: PiyoTheme.primary, action: goToCharacterStep) {
                Text("つぎへ")
                    .font(PiyoTheme.headlineFont)
            }
            .accessibilityIdentifier(A11yID.onboardingNext)
        }
    }

    private var characterStep: some View {
        VStack(spacing: 24) {
            Text("あいぼうを えらぼう")
                .font(PiyoTheme.titleFont)
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
                                CharacterArtView(character: character, mood: .idle, size: 92, isAnimated: false)
                                Text(character.name)
                                    .font(PiyoTheme.captionFont)
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

            BigButton(color: PiyoTheme.success, action: finish) {
                HStack(spacing: 10) {
                    Image(systemName: "play.fill")
                    Text("はじめる！")
                        .font(PiyoTheme.headlineFont)
                }
            }
            .accessibilityIdentifier(A11yID.onboardingStart)
        }
    }

    // MARK: - 音声入力

    private func setUpVoice() {
        guard voice == nil else { return }
        let model = OnboardingVoiceModel(environment: environment)
        model.onName = { nickname = $0 }
        model.onAge = { age = $0 }
        voice = model
        model.begin(field: .name)
    }

    // MARK: - 操作

    private func goToAgeStep() {
        environment.haptics.tap()
        step = 1
        voice?.begin(field: .age)
    }

    private func goToCharacterStep() {
        environment.haptics.tap()
        step = 2
        voice?.stop()
        environment.speak("あいぼうを えらぼう")
    }

    private func finish() {
        voice?.stop()
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
        environment.speak("\(profile.callName)、よろしくね！")
    }
}

/// なまえ・ねんれい を声で入れるためのマイク。
/// 聞き取れなかったときも責めず、下の入力にも誘導する。
private struct OnboardingVoicePanel: View {
    @Environment(\.piyoLayout) private var layout
    @Bindable var voice: OnboardingVoiceModel

    private var diameter: CGFloat { layout.scaled(104, minimum: 76) }

    var body: some View {
        VStack(spacing: 10) {
            Button {
                voice.toggle()
            } label: {
                ZStack {
                    Circle()
                        .fill(voice.isListening ? PiyoTheme.primaryDeep : PiyoTheme.primary)
                        .frame(width: diameter, height: diameter)
                        .shadow(color: PiyoTheme.primary.opacity(0.45), radius: voice.isListening ? 20 : 10, y: 5)
                    if voice.isListening {
                        Circle()
                            .stroke(PiyoTheme.primary.opacity(0.45), lineWidth: 7)
                            .frame(
                                width: diameter + CGFloat(voice.level) * 48,
                                height: diameter + CGFloat(voice.level) * 48
                            )
                            .animation(.easeOut(duration: 0.18), value: voice.level)
                    }
                    Image(systemName: voice.isListening ? "waveform" : "mic.fill")
                        .font(.system(size: diameter * 0.42, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(height: diameter + 16)
            }
            .buttonStyle(.plain)
            .disabled(voice.state == .unavailable)
            .opacity(voice.state == .unavailable ? 0.4 : 1)
            .accessibilityIdentifier(A11yID.onboardingVoiceButton)
            .accessibilityLabel(voice.isListening ? "きいているよ" : "マイク")

            Text(voice.guidanceText)
                .font(PiyoTheme.bodyFont)
                .foregroundStyle(PiyoTheme.textSoft)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)
                .lineLimit(2)
                .accessibilityIdentifier(A11yID.onboardingVoiceStatus)

            if voice.isListening, !voice.transcript.isEmpty {
                Text(voice.transcript)
                    .font(PiyoTheme.captionFont)
                    .foregroundStyle(PiyoTheme.textSoft)
                    .lineLimit(1)
            }
        }
    }
}
