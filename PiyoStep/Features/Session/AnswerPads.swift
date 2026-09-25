import SwiftUI
import PiyoCore

/// タップで選ぶ回答。
struct ChoiceGridView: View {
    @Bindable var model: SessionViewModel
    @Environment(\.piyoLayout) private var layout

    private var columns: [GridItem] {
        let spacing = CGFloat(layout.sized(14))
        return Array(repeating: GridItem(.flexible(), spacing: spacing), count: 2)
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: CGFloat(layout.sized(14))) {
            ForEach(Array(model.visibleChoices.enumerated()), id: \.element.id) { index, choice in
                ChoiceCardButton(
                    isHighlighted: model.selectedChoiceID == choice.id,
                    highlightColor: PiyoTheme.primary
                ) {
                    model.select(choice: choice)
                } content: {
                    choiceContent(choice)
                        .padding(12)
                }
                .accessibilityIdentifier("\(A11yID.sessionChoice)\(index)")
                .accessibilityLabel(choice.spokenText)
            }
        }
    }

    @ViewBuilder
    private func choiceContent(_ choice: AnswerChoice) -> some View {
        switch choice.display {
        case .text(let text):
            Text(text)
                .piyoFont(size: 52, weight: .heavy)
                .foregroundStyle(PiyoTheme.text)
                .minimumScaleFactor(0.4)
                .lineLimit(1)
        case .number(let value):
            Text("\(value)")
                .piyoFont(size: 52, weight: .heavy)
                .foregroundStyle(PiyoTheme.text)
                .minimumScaleFactor(0.4)
                .lineLimit(1)
        case .clock(let time):
            VStack(spacing: 4) {
                MiniClockView(time: time, size: CGFloat(layout.sized(76)))
                Text(time.displayJapanese)
                    .piyoFont(.caption)
                    .foregroundStyle(PiyoTheme.textSoft)
            }
        case .object(let kind, let count):
            CountableObjectsView(kind: kind, count: count, maximumColumns: 5, itemSize: CGFloat(layout.sized(24)))
        case .picture(let card):
            EnglishWordIllustration(card: card, size: CGFloat(layout.sized(76)), showsText: false)
        case .kanaWord(let card, let subject):
            KanaWordIllustration(card: card, subject: subject, size: CGFloat(layout.sized(70)), showsWord: false)
        }
    }
}

/// 時計の針を動かして答える。
struct ClockDragPanel: View {
    @Bindable var model: SessionViewModel
    @Environment(\.piyoLayout) private var layout

    var body: some View {
        VStack(spacing: 16) {
            Text("いま \(model.draggedTime.displayJapanese)")
                .piyoFont(.headline)
                .foregroundStyle(PiyoTheme.textSoft)

            BigButton(color: PiyoTheme.success, action: { model.submitDraggedTime() }) {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("できた！")
                        .piyoFont(.headline)
                }
            }
            .accessibilityIdentifier(A11yID.sessionClockSubmit)
        }
    }
}

/// なぞり書き・自由書き。
struct TracePanel: View {
    @Bindable var model: SessionViewModel
    @Environment(\.piyoLayout) private var layout

    private var templateText: String {
        guard let question = model.currentQuestion else { return "" }
        return AnswerGrader.correctAnswerDisplay(for: question)
    }

    private var showsTemplate: Bool {
        guard let question = model.currentQuestion else { return true }
        switch question.content {
        case .kanaCard(_, let task), .alphabetCard(_, let task, _):
            return task == .trace
        default:
            return true
        }
    }

    var body: some View {
        VStack(spacing: 14) {
            TraceCanvasView(
                character: templateText,
                showsTemplate: showsTemplate,
                canvasSize: CGFloat(layout.artSized(280)),
                strokes: $model.traceStrokes
            )
            // 線を引き終えるたびに見て、十分なぞれていれば「できた！」を待たずに進む。
            .onChange(of: model.traceStrokes.count) { _, _ in
                model.autoSubmitTraceIfComplete()
            }

            HStack(spacing: 12) {
                Button {
                    model.traceStrokes = []
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("けす")
                            .piyoFont(.body)
                    }
                    .foregroundStyle(PiyoTheme.textSoft)
                    .frame(maxWidth: .infinity, minHeight: CGFloat(layout.minimumTapSize))
                    .background(RoundedRectangle(cornerRadius: 18).fill(PiyoTheme.surfaceSunken))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(A11yID.sessionTraceClear)

                BigButton(
                    color: PiyoTheme.success,
                    isEnabled: !model.traceStrokes.isEmpty,
                    action: { model.submitTrace() }
                ) {
                    Text("できた！")
                        .piyoFont(.headline)
                }
                .accessibilityIdentifier(A11yID.sessionTraceSubmit)
            }
        }
    }
}

