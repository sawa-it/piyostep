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
        LazyVGrid(columns: columns, spacing: 14) {
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
                MiniClockView(time: time, size: 76)
                Text(time.displayJapanese)
                    .piyoFont(.caption)
                    .foregroundStyle(PiyoTheme.textSoft)
            }
        case .object(let kind, let count):
            CountableObjectsView(kind: kind, count: count, maximumColumns: 5, itemSize: 24)
        case .picture(let card):
            EnglishWordIllustration(card: card, size: 76, showsText: false)
        case .kanaWord(let card, let subject):
            KanaWordIllustration(card: card, subject: subject, size: 70, showsWord: false)
        }
    }
}

/// 数字入力のキーパッド。
struct NumberPadView: View {
    @Bindable var model: SessionViewModel
    @Environment(\.piyoLayout) private var layout

    private let digits = [1, 2, 3, 4, 5, 6, 7, 8, 9]

    var body: some View {
        VStack(spacing: 14) {
            Text(model.numberInput.isEmpty ? "—" : model.numberInput)
                .piyoFont(size: 56, weight: .heavy)
                .foregroundStyle(PiyoTheme.text)
                .frame(maxWidth: .infinity, minHeight: CGFloat(layout.sized(84)))
                .background(
                    RoundedRectangle(cornerRadius: PiyoTheme.smallCornerRadius)
                        .fill(PiyoTheme.surface)
                )

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3),
                spacing: 12
            ) {
                ForEach(digits, id: \.self) { digit in
                    digitButton(digit)
                }
                clearButton
                digitButton(0)
                submitButton
            }
        }
    }

    private func digitButton(_ digit: Int) -> some View {
        Button {
            model.appendDigit(digit)
        } label: {
            Text("\(digit)")
                .piyoFont(size: 36, weight: .heavy)
                .foregroundStyle(PiyoTheme.text)
                .frame(maxWidth: .infinity, minHeight: CGFloat(layout.sized(72)))
                .background(
                    RoundedRectangle(cornerRadius: 18).fill(PiyoTheme.surface)
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("\(A11yID.sessionNumberPadDigit)\(digit)")
    }

    private var clearButton: some View {
        Button {
            model.clearInput()
        } label: {
            Image(systemName: "delete.left.fill")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(PiyoTheme.textSoft)
                .frame(maxWidth: .infinity, minHeight: CGFloat(layout.sized(72)))
                .background(RoundedRectangle(cornerRadius: 18).fill(PiyoTheme.surfaceSunken))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(A11yID.sessionNumberPadClear)
    }

    private var submitButton: some View {
        Button {
            model.submitNumberInput()
        } label: {
            Image(systemName: "checkmark")
                .font(.system(size: 28, weight: .heavy))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: CGFloat(layout.sized(72)))
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(model.numberInput.isEmpty ? PiyoTheme.outline : PiyoTheme.success)
                )
        }
        .buttonStyle(.plain)
        .disabled(model.numberInput.isEmpty)
        .accessibilityIdentifier(A11yID.sessionNumberPadSubmit)
    }
}

/// 時刻を数字で入力するパッド（○じ ○ふん）。
struct TimePadView: View {
    @Bindable var model: SessionViewModel
    @Environment(\.piyoLayout) private var layout

