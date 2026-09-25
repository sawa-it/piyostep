import SwiftUI
import PiyoCore

/// 教科の中から「なにをするか」を選ぶ画面。
struct SubjectMenuView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss

    let subject: Subject
    var onSelect: (Skill) -> Void

    private var skills: [Skill] {
        subject.skills.filter { skill in
            skill.minimumAge <= (environment.profile?.age ?? 6)
        }
    }

    var body: some View {
        PiyoLayoutReader { metrics in
            ZStack {
                PiyoBackground(tint: PiyoTheme.color(for: subject))

                VStack(spacing: 20) {
                    HStack {
                        BackCircleButton { dismiss() }
                        Spacer()
                        Text(subject.childTitle)
                            .font(PiyoTheme.titleFont)
                            .foregroundStyle(PiyoTheme.text)
                        Spacer()
                        Color.clear.frame(width: 64, height: 64)
                    }

                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(skills) { skill in
                                BigButton(
                                    color: PiyoTheme.color(for: subject),
                                    minHeight: 108,
                                    action: { select(skill) }
                                ) {
                                    HStack(spacing: 16) {
                                        Image(systemName: icon(for: skill))
                                            .font(.system(size: 34, weight: .bold))
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(skill.childTitle)
                                                .font(PiyoTheme.headlineFont)
                                                .minimumScaleFactor(0.6)
                                                .lineLimit(1)
                                            Text(environment.currentLevel(for: skill).childLabel)
                                                .font(PiyoTheme.captionFont)
                                                .opacity(0.9)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 22, weight: .bold))
                                    }
                                    .padding(.vertical, 10)
                                }
                                .accessibilityIdentifier("\(A11yID.subjectSkill)\(skill.rawValue)")
                            }

                            if skills.isEmpty {
                                PiyoCard {
                                    Text("この きょうかは もうすこし おおきくなってから あそべるよ")
                                        .font(PiyoTheme.bodyFont)
                                        .foregroundStyle(PiyoTheme.textSoft)
                                        .multilineTextAlignment(.center)
                                }
                            }
                        }
                        .padding(.bottom, 20)
                    }
                }
                .padding(20)
                .frame(maxWidth: metrics.columnMaxWidth)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(A11yID.subjectMenu)
        .onAppear {
            environment.speak("\(subject.childTitle)、なにで あそぶ？")
        }
    }

    private func select(_ skill: Skill) {
        environment.haptics.tap()
        environment.speak(skill.childTitle)
        onSelect(skill)
    }

    private func icon(for skill: Skill) -> String {
        switch skill {
        case .clockRead: return "questionmark.circle.fill"
        case .clockSet: return "hand.draw.fill"
        case .hiraganaRead, .katakanaRead, .alphabetRead: return "speaker.wave.2.fill"
        case .hiraganaWrite, .katakanaWrite, .alphabetWrite: return "pencil.tip"
        case .hiraganaWord, .katakanaWord: return "photo.fill"
        case .numberCount: return "square.grid.3x3.fill"
        case .numberRead: return "textformat.123"
        case .placeValue: return "square.stack.3d.up.fill"
        case .englishWordRead: return "globe"
        }
    }
}
