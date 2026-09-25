import SwiftUI
import PiyoCore

/// 教科の中から「なにをするか」を選ぶ画面。
struct SubjectMenuView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.piyoLayout) private var layout

    let subject: Subject
    var onSelect: (Skill) -> Void

    private var skills: [Skill] {
        subject.skills.filter { skill in
            skill.minimumAge <= (environment.profile?.age ?? 6)
        }
    }

    var body: some View {
        ZStack {
            PiyoBackground(tint: PiyoTheme.color(for: subject))

            VStack(spacing: 20) {
                HStack {
                    BackCircleButton { dismiss() }
                    Spacer()
                    Text(subject.childTitle)
                        .piyoFont(.title)
                        .foregroundStyle(PiyoTheme.text)
                    Spacer()
                    Color.clear.frame(width: 64, height: 64)
                }

                ScrollView {
                    // 横向きは縦に積むと 2 つしか見えないので、2 列にする。
                    LazyVGrid(
                        columns: Array(
                            repeating: GridItem(.flexible(), spacing: CGFloat(layout.sized(16))),
                            count: layout.shape.isLandscape ? 2 : 1
                        ),
                        spacing: CGFloat(layout.sized(16))
                    ) {
                        ForEach(skills) { skill in
                            BigButton(
                                color: PiyoTheme.color(for: subject),
                                minHeight: CGFloat(layout.sized(104)),
                                action: { select(skill) }
                            ) {
                                HStack(spacing: 16) {
                                    Image(systemName: icon(for: skill))
                                        .font(.system(size: 34, weight: .bold))
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(skill.childTitle)
                                            .piyoFont(.headline)
                                            .minimumScaleFactor(0.6)
                                            .lineLimit(1)
                                        Text(environment.currentLevel(for: skill).childLabel)
                                            .piyoFont(.caption)
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
                                    .piyoFont(.body)
                                    .foregroundStyle(PiyoTheme.textSoft)
                                    .multilineTextAlignment(.center)
                            }
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
            .padding(CGFloat(layout.spacing))
            .piyoContentWidth(layout)
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
