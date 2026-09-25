import SwiftUI
import PiyoCore

/// タップで選ぶ回答。
struct ChoiceGridView: View {
    @Bindable var model: SessionViewModel

    private var columns: [GridItem] {
        [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]
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
                .font(PiyoTheme.childFont(size: 52, weight: .heavy))
                .foregroundStyle(PiyoTheme.text)
                .minimumScaleFactor(0.4)
                .lineLimit(1)
        case .number(let value):
            Text("\(value)")
                .font(PiyoTheme.childFont(size: 52, weight: .heavy))
                .foregroundStyle(PiyoTheme.text)
                .minimumScaleFactor(0.4)
                .lineLimit(1)
        case .clock(let time):
            VStack(spacing: 4) {
                MiniClockView(time: time, size: 76)
                Text(time.displayJapanese)
                    .font(PiyoTheme.captionFont)
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

    private let digitRows = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]

    var body: some View {
        VStack(spacing: 14) {
            Text(model.numberInput.isEmpty ? "—" : model.numberInput)
                .font(PiyoTheme.childFont(size: 56, weight: .heavy))
                .foregroundStyle(PiyoTheme.text)
                .frame(maxWidth: .infinity, minHeight: 84)
                .background(
                    RoundedRectangle(cornerRadius: PiyoTheme.smallCornerRadius)
                        .fill(PiyoTheme.surface)
                )

            // 12 個しかないので遅延生成しない。LazyVGrid だと画面外のボタンが
            // つくられず、VoiceOver や UI テストから決定ボタンにたどり着けない。
            Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                ForEach(digitRows, id: \.self) { row in
                    GridRow {
                        ForEach(row, id: \.self) { digit in
                            digitButton(digit)
                        }
                    }
                }
                GridRow {
                    clearButton
                    digitButton(0)
                    submitButton
                }
            }
        }
    }

    private func digitButton(_ digit: Int) -> some View {
        Button {
            model.appendDigit(digit)
        } label: {
            Text("\(digit)")
                .font(PiyoTheme.childFont(size: 36, weight: .heavy))
                .foregroundStyle(PiyoTheme.text)
                .frame(maxWidth: .infinity, minHeight: 72)
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
                .frame(maxWidth: .infinity, minHeight: 72)
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
                .frame(maxWidth: .infinity, minHeight: 72)
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

    private let digitRows = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                slot(text: model.hourInput, unit: "じ", field: .hour)
                slot(text: model.minuteInput, unit: "ふん", field: .minute)
            }

            // 12 個しかないので遅延生成しない。LazyVGrid だと画面外のボタンが
            // つくられず、VoiceOver や UI テストから決定ボタンにたどり着けない。
            Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                ForEach(digitRows, id: \.self) { row in
                    GridRow {
                        ForEach(row, id: \.self) { digit in
                            digitButton(digit)
                        }
                    }
                }
                GridRow {
                    clearButton
                    digitButton(0)
                    submitButton
                }
            }
        }
    }

    private func slot(text: String, unit: String, field: SessionViewModel.TimeField) -> some View {
        Button {
            model.activeTimeField = field
        } label: {
            HStack(spacing: 4) {
                Text(text.isEmpty ? "—" : text)
                    .font(PiyoTheme.childFont(size: 44, weight: .heavy))
                    .foregroundStyle(PiyoTheme.text)
                Text(unit)
                    .font(PiyoTheme.bodyFont)
                    .foregroundStyle(PiyoTheme.textSoft)
            }
            .frame(maxWidth: .infinity, minHeight: 84)
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
                .font(PiyoTheme.childFont(size: 36, weight: .heavy))
                .foregroundStyle(PiyoTheme.text)
                .frame(maxWidth: .infinity, minHeight: 72)
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
                .frame(maxWidth: .infinity, minHeight: 72)
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
                .frame(maxWidth: .infinity, minHeight: 72)
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

    var body: some View {
        VStack(spacing: 16) {
            Text("いま \(model.draggedTime.displayJapanese)")
                .font(PiyoTheme.headlineFont)
                .foregroundStyle(PiyoTheme.textSoft)

            BigButton(color: PiyoTheme.success, action: { model.submitDraggedTime() }) {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("できた！")
                        .font(PiyoTheme.headlineFont)
                }
            }
            .accessibilityIdentifier(A11yID.sessionClockSubmit)
        }
    }
}

