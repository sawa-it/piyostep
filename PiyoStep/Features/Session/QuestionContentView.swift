import SwiftUI
import PiyoCore

/// 出題内容を描く。文字が読めなくても分かるよう、イラストと大きな文字が中心。
struct QuestionContentView: View {
    let question: Question
    @Bindable var model: SessionViewModel

    var body: some View {
        PiyoCard(padding: 22) {
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        switch question.content {
        case .clockRead(let time):
            AnalogClockView(time: time, isInteractive: false, size: 250)

        case .clockSet(let target, _, let step):
            VStack(spacing: 14) {
                Text(target.displayJapanese)
                    .font(PiyoTheme.giantFont)
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                    .foregroundStyle(PiyoTheme.primaryDeep)
                Text("はりを うごかしてね")
                    .font(PiyoTheme.captionFont)
                    .foregroundStyle(PiyoTheme.textSoft)
                AnalogClockView(
                    time: model.draggedTime,
                    isInteractive: true,
                    minuteStep: step,
                    size: 260,
                    onChange: { model.draggedTime = $0 }
                )
            }

        case .countObjects(let kind, let count):
            VStack(spacing: 12) {
                CountableObjectsView(
                    kind: kind,
                    count: count,
                    itemSize: count > 12 ? 40 : 54,
                    tappedIndices: model.countedIndices,
                    onTap: { model.toggleCounted(index: $0) }
                )
                Text("さわって かぞえてみよう")
                    .font(PiyoTheme.captionFont)
                    .foregroundStyle(PiyoTheme.textSoft)
            }

        case .numberRead(let value):
            Text("\(value)")
                .font(PiyoTheme.giantFont)
                .foregroundStyle(PiyoTheme.color(for: .number))
                .minimumScaleFactor(0.4)
                .lineLimit(1)

        case .placeValue(let value, let place):
            VStack(spacing: 16) {
                Text("\(value)")
                    .font(PiyoTheme.childFont(size: 72, weight: .heavy))
                    .foregroundStyle(PiyoTheme.color(for: .number))
                PlaceValueBlocksView(value: value, highlighted: place)
                Text(place.childTitle)
                    .font(PiyoTheme.bodyFont)
                    .foregroundStyle(PiyoTheme.primaryDeep)
            }

        case .kanaCard(let card, let task):
            kanaContent(card: card, task: task)

        case .kanaWord(let card, let subject):
            KanaWordIllustration(card: card, subject: subject, size: 140, showsWord: true)

        case .alphabetCard(let card, let task, let isUppercase):
            alphabetContent(card: card, task: task, isUppercase: isUppercase)

        case .englishWord(let card, let task):
            englishContent(card: card, task: task)
        }
    }

    // MARK: - 教科ごと

    @ViewBuilder
    private func kanaContent(card: KanaCard, task: CharacterTask) -> some View {
        let subject = question.subject
        switch task {
        case .read:
            // 音声で答えるときだけ文字を見せる（選択肢では答えになってしまうため）。
            if model.answerMode == .voice {
                VStack(spacing: 10) {
                    Text(card.character(for: subject))
                        .font(PiyoTheme.giantFont)
                        .foregroundStyle(PiyoTheme.color(for: subject))
                    Text("こえで よんでみよう")
                        .font(PiyoTheme.captionFont)
                        .foregroundStyle(PiyoTheme.textSoft)
                }
            } else {
                VStack(spacing: 12) {
                    Button {
                        model.speakPrompt()
                    } label: {
                        Image(systemName: "speaker.wave.3.fill")
                            .font(.system(size: 54, weight: .bold))
                            .foregroundStyle(PiyoTheme.color(for: subject))
                            .frame(width: 140, height: 140)
                            .background(Circle().fill(PiyoTheme.color(for: subject).opacity(0.15)))
                    }
                    .buttonStyle(.plain)
                    Text("おとを きいて えらぼう")
                        .font(PiyoTheme.captionFont)
                        .foregroundStyle(PiyoTheme.textSoft)
                }
            }
        case .trace, .write:
            VStack(spacing: 10) {
                KanaWordIllustration(card: card, subject: subject, size: 76, showsWord: true)
                Text(card.character(for: subject))
                    .font(PiyoTheme.childFont(size: 56, weight: .heavy))
                    .foregroundStyle(PiyoTheme.color(for: subject))
            }
        }
    }

    @ViewBuilder
    private func alphabetContent(card: AlphabetCard, task: CharacterTask, isUppercase: Bool) -> some View {
        switch task {
        case .read:
            if model.answerMode == .voice {
                VStack(spacing: 10) {
                    Text(card.character(isUppercase: isUppercase))
                        .font(PiyoTheme.giantFont)
                        .foregroundStyle(PiyoTheme.color(for: .alphabet))
                    Text("こえで よんでみよう")
                        .font(PiyoTheme.captionFont)
                        .foregroundStyle(PiyoTheme.textSoft)
                }
            } else {
                Button {
                    model.speakPrompt()
                } label: {
                    Image(systemName: "speaker.wave.3.fill")
                        .font(.system(size: 54, weight: .bold))
                        .foregroundStyle(PiyoTheme.color(for: .alphabet))
                        .frame(width: 140, height: 140)
                        .background(Circle().fill(PiyoTheme.color(for: .alphabet).opacity(0.15)))
                }
                .buttonStyle(.plain)
            }
        case .trace, .write:
            VStack(spacing: 8) {
                Text(card.character(isUppercase: isUppercase))
                    .font(PiyoTheme.childFont(size: 64, weight: .heavy))
                    .foregroundStyle(PiyoTheme.color(for: .alphabet))
                Text(card.katakanaName)
                    .font(PiyoTheme.captionFont)
                    .foregroundStyle(PiyoTheme.textSoft)
            }
        }
    }

    @ViewBuilder
    private func englishContent(card: EnglishWordCard, task: EnglishWordTask) -> some View {
        switch task {
        case .speakWord:
            VStack(spacing: 10) {
                EnglishWordIllustration(card: card, size: 150, showsText: false)
                Text(card.japanese)
                    .font(PiyoTheme.bodyFont)
                    .foregroundStyle(PiyoTheme.textSoft)
                Text("えいごで いってみよう")
                    .font(PiyoTheme.captionFont)
                    .foregroundStyle(PiyoTheme.textSoft)
            }
        case .wordToPicture, .pictureToWord:
            VStack(spacing: 12) {
                Text(card.english)
                    .font(PiyoTheme.childFont(size: 52, weight: .heavy))
                    .foregroundStyle(PiyoTheme.color(for: .englishWord))
                Button {
                    model.speakPrompt()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "speaker.wave.2.fill")
                        Text("もういちど きく")
                            .font(PiyoTheme.captionFont)
                    }
                    .foregroundStyle(PiyoTheme.textSoft)
                    .padding(.horizontal, 18)
                    .frame(height: 48)
                    .background(Capsule().fill(PiyoTheme.surfaceSunken))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
