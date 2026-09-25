import SwiftUI
import PiyoCore

/// ご飯タイマーの入れ物。準備 → 競争 → 結果 を 1 画面で切り替える。
struct MealRaceContainerView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss

    @State private var model: MealRaceViewModel?

    var body: some View {
        PiyoLayoutReader { _ in
            ZStack {
                PiyoBackground(tint: PiyoTheme.success)
                if let model {
                    switch model.stage {
                    case .ready:
                        MealSetupView(model: model, onClose: { dismiss() })
                    case .countdown(let value):
                        CountdownView(value: value, character: model.character)
                    case .racing:
                        MealRaceView(model: model, onClose: { dismiss() })
                    case .finished:
                        MealResultView(model: model, onDone: { dismiss() })
                    }
                }
            }
        }
        .onAppear {
            if model == nil {
                model = MealRaceViewModel(environment: environment)
            }
        }
        .onDisappear {
            model?.cancel()
        }
    }
}

/// スタート前。保護者の設定内容を見せてから始める。
struct MealSetupView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.piyoLayout) private var layout
    @Bindable var model: MealRaceViewModel
    var onClose: () -> Void

    private func minuteButton(_ minutes: Int) -> some View {
        let isSelected = model.targetMinutes == minutes
        return Button {
            model.select(minutes: minutes)
        } label: {
            VStack(spacing: 2) {
                Text("\(minutes)")
                    .font(PiyoTheme.childFont(size: 30, weight: .heavy))
                Text("ふん")
                    .font(PiyoTheme.childFont(size: 13, weight: .semibold))
            }
            .foregroundStyle(isSelected ? .white : PiyoTheme.textSoft)
            .frame(maxWidth: .infinity, minHeight: 72)
            .background(
                RoundedRectangle(cornerRadius: PiyoTheme.smallCornerRadius, style: .continuous)
                    .fill(isSelected ? PiyoTheme.success : PiyoTheme.surfaceSunken)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("\(A11yID.mealMinutes)\(minutes)")
        .accessibilityLabel("\(minutes)ふん")
    }

    var body: some View {
        // 時間の選択肢が増えて 1 列では入りきらないので、横向きでは左右に分ける。
        VStack(spacing: 12) {
            HStack {
                BackCircleButton(action: onClose)
                Spacer()
            }

            AdaptivePanes(spacing: 20) {
                VStack(spacing: 14) {
                    CharacterArtView(
                        character: model.character,
                        mood: .happy,
                        size: layout.scaled(170, minimum: 110)
                    )

                    Text(model.character.raceIntroLine)
                        .font(PiyoTheme.headlineFont)
                        .foregroundStyle(PiyoTheme.text)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.6)
                        .padding(.horizontal, 12)
                }
            } trailing: {
                VStack(spacing: 18) {
                    PiyoCard {
                        VStack(spacing: 16) {
                            Text("なんぷんで たべる？")
                                .font(PiyoTheme.bodyFont)
                                .foregroundStyle(PiyoTheme.textSoft)

                            // 食べる時間はその日の量で変わるので、始める前にここで選べるようにする。
                            LazyVGrid(
                                columns: [GridItem(.adaptive(minimum: 84), spacing: 10)],
                                spacing: 10
                            ) {
                                ForEach(MealRaceViewModel.selectableMinutes, id: \.self) { minutes in
                                    minuteButton(minutes)
                                }
                            }

                            Divider()

                            HStack(spacing: 10) {
                                Image(systemName: "fork.knife")
                                    .font(.system(size: 24))
                                    .foregroundStyle(PiyoTheme.success)
                                Text(model.character.favoriteFood)
                                    .font(PiyoTheme.bodyFont)
                                    .foregroundStyle(PiyoTheme.text)
                            }
                        }
                    }

                    BigButton(color: PiyoTheme.success, minHeight: 104, action: { model.begin() }) {
                        HStack(spacing: 12) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 30, weight: .bold))
                            Text("スタート！")
                                .font(PiyoTheme.titleFont)
                                .minimumScaleFactor(0.6)
                                .lineLimit(1)
                        }
                    }
                    .accessibilityIdentifier(A11yID.mealStart)
                }
            }
        }
        .padding(20)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(A11yID.mealSetup)
        .onAppear {
            environment.speak(model.character.raceIntroLine)
        }
    }
}

/// 3・2・1 のカウントダウン。
struct CountdownView: View {
    let value: Int
    let character: CharacterDefinition

