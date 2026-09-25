import SwiftUI
import PiyoCore

/// セッションのおわり。点数で評価せず、がんばりをねぎらう。
struct SessionResultView: View {
    @Environment(AppEnvironment.self) private var environment

    let summary: SessionSummary
    var onDone: () -> Void

    @State private var animateStars = false

    var body: some View {
        ZStack {
            PiyoBackground(tint: PiyoTheme.cheer)
            ConfettiView(isActive: animateStars)

            VStack(spacing: 26) {
                Spacer(minLength: 12)

                CharacterArtView(character: environment.buddyCharacter, mood: .happy, size: 170)

                Text(summary.childMessage)
                    .font(PiyoTheme.titleFont)
                    .foregroundStyle(PiyoTheme.text)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.6)

                PiyoCard {
                    VStack(spacing: 18) {
                        HStack(spacing: 10) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 34))
                                .foregroundStyle(PiyoTheme.cheer)
                            Text("★ \(summary.starsEarned)")
                                .font(PiyoTheme.titleFont)
                                .foregroundStyle(PiyoTheme.text)
                        }
                        .accessibilityIdentifier(A11yID.resultStars)

                        HStack(spacing: 8) {
                            ForEach(0 ..< max(1, summary.questionCount), id: \.self) { index in
                                Image(systemName: index < summary.correctCount ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 24))
                                    .foregroundStyle(
                                        index < summary.correctCount ? PiyoTheme.success : PiyoTheme.outline
                                    )
                            }
                        }

                        Text("\(summary.questionCount)もん やったよ")
                            .font(PiyoTheme.bodyFont)
                            .foregroundStyle(PiyoTheme.textSoft)
                    }
                }

                Spacer(minLength: 12)

                BigButton(color: PiyoTheme.success, action: onDone) {
                    HStack(spacing: 10) {
                        Image(systemName: "house.fill")
                        Text("ホームへ")
                            .font(PiyoTheme.headlineFont)
                    }
                }
                .accessibilityIdentifier(A11yID.resultDone)
            }
            .padding(24)
            .frame(maxWidth: 560)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(A11yID.result)
        .onAppear {
            animateStars = true
            environment.speak(summary.childMessage)
        }
    }
}
