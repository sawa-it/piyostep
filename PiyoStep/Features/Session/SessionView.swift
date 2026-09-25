import SwiftUI
import PiyoCore

/// 学習セッションの画面。出題・回答・フィードバック・結果をまとめる。
struct SessionView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.piyoLayout) private var layout

    let request: SessionRequest

    @State private var model: SessionViewModel?
    @State private var isShowingQuitConfirmation = false

    private var isShowingResult: Bool {
        model?.stage == .finished && model?.summary != nil
    }

    var body: some View {
        ZStack {
            PiyoBackground(tint: PiyoTheme.color(for: request.subject ?? .number))

            if let model {
                sessionBody(model)
            }

            if isShowingQuitConfirmation {
                QuitConfirmView(
                    character: environment.buddyCharacter,
                    onQuit: { dismiss() },
                    onContinue: {
                        isShowingQuitConfirmation = false
                        model?.speakPrompt()
                    }
                )
                .transition(.opacity)
                .zIndex(5)
            }
        }
        .accessibilityElement(children: .contain)
        // 入れ子のコンテナは潰れてしまうので、結果画面に変わったら名前も入れ替える。
        // こうしないと「いまどの画面か」が VoiceOver からも UI テストからも分からない。
        .accessibilityIdentifier(isShowingResult ? A11yID.result : A11yID.session)
        .animation(.easeInOut(duration: 0.2), value: isShowingQuitConfirmation)
        .onAppear {
            // 幼児は考えているあいだ画面に触らない。途中で暗くならないようにする。
            UIApplication.shared.isIdleTimerDisabled = true
            guard model == nil else { return }
            let created = SessionViewModel(
                environment: environment,
                kind: request.kind,
                subject: request.subject,
                questions: request.questions
            )
            created.start()
            model = created
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            model?.close()
        }
    }

    @ViewBuilder
    private func sessionBody(_ model: SessionViewModel) -> some View {
        if model.stage == .finished, let summary = model.summary {
            SessionResultView(summary: summary) {
                dismiss()
            }
        } else {
            VStack(spacing: 14) {
                header(model)
                if layout.usesSideBySideAnswer {
                    // 横向きは出題を左、回答を右に置く。縦に積むと、
                    // 高さ 390pt の iPhone 横持ちで回答ボタンが画面の外に出る。
                    HStack(alignment: .top, spacing: CGFloat(layout.spacing)) {
                        ScrollView { questionArea(model).padding(.vertical, 4) }
                        ScrollView { answerArea(model).padding(.vertical, 4) }
                    }
                    .padding(.horizontal, CGFloat(layout.spacing))
                    .padding(.bottom, 16)
                    .piyoContentWidth(layout)
                } else {
                    ScrollView {
                        VStack(spacing: CGFloat(layout.spacing)) {
                            questionArea(model)
                            answerArea(model)
                        }
                        .padding(.horizontal, CGFloat(layout.spacing))
                        .padding(.bottom, 28)
                        .piyoContentWidth(layout)
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if model.stage == .feedback, let feedback = model.feedback {
                    FeedbackPanel(
                        feedback: feedback,
                        character: environment.buddyCharacter,
                        onRetry: { model.retryCurrentQuestion() },
                        onNext: { model.advance() }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .overlay {
                ConfettiView(isActive: model.showsConfetti)
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: model.stage)
        }
    }

    // MARK: - ヘッダー

    private func header(_ model: SessionViewModel) -> some View {
        VStack(spacing: 10) {
            HStack {
                Button {
                    model.stopVoice()
                    environment.speak("やめる？")
                    isShowingQuitConfirmation = true
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundStyle(PiyoTheme.textSoft)
                        .frame(width: 56, height: 56)
                        .background(Circle().fill(PiyoTheme.surface.opacity(0.9)))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(A11yID.sessionClose)

                Spacer()

                Text("\(min(model.progressCount + 1, model.totalCount)) / \(model.totalCount)")
                    .piyoFont(.body)
                    .foregroundStyle(PiyoTheme.textSoft)

                Spacer()

                Button {
                    model.speakPrompt()
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(PiyoTheme.textSoft)
                        .frame(width: 56, height: 56)
                        .background(Circle().fill(PiyoTheme.surface.opacity(0.9)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("もういちど きく")
            }
            SessionProgressBar(current: model.progressCount, total: model.totalCount)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    // MARK: - 出題

    private func questionArea(_ model: SessionViewModel) -> some View {
        VStack(spacing: 16) {
            Text(model.currentQuestion?.prompt.displayText ?? "")
                .piyoFont(.title)
                .foregroundStyle(PiyoTheme.text)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)
                .lineLimit(2)
                .accessibilityIdentifier(A11yID.sessionPrompt)

            if let question = model.currentQuestion {
                QuestionContentView(question: question, model: model)
            }

            if model.showsHint, let hint = model.currentQuestion?.prompt.hintText {
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(PiyoTheme.cheer)
                    Text(hint)
                        .piyoFont(.body)
                        .foregroundStyle(PiyoTheme.textSoft)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Capsule().fill(PiyoTheme.cheer.opacity(0.18)))
            }
        }
    }

    // MARK: - 回答

    /// 答え方は切り替えない。タップの手段は問題ごとに 1 つ、声はその横で勝手に聞いている。
    @ViewBuilder
    private func answerArea(_ model: SessionViewModel) -> some View {
        VStack(spacing: 16) {
            if model.showsTapInput {
                if model.showsVoiceStatus {
                    VoiceListeningBadge(model: model)
                }
                switch model.tapMode {
                case .dragHands:
                    ClockDragPanel(model: model)
                case .trace:
                    TracePanel(model: model)
                case .choice, .numberPad, .voice:
                    ChoiceGridView(model: model)
                }
            } else {
                VoiceAnswerPanel(model: model)
            }
        }
        .disabled(model.stage == .feedback)
        .opacity(model.stage == .feedback ? 0.4 : 1)
    }
}

/// 「やめる？」の確認。
///
/// システムのダイアログは文字だけで、幼児には読めない。
/// キャラクターと絵つきの大きな 2 択にして、声でも聞かせる。
struct QuitConfirmView: View {
    @Environment(\.piyoLayout) private var layout

    let character: CharacterDefinition
    var onQuit: () -> Void
    var onContinue: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()

            VStack(spacing: CGFloat(layout.sized(18))) {
                HStack(spacing: 16) {
                    CharacterArtView(character: character, mood: .thinking, size: CGFloat(layout.sized(90)))
                    Text("やめる？")
                        .piyoFont(.title)
                        .foregroundStyle(PiyoTheme.text)
                }

                HStack(spacing: CGFloat(layout.sized(14))) {
                    BigButton(color: PiyoTheme.calm, action: onQuit) {
                        VStack(spacing: 6) {
                            Image(systemName: "house.fill")
                                .font(.system(size: CGFloat(layout.fontSize(30)), weight: .bold))
                            Text("おうちへ")
                                .piyoFont(.headline)
                        }
                        .padding(.vertical, 8)
                    }
                    .accessibilityIdentifier(A11yID.sessionQuitConfirm)

                    BigButton(color: PiyoTheme.success, action: onContinue) {
                        VStack(spacing: 6) {
                            Image(systemName: "play.fill")
                                .font(.system(size: CGFloat(layout.fontSize(30)), weight: .bold))
                            Text("つづける")
                                .piyoFont(.headline)
                        }
                        .padding(.vertical, 8)
                    }
                    .accessibilityIdentifier(A11yID.sessionQuitCancel)
                }
            }
            .padding(CGFloat(layout.sized(24)))
            .frame(maxWidth: 560)
            .background(
                RoundedRectangle(cornerRadius: PiyoTheme.cornerRadius, style: .continuous)
                    .fill(PiyoTheme.surface)
                    .shadow(color: .black.opacity(0.18), radius: 24, y: 10)
            )
            .padding(24)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(A11yID.sessionQuitDialog)
    }
}

/// 正解・不正解のフィードバック。
struct FeedbackPanel: View {
    let feedback: SessionFeedback
    let character: CharacterDefinition
    var onRetry: () -> Void
    var onNext: () -> Void

    private var tint: Color {
        switch feedback.judgement {
        case .correct: return PiyoTheme.success
        case .incorrect: return PiyoTheme.primary
        case .unclear: return PiyoTheme.calm
        }
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                CharacterArtView(
                    character: character,
                    mood: feedback.judgement == .correct ? .happy : .cheering,
                    size: 80
                )
                VStack(alignment: .leading, spacing: 6) {
                    Text(feedback.message)
                        .piyoFont(.headline)
                        .foregroundStyle(PiyoTheme.text)
                        .minimumScaleFactor(0.6)
                        .lineLimit(3)
                        .accessibilityIdentifier(A11yID.sessionFeedback)
                    if feedback.starsEarned > 0 {
                        StarRewardView(stars: feedback.starsEarned, maximum: 2, size: 26)
                    }
                }
                Spacer(minLength: 0)
            }

            if feedback.canRetry {
                BigButton(color: tint, action: onRetry) {
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("もういっかい！")
                            .piyoFont(.headline)
                    }
                }
                .accessibilityIdentifier(A11yID.sessionRetry)
            } else {
                // 読み終えると自動でも進む。押せば待たずに進める。
                BigButton(color: tint, action: onNext) {
                    HStack(spacing: 10) {
                        Text("つぎへ")
                            .piyoFont(.headline)
                        Image(systemName: "arrow.right")
                    }
                }
                .accessibilityIdentifier(A11yID.sessionNext)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: PiyoTheme.cornerRadius, style: .continuous)
                .fill(PiyoTheme.surface)
                .shadow(color: .black.opacity(0.14), radius: 20, y: -4)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .frame(maxWidth: 720)
    }
}
