import SwiftUI
import PiyoCore

/// セッションのおわり。点数で評価せず、がんばりをねぎらう。
struct SessionResultView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.piyoLayout) private var layout

    let summary: SessionSummary
    var onDone: () -> Void

    @State private var animateStars = false

    var body: some View {
        ZStack {
            PiyoBackground(tint: PiyoTheme.cheer)
            ConfettiView(isActive: animateStars)

            resultBody
                .padding(CGFloat(layout.sized(24)))
                .piyoContentWidth(layout)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(A11yID.result)
        .onAppear {
            animateStars = true
            environment.speak(summary.childMessage)
        }
    }

    /// 横向きは、ねぎらいの絵と結果を左右に分ける。
    /// 縦に積むと高さが足りず「ホームへ」が画面の外に出てしまう。
    @ViewBuilder
    private var resultBody: some View {
        if layout.shape.isLandscape {
            HStack(spacing: CGFloat(layout.spacing)) {
                VStack(spacing: CGFloat(layout.sized(16))) {
                    character
                    message
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: CGFloat(layout.sized(18))) {
                    scoreCard
                    homeButton
                }
                .frame(maxWidth: .infinity)
            }
        } else {
            VStack(spacing: CGFloat(layout.sized(26))) {
                Spacer(minLength: 12)
                character
                message
                scoreCard
                Spacer(minLength: 12)
                homeButton
            }
        }
    }

    private var character: some View {
        ZStack {
            // 後ろで光の帯がゆっくり回る。「がんばった」の主役感を出す。
            SunburstView(color: PiyoTheme.cheer)
                .frame(width: CGFloat(layout.artSized(260)), height: CGFloat(layout.artSized(260)))
                .clipShape(Circle())
            CharacterArtView(
                character: environment.buddyCharacter,
                mood: .cheering,
                size: CGFloat(layout.artSized(170))
            )
            ArtImage(asset: .trophy, size: CGFloat(layout.artSized(64)))
                .offset(x: CGFloat(layout.artSized(88)), y: CGFloat(layout.artSized(48)))
                .shadow(color: PiyoTheme.shadow.opacity(0.2), radius: 6, y: 4)
        }
    }

    private var message: some View {
        Text(summary.childMessage)
            .piyoFont(.title)
            .foregroundStyle(PiyoTheme.text)
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.6)
    }

    private var scoreCard: some View {
        PiyoCard {
            VStack(spacing: CGFloat(layout.sized(18))) {
                HStack(spacing: 10) {
                    ArtImage(asset: .star, size: CGFloat(layout.fontSize(40)))
                    Text("★ \(summary.starsEarned)")
                        .piyoFont(.title)
                        .foregroundStyle(PiyoTheme.text)
                }
                .accessibilityIdentifier(A11yID.resultStars)

                HStack(spacing: 8) {
                    ForEach(0 ..< max(1, summary.questionCount), id: \.self) { index in
                        Image(systemName: index < summary.correctCount ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: CGFloat(layout.fontSize(24))))
                            .foregroundStyle(
                                index < summary.correctCount ? PiyoTheme.success : PiyoTheme.outline
                            )
                    }
                }

                Text("\(summary.questionCount)もん やったよ")
                    .piyoFont(.body)
                    .foregroundStyle(PiyoTheme.textSoft)
            }
        }
    }

    private var homeButton: some View {
        BigButton(color: PiyoTheme.success, action: onDone) {
            HStack(spacing: 10) {
                Image(systemName: "house.fill")
                Text("ホームへ")
                    .piyoFont(.headline)
            }
        }
        .accessibilityIdentifier(A11yID.resultDone)
    }
}
