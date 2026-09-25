import SwiftUI
import PiyoCore

/// セッションのおわり。
///
/// 子どもの結果 → おうちのかたに わたす → おうちのかた向けの実績、の 3 段階で進む。
/// 広告はいちばん最後（おうちのかたの画面）にだけ出す。
struct SessionResultView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.piyoLayout) private var layout

    let summary: SessionSummary
    var onDone: () -> Void

    private enum Stage {
        /// 子どもが見る結果
        case child
        /// おうちのかたに渡すための待ち受け
        case handoff
        /// おうちのかたが見る実績
        case parent
    }

    @State private var stage: Stage = .child
    @State private var animateStars = false
    @State private var isShowingGate = false

    var body: some View {
        ZStack {
            PiyoBackground(tint: stage == .parent ? PiyoTheme.calm : PiyoTheme.cheer)
            if stage == .child {
                ConfettiView(isActive: animateStars)
            }

            switch stage {
            case .child: childResult
            case .handoff: handoff
            case .parent: parentSummary
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(A11yID.result)
        .animation(.easeInOut(duration: 0.25), value: stage)
        .sheet(isPresented: $isShowingGate) {
            ParentGateView(
                onPass: {
                    environment.markParentGatePassed()
                    isShowingGate = false
                    showParentSummary()
                },
                onCancel: { isShowingGate = false }
            )
            .environment(environment)
        }
        .onAppear {
            animateStars = true
            environment.speak(summary.childMessage)
        }
    }

    // MARK: - 子どもの結果

    private var childResult: some View {
        AdaptiveColumn(spacing: 26, maxWidth: 560) {
            Spacer(minLength: 12)

            CharacterArtView(
                character: environment.buddyCharacter,
                mood: .happy,
                size: layout.scaled(170, minimum: 110)
            )

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

            BigButton(color: PiyoTheme.success, action: goToHandoff) {
                HStack(spacing: 10) {
                    Image(systemName: "hand.wave.fill")
                    Text("おうちのひとに みせる")
                        .font(PiyoTheme.headlineFont)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
            }
            .accessibilityIdentifier(A11yID.resultShowParent)
        }
        .padding(24)
    }

    // MARK: - おうちのかたへ渡す

    private var handoff: some View {
        AdaptiveColumn(spacing: 24, maxWidth: 560) {
            Spacer(minLength: 12)

            CharacterArtView(
                character: environment.buddyCharacter,
                mood: .cheering,
                size: layout.scaled(150, minimum: 100)
            )

            Text("おうちのひとに わたしてね")
                .font(PiyoTheme.titleFont)
                .foregroundStyle(PiyoTheme.text)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)

            Text("きょう がんばったことを みてもらおう")
                .font(PiyoTheme.bodyFont)
                .foregroundStyle(PiyoTheme.textSoft)
                .multilineTextAlignment(.center)

            Spacer(minLength: 12)

            BigButton(color: PiyoTheme.calm, action: goToParent) {
                Text("うけとりました")
                    .font(PiyoTheme.headlineFont)
            }
            .accessibilityIdentifier(A11yID.resultHandoffReceived)

            Text("おうちのかたが おしてください")
                .font(PiyoTheme.captionFont)
                .foregroundStyle(PiyoTheme.textSoft)
        }
        .padding(24)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(A11yID.resultHandoff)
    }

    // MARK: - おうちのかたの実績

    private var parentSummary: some View {
        VStack(spacing: 0) {
            // 広告はおうちのかたが見る画面にだけ出す。
            if environment.adPresenter.shouldPresentAd(adsRemoved: environment.settings.adsRemoved) {
                ParentAdBannerView()
            }

            VStack(spacing: 12) {
                Text("きょうの がんばり")
                    .font(PiyoTheme.titleFont)
                    .foregroundStyle(PiyoTheme.text)

                AdaptivePanes(spacing: 20) {
                    VStack(spacing: 16) {
                        PiyoCard {
                            VStack(spacing: 14) {
                                Text("このかい")
                                    .font(PiyoTheme.captionFont)
                                    .foregroundStyle(PiyoTheme.textSoft)
                                HStack(spacing: 0) {
                                    statColumn(title: "といた", value: "\(summary.questionCount)もん")
                                    Divider().frame(height: 44)
                                    statColumn(title: "せいかい", value: "\(summary.correctCount)もん")
                                    Divider().frame(height: 44)
                                    statColumn(title: "ほし", value: "★\(summary.starsEarned)")
                                }
                            }
                        }

                        PiyoCard {
                            VStack(spacing: 14) {
                                Text("これまで")
                                    .font(PiyoTheme.captionFont)
                                    .foregroundStyle(PiyoTheme.textSoft)
                                HStack(spacing: 0) {
                                    statColumn(title: "がくしゅう日", value: "\(environment.progress.learningDays)日")
                                    Divider().frame(height: 44)
                                    statColumn(title: "といた", value: "\(environment.progress.totalQuestions)もん")
                                    Divider().frame(height: 44)
                                    statColumn(title: "ほし", value: "★\(environment.progress.totalStars)")
                                }
                            }
                        }

                        if !review.outcomes.isEmpty {
                            reviewCard
                        }
                    }
                } trailing: {
                    VStack(spacing: 16) {
                        if !review.praisePoints.isEmpty {
                            praiseCard
                        }
                        if !review.watchPoints.isEmpty {
                            watchCard
                        }
                    }
                }

                BigButton(color: PiyoTheme.success, minHeight: 72, action: onDone) {
                    HStack(spacing: 10) {
                        Image(systemName: "house.fill")
                        Text("ホームへ")
                            .font(PiyoTheme.headlineFont)
                    }
                }
                .accessibilityIdentifier(A11yID.resultDone)
            }
            .padding(20)
        }
        // children: .contain を付けないと中身がひとつの要素にまとめられ、
        // 「ホームへ」などがアクセシビリティツリーから消えてしまう。
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(A11yID.resultParent)
    }

    /// この回の振り返り。記録から組み立てるので、問題文そのものは出せない。
    private var review: SessionReview { SessionReview.make(from: summary) }

    private var praiseCard: some View {
        PiyoCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("ほめる ポイント", systemImage: "hands.clap.fill")
                    .font(PiyoTheme.bodyFont)
                    .foregroundStyle(PiyoTheme.primaryDeep)

                ForEach(review.praisePoints, id: \.self) { point in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(PiyoTheme.success)
                        Text(point)
                            .font(PiyoTheme.captionFont)
                            .foregroundStyle(PiyoTheme.text)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityIdentifier(A11yID.resultPraise)
    }

    private var reviewCard: some View {
        PiyoCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("やったこと")
                    .font(PiyoTheme.captionFont)
                    .foregroundStyle(PiyoTheme.textSoft)

                ForEach(review.outcomes) { outcome in
                    HStack(spacing: 8) {
                        Text(outcome.skill.parentTitle)
                            .font(PiyoTheme.captionFont)
                            .foregroundStyle(PiyoTheme.text)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Spacer(minLength: 8)
                        if outcome.solvedAfterRetry > 0 {
                            Text("やりなおし \(outcome.solvedAfterRetry)")
                                .font(PiyoTheme.childFont(size: 12, weight: .semibold))
                                .foregroundStyle(PiyoTheme.textSoft)
                        }
                        Text("\(outcome.solved) / \(outcome.questionCount)")
                            .font(PiyoTheme.bodyFont)
                            .foregroundStyle(PiyoTheme.text)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityIdentifier(A11yID.resultReview)
    }

    private var watchCard: some View {
        PiyoCard {
            VStack(alignment: .leading, spacing: 10) {
                Label("きになる ところ", systemImage: "lightbulb.fill")
                    .font(PiyoTheme.bodyFont)
                    .foregroundStyle(PiyoTheme.textSoft)

                ForEach(review.watchPoints, id: \.self) { point in
                    Text(point)
                        .font(PiyoTheme.captionFont)
                        .foregroundStyle(PiyoTheme.textSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func statColumn(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(PiyoTheme.headlineFont)
                .foregroundStyle(PiyoTheme.text)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(title)
                .font(PiyoTheme.captionFont)
                .foregroundStyle(PiyoTheme.textSoft)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 操作

    private func goToHandoff() {
        environment.haptics.tap()
        stage = .handoff
        environment.speak("おうちのひとに わたしてね")
    }

    private func goToParent() {
        environment.haptics.tap()
        environment.stopSpeaking()
        // この起動ですでに大人が確認していれば、そのまま実績を出す。
        if environment.hasPassedParentGateThisLaunch {
            showParentSummary()
        } else {
            isShowingGate = true
        }
    }

    private func showParentSummary() {
        environment.refreshProgress()
        stage = .parent
    }
}
