import SwiftUI
import PiyoCore

/// はじめての起動。子ども本人でも進められるよう、3 ステップだけにする。
struct OnboardingView: View {
    @Environment(AppEnvironment.self) private var environment

    @State private var step = 0
    @State private var nickname = ""
    @State private var age = 4
    @State private var characterID = CharacterCatalog.defaultCharacterID

    private let ageOptions = [3, 4, 5, 6]

    var body: some View {
        ZStack {
            PiyoBackground(tint: PiyoTheme.primary)
            VStack(spacing: 28) {
                CharacterArtView(
                    character: CharacterCatalog.character(id: characterID) ?? CharacterCatalog.fallback,
                    mood: .happy,
                    size: 150
                )

                switch step {
                case 0: nameStep
                case 1: ageStep
                default: characterStep
                }
            }
            .padding(24)
            .frame(maxWidth: 560)
        }
        .onAppear {
            environment.speak("なまえを おしえてね")
        }
    }

    // MARK: - ステップ

    private var nameStep: some View {
        VStack(spacing: 24) {
            Text("なまえは なにかな？")
                .font(PiyoTheme.titleFont)
                .foregroundStyle(PiyoTheme.text)

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
        VStack(spacing: 24) {
            Text("なんさい？")
                .font(PiyoTheme.titleFont)
                .foregroundStyle(PiyoTheme.text)

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

    // MARK: - 操作

    private func goToAgeStep() {
        environment.haptics.tap()
        step = 1
        environment.speak("なんさい？")
    }

    private func goToCharacterStep() {
        environment.haptics.tap()
        step = 2
        environment.speak("あいぼうを えらぼう")
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
        environment.speak("\(profile.callName)、よろしくね！")
    }
}