/// 「こえで こたえる」問題の回答エリア。
///
/// マイクは押させない。問いかけを読み終えると勝手に聞き始めるので、
/// 子どもは画面のキャラクターに向かって話すだけでよい。
/// 聞き取りが止まったときだけ、マイクを押すともう一度聞いてくれる。
struct VoiceAnswerPanel: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.piyoLayout) private var layout
    @Bindable var model: SessionViewModel

    private var isListening: Bool { model.isListening }

    var body: some View {
        VStack(spacing: CGFloat(layout.sized(14))) {
            HStack(spacing: 14) {
                CharacterArtView(
                    character: environment.buddyCharacter,
                    mood: isListening ? .listening : .idle,
                    size: CGFloat(layout.sized(84))
                )
                VStack(alignment: .leading, spacing: 6) {
                    Text(model.voiceGuidanceText)
                        .piyoFont(.headline)
                        .foregroundStyle(PiyoTheme.text)
                        .minimumScaleFactor(0.6)
                        .lineLimit(2)
                        .accessibilityIdentifier(A11yID.sessionVoiceStatus)
                    if !model.voiceTranscript.isEmpty {
                        Text(model.voiceTranscript)
                            .piyoFont(.caption)
                            .foregroundStyle(PiyoTheme.textSoft)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }

            VoiceWaveformView(level: model.voiceLevel, isListening: isListening)

            micIndicator

            // 話したくない子・話せない場面のための逃げ道。押すと選択肢に切り替わる。
            Button {
                model.chooseTapAnswer()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "hand.tap.fill")
                    Text("タップで こたえる")
                        .piyoFont(.body)
                }
                .foregroundStyle(PiyoTheme.primaryDeep)
                .frame(maxWidth: .infinity, minHeight: CGFloat(layout.sized(64)))
                .background(Capsule().fill(PiyoTheme.primary.opacity(0.14)))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(A11yID.sessionTapFallback)
        }
    }

    /// マイクは指で押すものなので、狭い画面でも小さくしすぎない。
    private var micSize: CGFloat { CGFloat(max(120, layout.artSized(132))) }

    private var micIndicator: some View {
        Button {
            model.startVoice()
        } label: {
            ZStack {
                Circle()
                    .fill(isListening ? PiyoTheme.primaryDeep : PiyoTheme.primary)
                    .frame(width: micSize, height: micSize)
                    .shadow(color: PiyoTheme.primary.opacity(0.45), radius: isListening ? 24 : 12, y: 6)
                if isListening {
                    Circle()
                        .stroke(PiyoTheme.primary.opacity(0.45), lineWidth: 8)
                        .frame(width: micSize + CGFloat(model.voiceLevel) * 60, height: micSize + CGFloat(model.voiceLevel) * 60)
                        .animation(.easeOut(duration: 0.18), value: model.voiceLevel)
                }
                Image(systemName: isListening ? "waveform" : "mic.fill")
                    .font(.system(size: 54, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(height: micSize * 1.33)
        }
        .buttonStyle(.plain)
        .disabled(!model.canRestartVoice)
        .accessibilityIdentifier(A11yID.sessionVoiceButton)
        .accessibilityLabel(isListening ? "きいているよ" : "もういちど きいてもらう")
    }
}

/// タップで答える問題に添える、小さな「きいているよ」表示。
///
/// 選択肢を押しても、声で言ってもよい。どちらも同じ画面にあるので切り替えは要らない。
/// 聞き取りが止まったときは、この帯そのものがマイクのボタンになる。
struct VoiceListeningBadge: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.piyoLayout) private var layout
    @Bindable var model: SessionViewModel

    private var isListening: Bool { model.isListening }

    var body: some View {
        Button {
            model.startVoice()
        } label: {
            HStack(spacing: 12) {
                CharacterArtView(
                    character: environment.buddyCharacter,
                    mood: isListening ? .listening : .idle,
                    size: CGFloat(layout.sized(56))
                )
                VoiceWaveformView(level: model.voiceLevel, isListening: isListening, barCount: 5)
                    .frame(width: CGFloat(layout.sized(64)))
                Text(model.voiceGuidanceText)
                    .piyoFont(.body)
                    .foregroundStyle(PiyoTheme.text)
                    .minimumScaleFactor(0.6)
                    .lineLimit(2)
                    .accessibilityIdentifier(A11yID.sessionVoiceStatus)
                Spacer(minLength: 0)
                Image(systemName: isListening ? "waveform" : "mic.fill")
                    .font(.system(size: CGFloat(layout.fontSize(22)), weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: CGFloat(layout.sized(48)), height: CGFloat(layout.sized(48)))
                    .background(Circle().fill(isListening ? PiyoTheme.primaryDeep : PiyoTheme.primary))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: CGFloat(layout.sized(72)))
            .background(
                RoundedRectangle(cornerRadius: PiyoTheme.smallCornerRadius, style: .continuous)
                    .fill(PiyoTheme.surface.opacity(0.9))
            )
            .overlay(
                RoundedRectangle(cornerRadius: PiyoTheme.smallCornerRadius, style: .continuous)
                    .stroke(isListening ? PiyoTheme.primary : PiyoTheme.outline.opacity(0.6), lineWidth: isListening ? 3 : 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!model.canRestartVoice)
        .accessibilityIdentifier(A11yID.sessionVoiceButton)
        .accessibilityLabel(isListening ? "きいているよ" : "もういちど きいてもらう")
    }
}