/// なぞり書き・自由書き。
struct TracePanel: View {
    @Environment(\.piyoLayout) private var layout
    @Bindable var model: SessionViewModel

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
                canvasSize: layout.scaled(280, minimum: 180),
                strokes: $model.traceStrokes
            )

            HStack(spacing: 12) {
                Button {
                    model.traceStrokes = []
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("けす")
                            .font(PiyoTheme.bodyFont)
                    }
                    .foregroundStyle(PiyoTheme.textSoft)
                    .frame(maxWidth: .infinity, minHeight: 72)
                    .background(RoundedRectangle(cornerRadius: 18).fill(PiyoTheme.surfaceSunken))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(A11yID.sessionTraceClear)

                BigButton(
                    color: PiyoTheme.success,
                    minHeight: 72,
                    isEnabled: !model.traceStrokes.isEmpty,
                    action: { model.submitTrace() }
                ) {
                    Text("できた！")
                        .font(PiyoTheme.headlineFont)
                }
                .accessibilityIdentifier(A11yID.sessionTraceSubmit)
            }
        }
    }
}

/// 音声で答える。マイク・波形・キャラクターの反応をまとめる。
struct VoiceAnswerPanel: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.piyoLayout) private var layout
    @Bindable var model: SessionViewModel

    private var isListening: Bool {
        model.voiceState.isListening
    }

    /// 横向きで高さが足りないときはマイクを小さくする。
    private var micDiameter: CGFloat { layout.scaled(132, minimum: 92) }

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                CharacterArtView(
                    character: environment.buddyCharacter,
                    mood: isListening ? .listening : .idle,
                    size: layout.scaled(84, minimum: 60)
                )
                VStack(alignment: .leading, spacing: 6) {
                    Text(model.voiceGuidanceText)
                        .font(PiyoTheme.headlineFont)
                        .foregroundStyle(PiyoTheme.text)
                        .minimumScaleFactor(0.6)
                        .lineLimit(2)
                        .accessibilityIdentifier(A11yID.sessionVoiceStatus)
                    if !model.voiceTranscript.isEmpty {
                        Text(model.voiceTranscript)
                            .font(PiyoTheme.captionFont)
                            .foregroundStyle(PiyoTheme.textSoft)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }

            VoiceWaveformView(level: model.voiceLevel, isListening: isListening)

            micButton

            if model.shouldSuggestTapAnswer {
                Button {
                    model.answerMode = .choice
                    model.stopVoice()
                } label: {
                    Text("タップで こたえる")
                        .font(PiyoTheme.bodyFont)
                        .foregroundStyle(PiyoTheme.primaryDeep)
                        .frame(maxWidth: .infinity, minHeight: 64)
                        .background(Capsule().fill(PiyoTheme.primary.opacity(0.14)))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var micButton: some View {
        Button {
            if isListening {
                model.stopVoice()
            } else {
                model.startVoice()
            }
        } label: {
            ZStack {
                Circle()
                    .fill(isListening ? PiyoTheme.primaryDeep : PiyoTheme.primary)
                    .frame(width: micDiameter, height: micDiameter)
                    .shadow(color: PiyoTheme.primary.opacity(0.45), radius: isListening ? 24 : 12, y: 6)
                if isListening {
                    Circle()
                        .stroke(PiyoTheme.primary.opacity(0.45), lineWidth: 8)
                        .frame(
                            width: micDiameter + CGFloat(model.voiceLevel) * 60,
                            height: micDiameter + CGFloat(model.voiceLevel) * 60
                        )
                        .animation(.easeOut(duration: 0.18), value: model.voiceLevel)
                }
                Image(systemName: isListening ? "waveform" : "mic.fill")
                    .font(.system(size: micDiameter * 0.41, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(height: micDiameter + 44)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(A11yID.sessionVoiceButton)
        .accessibilityLabel(isListening ? "きいているよ" : "マイク")
    }
}
