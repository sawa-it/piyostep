import SwiftUI
import PiyoCore

/// 学習セッションを開くための要求。
struct SessionRequest: Identifiable {
    let id = UUID()
    let kind: SessionKind
    let subject: Subject?
    let questions: [Question]
}

/// 全画面で出すもの（学習・ごはんタイマー・きょうは おしまい）。
enum FullScreenRoute: Identifiable {
    case session(SessionRequest)
    case meal
    case dayEnd

    var id: String {
        switch self {
        case .session(let request): return "session-\(request.id)"
        case .meal: return "meal"
        case .dayEnd: return "dayEnd"
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
    @Environment(\.piyoLayout) private var layout

    @State private var fullScreenRoute: FullScreenRoute?
    @State private var sheetRoute: SheetRoute?
    /// 広告を閉じたら保護者画面を開く、という待ち状態
    @State private var opensParentAreaAfterAd = false

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: CGFloat(layout.sized(16))),
            count: layout.subjectColumns
        )
    }

    var body: some View {
        ZStack {
            PiyoBackground(tint: PiyoTheme.primary)

            ScrollView {
                layoutBody
                    .padding(CGFloat(layout.spacing))
                    .piyoContentWidth(layout)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(A11yID.home)
        .fullScreenCover(item: $fullScreenRoute) { route in
            // 出した先は大きさが違う（シートは一回り小さい）ので、そこで測り直す。
            PiyoLayoutReader {
                fullScreenDestination(route)
                    .environment(environment)
            }
        }
        .sheet(item: $sheetRoute) { route in
            PiyoLayoutReader {
                sheetDestination(route)
                    .environment(environment)
            }
        }
        .onAppear {
            environment.refreshProgress()
            greet()
        }
        .onChange(of: environment.isShowingParentAd) { _, isShowing in
            guard !isShowing, opensParentAreaAfterAd else { return }
            opensParentAreaAfterAd = false
            presentAfterDismiss { sheetRoute = .parentArea }
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
        case .dayEnd:
            DayEndView()
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
                    sheetRoute = nil
                    presentAfterDismiss { openParentArea() }
                },
                onCancel: { sheetRoute = nil }
            )
        case .parentArea:
            ParentAreaView()
        }
    }

    // MARK: - 並べ方

    /// 横向きは左右に分ける。縦に積むと、高さ 390pt の iPhone 横持ちで
    /// 「きょうの チャレンジ」より下が画面の外に出てしまう。
    @ViewBuilder
    private var layoutBody: some View {
        if layout.shape.isLandscape {
            HStack(alignment: .top, spacing: CGFloat(layout.spacing)) {
                VStack(spacing: CGFloat(layout.spacing)) {
                    header
                    dailyChallengeCard
                    bottomButtons
                }
                .frame(maxWidth: .infinity)

                subjectsGrid
                    .frame(maxWidth: .infinity)
            }
        } else {
            VStack(spacing: CGFloat(layout.spacing)) {
                header
                dailyChallengeCard
                subjectsGrid
                bottomButtons
            }
        }
    }

    // MARK: - パーツ

    private var header: some View {
        headerContent
            .padding(CGFloat(layout.sized(16)))
            .background(
                RoundedRectangle(cornerRadius: PiyoTheme.cornerRadius, style: .continuous)
                    .fill(PiyoTheme.surface.opacity(0.75))
            )
            .overlay(
                RoundedRectangle(cornerRadius: PiyoTheme.cornerRadius, style: .continuous)
                    .stroke(PiyoTheme.outline.opacity(0.35), lineWidth: 1)
            )
    }

    private var headerContent: some View {
        HStack(alignment: .center, spacing: 12) {
            // 写真を選んでいればその写真、そうでなければ相棒キャラの絵。
            if environment.avatar.photoFileName != nil {
                AvatarView(
                    avatar: environment.avatar,
                    photoData: environment.avatarImageData(),
                    size: CGFloat(layout.sized(84))
                )
            } else {
                CharacterArtView(
                    character: environment.buddyCharacter,
                    mood: .happy,
                    size: CGFloat(layout.sized(84))
                )
                    .accessibilityIdentifier(A11yID.avatar)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(environment.appDisplayName)
                    .piyoFont(size: 13, weight: .semibold)
                    .foregroundStyle(PiyoTheme.primaryDeep)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(PiyoTheme.primary.opacity(0.14)))
                    .accessibilityIdentifier(A11yID.homeAppName)

                Text("\(environment.profile?.callName ?? "きみ")、こんにちは！")
                    .piyoFont(.headline)
                    .foregroundStyle(PiyoTheme.text)
                    .minimumScaleFactor(0.6)
                    .lineLimit(2)
                    .accessibilityIdentifier(A11yID.homeGreeting)

                HStack(spacing: 8) {
                    HStack(spacing: 5) {
                        Image(systemName: "star.fill")
                            .font(.system(size: CGFloat(layout.fontSize(15)), weight: .bold))
                            .foregroundStyle(PiyoTheme.cheer)
                        Text("\(environment.progress.totalStars)")
                            .piyoFont(size: 17, weight: .heavy)
                            .foregroundStyle(PiyoTheme.text)
                            .accessibilityIdentifier(A11yID.homeStarCount)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(PiyoTheme.cheer.opacity(0.18)))

                    if let goal = environment.nextUnlockGoal {
                        Text("つぎは \(goal.name)")
                            .piyoFont(.caption)
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
                VStack(spacing: 3) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: CGFloat(layout.fontSize(19)), weight: .bold))
                    Text("おうちのひと")
                        .piyoFont(size: 11, weight: .semibold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .foregroundStyle(PiyoTheme.textSoft)
                .frame(width: CGFloat(layout.sized(82)), height: CGFloat(layout.sized(60)))
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(PiyoTheme.surfaceSunken)
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(A11yID.homeParent)
        }
    }

    private var dailyChallengeCard: some View {
        BigButton(color: PiyoTheme.primary, minHeight: CGFloat(layout.sized(140)), action: startDailyChallenge) {
            HStack(spacing: 18) {
                Image(systemName: "sparkles")
                    .font(.system(size: 46, weight: .bold))
                VStack(alignment: .leading, spacing: 6) {
                    Text("きょうの チャレンジ")
                        .piyoFont(.title)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text("\(environment.settings.dailyGoal.questionCount)もん・\(estimatedMinutes)ふんくらい")
                        .piyoFont(.body)
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
        LazyVGrid(columns: columns, spacing: CGFloat(layout.sized(16))) {
            ForEach(Array(environment.settings.enabledSubjects).sorted(by: { $0.rawValue < $1.rawValue })) { subject in
                IconTitleButton(
                    systemImage: icon(for: subject),
                    title: subject.childTitle,
                    color: PiyoTheme.color(for: subject),
                    minHeight: CGFloat(layout.sized(126))
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
        VStack(spacing: CGFloat(layout.sized(16))) {
            HStack(spacing: CGFloat(layout.sized(16))) {
                IconTitleButton(
                    systemImage: "fork.knife",
                    title: "ごはんタイマー",
                    color: PiyoTheme.success,
                    minHeight: CGFloat(layout.sized(116))
                ) {
                    environment.haptics.tap()
                    fullScreenRoute = .meal
                }
                .accessibilityIdentifier(A11yID.homeMealTimer)

                IconTitleButton(
                    systemImage: "books.vertical.fill",
                    title: "ずかん",
                    color: PiyoTheme.calm,
                    minHeight: CGFloat(layout.sized(116))
                ) {
                    environment.haptics.tap()
                    sheetRoute = .collection
                }
                .accessibilityIdentifier(A11yID.homeCollection)
            }

            dayEndButton
        }
    }

    /// その日の遊び終わり。★と新しく手に入ったものを、ここでまとめて受け取る。
    /// 問題を解き終えるたびに受け取り画面を挟まないぶん、ここは目立たせる。
    private var dayEndButton: some View {
        BigButton(color: PiyoTheme.primaryDeep, minHeight: CGFloat(layout.sized(96)), action: openDayEnd) {
            HStack(spacing: 14) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: CGFloat(layout.fontSize(30)), weight: .bold))
                VStack(alignment: .leading, spacing: 2) {
                    Text("きょうは おしまい")
                        .piyoFont(.headline)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text("★と あたらしい ものを うけとる")
                        .piyoFont(size: 13, weight: .semibold)
                        .opacity(0.9)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Spacer(minLength: 0)
                Image(systemName: "gift.fill")
                    .font(.system(size: CGFloat(layout.fontSize(26)), weight: .bold))
                    .foregroundStyle(PiyoTheme.cheer)
            }
            .padding(.vertical, 8)
        }
        .accessibilityIdentifier(A11yID.homeDayEnd)
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

    /// ゲートを通ったあとで保護者画面を開く。
    /// 広告はここでだけ出す。ゲートの向こう側なので、見るのは必ず大人になる。
    ///
    /// 広告はルートに重ねて出すので、シートを先に開くとその下に隠れてしまう。
    /// 「ゲート → 広告 → 保護者画面」の順に、ひとつずつ出す。
    private func openParentArea() {
        guard environment.adPresenter.shouldPresentParentAd(adsRemoved: environment.settings.adsRemoved) else {
            sheetRoute = .parentArea
            return
        }
        environment.adPresenter.markParentAdPresented()
        opensParentAreaAfterAd = true
        environment.isShowingParentAd = true
    }

    private func openDayEnd() {
        environment.haptics.tap()
        fullScreenRoute = .dayEnd
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
}