    var body: some View {
        VStack(spacing: 28) {
            CharacterArtView(character: character, mood: .cheering, size: 160)
            Text("\(value)")
                .font(PiyoTheme.childFont(size: 140, weight: .heavy))
                .foregroundStyle(PiyoTheme.primaryDeep)
                .transition(.scale.combined(with: .opacity))
                .id(value)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: value)
    }
}

/// 競争中。
struct MealRaceView: View {
    @Environment(AppEnvironment.self) private var environment
    @Bindable var model: MealRaceViewModel
    var onClose: () -> Void

    var body: some View {
        PiyoLayoutReader { metrics in
            VStack(spacing: 8) {
                header

                // キャラクターを主役にして、手前の茶碗のごはんが経過で減っていく。
                ZStack(alignment: .bottomTrailing) {
                    MealSceneView(
                        character: model.character,
                        activity: model.snapshot.characterActivity,
                        bowlFullness: model.characterPlateFullness,
                        message: model.characterMessage,
                        size: max(180, min(480, metrics.size.height * 0.55))
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    finishControls
                }
                .frame(maxHeight: .infinity)

                // いちばん下に、キャラクターの進み具合だけを横いっぱいの帯で出す。
                CharacterProgressBar(
                    progress: model.snapshot.characterProgress,
                    character: model.character
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(A11yID.mealRace)
    }

    /// 食べ終わりの操作。声でも終われるので、ボタンは邪魔にならない大きさに留める。
    private var finishControls: some View {
        VStack(alignment: .trailing, spacing: 8) {
            if let hint = model.voiceHint {
                Label(hint, systemImage: model.isListeningForFinish ? "mic.fill" : "mic.slash.fill")
                    .font(PiyoTheme.captionFont)
                    .foregroundStyle(PiyoTheme.textSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(PiyoTheme.surface))
            }

            Button {
                model.finish()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 26, weight: .bold))
                    Text("たべおわった！")
                        .font(PiyoTheme.headlineFont)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 22)
                .frame(minHeight: 88)
                .background(
                    RoundedRectangle(cornerRadius: PiyoTheme.cornerRadius, style: .continuous)
                        .fill(PiyoTheme.success)
                        .shadow(color: PiyoTheme.success.opacity(0.35), radius: 10, y: 5)
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(A11yID.mealFinish)
        }
    }

    private var header: some View {
        HStack {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(PiyoTheme.textSoft)
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(PiyoTheme.surface.opacity(0.9)))
            }
            .buttonStyle(.plain)

            Spacer()

            HStack(spacing: 8) {
                Image(systemName: "timer")
                    .foregroundStyle(PiyoTheme.textSoft)
                Text(model.remainingText)
                    .font(PiyoTheme.headlineFont)
                    .foregroundStyle(PiyoTheme.text)
                    .monospacedDigit()
            }

            Spacer()
            Color.clear.frame(width: 52, height: 52)
        }
    }

}

/// 結果。どちらが先でも、必ず前向きな表現にする。
struct MealResultView: View {
    @Environment(AppEnvironment.self) private var environment
    @Bindable var model: MealRaceViewModel
    var onDone: () -> Void

    var body: some View {
        AdaptiveColumn(spacing: 24, maxWidth: 560) {
            Spacer(minLength: 0)

            HStack(spacing: -16) {
                CharacterArtView(character: model.character, mood: .cheering, size: 140)
                CharacterArtView(character: environment.buddyCharacter, mood: .happy, size: 120)
            }

            if let result = model.result {
                Text(result.headline)
                    .font(PiyoTheme.childFont(size: 44, weight: .heavy))
                    .foregroundStyle(PiyoTheme.primaryDeep)

                Text(result.subline)
                    .font(PiyoTheme.headlineFont)
                    .foregroundStyle(PiyoTheme.text)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, 12)

                StarRewardView(stars: result.starsEarned, maximum: 3, size: 40)

                if !result.childFinishedFirst {
                    Text(model.character.watchingLine)
                        .font(PiyoTheme.bodyFont)
                        .foregroundStyle(PiyoTheme.textSoft)
                }
            }

            Spacer(minLength: 0)

            BigButton(color: PiyoTheme.success, action: onDone) {
                HStack(spacing: 10) {
                    Image(systemName: "house.fill")
                    Text("ホームへ")
                        .font(PiyoTheme.headlineFont)
                }
            }
            .accessibilityIdentifier(A11yID.mealResultDone)
        }
        .padding(24)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(A11yID.mealResult)
        .overlay {
            ConfettiView(isActive: true)
        }
    }
}