    private let digits = [1, 2, 3, 4, 5, 6, 7, 8, 9]

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                slot(text: model.hourInput, unit: "じ", field: .hour)
                slot(text: model.minuteInput, unit: "ふん", field: .minute)
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3),
                spacing: 12
            ) {
                ForEach(digits, id: \.self) { digit in
                    digitButton(digit)
                }
                clearButton
                digitButton(0)
                submitButton
            }
        }
    }

    private func slot(text: String, unit: String, field: SessionViewModel.TimeField) -> some View {
        Button {
            model.activeTimeField = field
        } label: {
            HStack(spacing: 4) {
                Text(text.isEmpty ? "—" : text)
                    .piyoFont(size: 44, weight: .heavy)
                    .foregroundStyle(PiyoTheme.text)
                Text(unit)
                    .piyoFont(.body)
                    .foregroundStyle(PiyoTheme.textSoft)
            }
            .frame(maxWidth: .infinity, minHeight: CGFloat(layout.sized(84)))
            .background(
                RoundedRectangle(cornerRadius: PiyoTheme.smallCornerRadius)
                    .fill(PiyoTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: PiyoTheme.smallCornerRadius)
                            .stroke(
                                model.activeTimeField == field ? PiyoTheme.primary : PiyoTheme.outline,
                                lineWidth: model.activeTimeField == field ? 5 : 2
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func digitButton(_ digit: Int) -> some View {
        Button {
            model.appendDigit(digit)
        } label: {
            Text("\(digit)")
                .piyoFont(size: 36, weight: .heavy)
                .foregroundStyle(PiyoTheme.text)
                .frame(maxWidth: .infinity, minHeight: CGFloat(layout.sized(72)))
                .background(RoundedRectangle(cornerRadius: 18).fill(PiyoTheme.surface))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("\(A11yID.sessionNumberPadDigit)\(digit)")
    }

    private var clearButton: some View {
        Button {
            model.clearInput()
        } label: {
            Image(systemName: "delete.left.fill")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(PiyoTheme.textSoft)
                .frame(maxWidth: .infinity, minHeight: CGFloat(layout.sized(72)))
                .background(RoundedRectangle(cornerRadius: 18).fill(PiyoTheme.surfaceSunken))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(A11yID.sessionNumberPadClear)
    }

    private var submitButton: some View {
        Button {
            model.submitTimeInput()
        } label: {
            Image(systemName: "checkmark")
                .font(.system(size: 28, weight: .heavy))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: CGFloat(layout.sized(72)))
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(model.hourInput.isEmpty ? PiyoTheme.outline : PiyoTheme.success)
                )
        }
        .buttonStyle(.plain)
        .disabled(model.hourInput.isEmpty)
        .accessibilityIdentifier(A11yID.sessionNumberPadSubmit)
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

    /// かきとりでは お手本を出さない。まちがえて 2 回目に入ったときだけ、ヒントとして出す。
    private var showsTemplate: Bool {
        guard let question = model.currentQuestion else { return true }
        return TraceTemplatePolicy.showsTemplate(for: question.content, hintShown: model.showsHint)
    }

    var body: some View {
        VStack(spacing: 14) {
            TraceCanvasView(
                character: templateText,
                showsTemplate: showsTemplate,
                canvasSize: CGFloat(layout.artSized(280)),
                strokes: $model.traceStrokes
            )

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
                    .frame(maxWidth: .infinity, minHeight: CGFloat(layout.sized(72)))
                    .background(RoundedRectangle(cornerRadius: 18).fill(PiyoTheme.surfaceSunken))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(A11yID.sessionTraceClear)

                BigButton(
                    color: PiyoTheme.success,
                    minHeight: CGFloat(layout.sized(72)),
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

/// 聞き取り中のしるし。ボタンではない。
///
/// 問題を読み上げ終えると自動でマイクが開き、答え待ちのあいだ ずっと聞いている。
/// 「マイクを押してから話す」も「音声モードに切り替える」も幼児にはできないので、
/// 押すものは置かず、いま聞いていることだけを キャラクターと波形で見せる。
struct ListeningIndicatorView: View {
    @Environment(AppEnvironment.self) private var environment
    @Bindable var model: SessionViewModel

    private var isListening: Bool {
        model.isListening
    }

    var body: some View {
        HStack(spacing: 12) {
            CharacterArtView(
                character: environment.buddyCharacter,
                mood: isListening ? .listening : .idle,
                size: 56
            )
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: isListening ? "ear.fill" : "ear")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(isListening ? PiyoTheme.primaryDeep : PiyoTheme.textSoft)
                    Text(isListening ? "きいているよ" : "こえでも こたえられるよ")
                        .piyoFont(.body)
                        .foregroundStyle(PiyoTheme.text)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
                if !model.voiceTranscript.isEmpty {
                    Text(model.voiceTranscript)
                        .piyoFont(.caption)
                        .foregroundStyle(PiyoTheme.textSoft)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            VoiceWaveformView(level: model.voiceLevel, isListening: isListening, barCount: 5)
                .frame(width: 64)
                .opacity(isListening ? 1 : 0.35)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule().fill(isListening ? PiyoTheme.primary.opacity(0.12) : PiyoTheme.surface.opacity(0.8))
        )
        .animation(.easeInOut(duration: 0.25), value: isListening)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier(A11yID.sessionVoiceStatus)
        .accessibilityLabel(model.voiceGuidanceText)
    }
}
