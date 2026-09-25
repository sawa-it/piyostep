import SwiftUI
import PiyoCore

/// 学習セッションを開くための要求。
struct SessionRequest: Identifiable {
    let id = UUID()
    let kind: SessionKind
    let subject: Subject?
    let questions: [Question]
}

/// 全画面で出すもの（学習・ごはんタイマー）。
enum FullScreenRoute: Identifiable {
    case session(SessionRequest)
    case meal

    var id: String {
        switch self {
        case .session(let request): return "session-\(request.id)"
        case .meal: return "meal"
        }
    }
}

/// シートで出すもの。
enum SheetRoute: Identifiable {
    case subjectMenu(Subject)
    case collection
    case parentGate
    case parentArea

    var id: String {
        switch self {
        case .subjectMenu(let subject): return "subject-\(subject.rawValue)"
        case .collection: return "collection"
        case .parentGate: return "parentGate"
        case .parentArea: return "parentArea"
        }
    }
}

struct HomeView: View {
    @Environment(AppEnvironment.self) private var environment

    @State private var fullScreenRoute: FullScreenRoute?
    @State private var sheetRoute: SheetRoute?
    @State private var unlockQueue: [UnlockableItem] = []

    /// 幅に応じて列数が変わる。横向きの iPad では 3 列以上になる。
    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 16)]

    var body: some View {
        PiyoLayoutReader { _ in
            ZStack {
                PiyoBackground(tint: PiyoTheme.primary)

                // 横向きでは「あいさつ＋きょうのチャレンジ」と「教科のボタン」を左右に分ける。
                AdaptivePanes(spacing: 22) {
                    VStack(spacing: 22) {
                        header
                        dailyChallengeCard
                    }
                } trailing: {
                    VStack(spacing: 22) {
                        subjectsGrid
                        bottomButtons
                    }
                }
                .padding(20)

                if let item = unlockQueue.first {
                    Color.black.opacity(0.35).ignoresSafeArea()
                    UnlockBanner(item: item) {
                        unlockQueue.removeFirst()
                        environment.haptics.tap()
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(A11yID.home)
        .fullScreenCover(item: $fullScreenRoute) { route in
            fullScreenDestination(route)
                .environment(environment)
        }
        .sheet(item: $sheetRoute) { route in
            sheetDestination(route)
                .environment(environment)
        }
        .onAppear {
            environment.refreshProgress()
            showNextUnlockIfNeeded()
            greet()
        }
        .onChange(of: environment.pendingUnlocks.count) { _, _ in
            showNextUnlockIfNeeded()
        }
    }

    // MARK: - 遷移先

    @ViewBuilder
    private func fullScreenDestination(_ route: FullScreenRoute) -> some View {
        switch route {
        case .session(let request):
            SessionView(request: request)
        case .meal:
            MealRaceContainerView()
        }
    }

    @ViewBuilder
    private func sheetDestination(_ route: SheetRoute) -> some View {
        switch route {
        case .subjectMenu(let subject):
            SubjectMenuView(subject: subject) { skill in
                // シートを閉じ切ってからフルスクリーンを出す。
                // 同じタイミングで閉じる/開くを行うと SwiftUI が取りこぼすことがある。
                sheetRoute = nil
                presentAfterDismiss { startFreePlay(skill: skill) }
            }
        case .collection:
            CollectionView()
        case .parentGate:
            ParentGateView(
                onPass: {
                    environment.markParentGatePassed()
                    sheetRoute = nil
                    presentAfterDismiss { sheetRoute = .parentArea }
                },
                onCancel: { sheetRoute = nil }
            )
        case .parentArea:
            ParentAreaView()
        }
    }

    // MARK: - パーツ

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            // 写真を選んでいればその写真、そうでなければ相棒キャラの絵。
            if environment.avatar.photoFileName != nil {
                AvatarView(
                    avatar: environment.avatar,
                    photoData: environment.avatarImageData(),
                    size: 92
                )
            } else {
                CharacterArtView(character: environment.buddyCharacter, mood: .happy, size: 92)
                    .accessibilityIdentifier(A11yID.avatar)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(environment.appDisplayName)
                    .font(PiyoTheme.captionFont)
                    .foregroundStyle(PiyoTheme.textSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .accessibilityIdentifier(A11yID.homeAppName)

                Text("\(environment.profile?.callName ?? "きみ")、こんにちは！")
                    .font(PiyoTheme.headlineFont)
                    .foregroundStyle(PiyoTheme.text)
                    .minimumScaleFactor(0.6)
                    .lineLimit(2)
                    .accessibilityIdentifier(A11yID.homeGreeting)

                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(PiyoTheme.cheer)
                    Text("\(environment.progress.totalStars)")
                        .font(PiyoTheme.bodyFont)
                        .foregroundStyle(PiyoTheme.text)
                        .accessibilityIdentifier(A11yID.homeStarCount)
                    if let goal = environment.nextUnlockGoal {
                        Text("・つぎは \(goal.name)")
                            .font(PiyoTheme.captionFont)
                            .foregroundStyle(PiyoTheme.textSoft)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
            }

            Spacer()

            Button {
                environment.haptics.tap()
                sheetRoute = .parentGate
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 20, weight: .bold))
                    Text("おうちのひと")
                        .font(PiyoTheme.childFont(size: 11, weight: .semibold))
                }
                .foregroundStyle(PiyoTheme.textSoft)
                .frame(width: 84, height: 60)
                .background(
                    RoundedRectangle(cornerRadius: 16).fill(PiyoTheme.surface.opacity(0.9))
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(A11yID.homeParent)
        }
    }

    private var dailyChallengeCard: some View {
        BigButton(color: PiyoTheme.primary, minHeight: 150, action: startDailyChallenge) {
            HStack(spacing: 18) {
                Image(systemName: "sparkles")
                    .font(.system(size: 46, weight: .bold))
                VStack(alignment: .leading, spacing: 6) {
                    Text("きょうの チャレンジ")
                        .font(PiyoTheme.titleFont)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text("\(environment.settings.dailyGoal.questionCount)もん・\(estimatedMinutes)ふんくらい")
                        .font(PiyoTheme.bodyFont)
                        .opacity(0.92)
                }
                Spacer()
            }
            .padding(.vertical, 14)
        }
        .accessibilityIdentifier(A11yID.homeDailyChallenge)
    }

    private var estimatedMinutes: Int {
        max(3, min(10, environment.settings.dailyGoal.questionCount / 2 + 2))
    }

    private var subjectsGrid: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            // 学習の優先度順（ひらがな・すうじ → とけい・カタカナ → 英語）に並べる。
            ForEach(Subject.orderedByPriority.filter(environment.settings.enabledSubjects.contains)) { subject in
                IconTitleButton(
                    systemImage: icon(for: subject),
                    title: subject.childTitle,
                    color: PiyoTheme.color(for: subject),
                    minHeight: 130
                ) {
                    environment.haptics.tap()
                    environment.speak(subject.childTitle)
                    sheetRoute = .subjectMenu(subject)
                }
                .accessibilityIdentifier("\(A11yID.homeSubject)\(subject.rawValue)")
            }
        }
    }

    private var bottomButtons: some View {
        HStack(spacing: 16) {
            IconTitleButton(
                systemImage: "fork.knife",
                title: "ごはんタイマー",
                color: PiyoTheme.success,
                minHeight: 120
            ) {
                environment.haptics.tap()
                fullScreenRoute = .meal
            }
            .accessibilityIdentifier(A11yID.homeMealTimer)

            IconTitleButton(
                systemImage: "books.vertical.fill",
                title: "ずかん",
                color: PiyoTheme.calm,
                minHeight: 120
            ) {
                environment.haptics.tap()
                sheetRoute = .collection
            }
            .accessibilityIdentifier(A11yID.homeCollection)
        }
    }

    private func icon(for subject: Subject) -> String {
        switch subject {
        case .clock: return "clock.fill"
        case .hiragana: return "character.book.closed.fill"
        case .katakana: return "textformat"
        case .number: return "number"
        case .alphabet: return "a.circle.fill"
        case .englishWord: return "globe"
        }
    }

    // MARK: - 操作

    private func startDailyChallenge() {
        environment.haptics.tap()
        let challenge = environment.makeDailyChallenge()
        guard !challenge.questions.isEmpty else { return }
        fullScreenRoute = .session(
            SessionRequest(kind: .dailyChallenge, subject: nil, questions: challenge.questions)
        )
    }

    private func startFreePlay(skill: Skill) {
        let questions = environment.makeFreePlayQuestions(skill: skill)
        guard !questions.isEmpty else { return }
        fullScreenRoute = .session(
            SessionRequest(kind: .freePlay, subject: skill.subject, questions: questions)
        )
    }

    private func greet() {
        guard let profile = environment.profile else { return }
        environment.speak("\(profile.callName)、こんにちは！ なにで あそぶ？")
    }

    /// 別の表示を閉じ切ってから次を出す。
    private func presentAfterDismiss(_ action: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            action()
        }
    }

    private func showNextUnlockIfNeeded() {
        guard !environment.pendingUnlocks.isEmpty else { return }
        unlockQueue.append(contentsOf: environment.consumePendingUnlocks())
    }
}
