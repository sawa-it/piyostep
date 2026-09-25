import Foundation

/// 1 日分の学習サマリー。
public struct DailyStat: Equatable, Sendable, Identifiable {
    public let date: Date
    public let questionCount: Int
    public let correctCount: Int
    public let studySeconds: TimeInterval
    public let starsEarned: Int

    public var id: Date { date }

    public init(date: Date, questionCount: Int, correctCount: Int, studySeconds: TimeInterval, starsEarned: Int) {
        self.date = date
        self.questionCount = questionCount
        self.correctCount = correctCount
        self.studySeconds = studySeconds
        self.starsEarned = starsEarned
    }

    public var accuracy: Double? {
        questionCount > 0 ? Double(correctCount) / Double(questionCount) : nil
    }

    public var studyMinutes: Int {
        Int((studySeconds / 60).rounded())
    }

    public var didStudy: Bool { questionCount > 0 || studySeconds > 0 }
}

/// 教科ごとのサマリー。
public struct SubjectStat: Equatable, Sendable, Identifiable {
    public let subject: Subject
    public let attempts: Int
    public let correctCount: Int
    public let mastery: Double
    public let lastPracticedAt: Date?

    public var id: String { subject.rawValue }

    public init(subject: Subject, attempts: Int, correctCount: Int, mastery: Double, lastPracticedAt: Date?) {
        self.subject = subject
        self.attempts = attempts
        self.correctCount = correctCount
        self.mastery = mastery
        self.lastPracticedAt = lastPracticedAt
    }

    public var accuracy: Double? {
        attempts > 0 ? Double(correctCount) / Double(attempts) : nil
    }
}

/// 最近の学習内容。
public struct RecentActivity: Equatable, Sendable, Identifiable {
    public let id: UUID
    public let date: Date
    public let title: String
    public let detail: String

    public init(id: UUID = UUID(), date: Date, title: String, detail: String) {
        self.id = id
        self.date = date
        self.title = title
        self.detail = detail
    }
}

/// 保護者画面に出す集計結果。
public struct ProgressSummary: Equatable, Sendable {
    public let totalQuestions: Int
    public let totalCorrect: Int
    public let totalStars: Int
    public let learningDays: Int
    public let challengesCompleted: Int
    public let mealsCompleted: Int
    public let totalStudySeconds: TimeInterval
    public let dailyStats: [DailyStat]
    public let subjectStats: [SubjectStat]
    public let strengths: [Subject]
    public let weaknesses: [Subject]
    public let recentActivities: [RecentActivity]

    public init(
        totalQuestions: Int,
        totalCorrect: Int,
        totalStars: Int,
        learningDays: Int,
        challengesCompleted: Int,
        mealsCompleted: Int,
        totalStudySeconds: TimeInterval,
        dailyStats: [DailyStat],
        subjectStats: [SubjectStat],
        strengths: [Subject],
        weaknesses: [Subject],
        recentActivities: [RecentActivity]
    ) {
        self.totalQuestions = totalQuestions
        self.totalCorrect = totalCorrect
        self.totalStars = totalStars
        self.learningDays = learningDays
        self.challengesCompleted = challengesCompleted
        self.mealsCompleted = mealsCompleted
        self.totalStudySeconds = totalStudySeconds
        self.dailyStats = dailyStats
        self.subjectStats = subjectStats
        self.strengths = strengths
        self.weaknesses = weaknesses
        self.recentActivities = recentActivities
    }

    public var overallAccuracy: Double? {
        totalQuestions > 0 ? Double(totalCorrect) / Double(totalQuestions) : nil
    }

    public static let empty = ProgressSummary(
        totalQuestions: 0,
        totalCorrect: 0,
        totalStars: 0,
        learningDays: 0,
        challengesCompleted: 0,
        mealsCompleted: 0,
        totalStudySeconds: 0,
        dailyStats: [],
        subjectStats: [],
        strengths: [],
        weaknesses: [],
        recentActivities: []
    )
}

/// 履歴から保護者向けサマリーを計算する。
public struct ProgressAggregator {
    private let calendar: Calendar
    private let estimator: MasteryEstimator

    public init(calendar: Calendar = .piyo, estimator: MasteryEstimator = MasteryEstimator()) {
        self.calendar = calendar
        self.estimator = estimator
    }

    /// 直近 `dayCount` 日分の日別統計（学習していない日も 0 で埋める）。
    public func dailyStats(
        attempts: [AttemptRecord],
        sessions: [SessionRecord],
        now: Date,
        dayCount: Int = 7
    ) -> [DailyStat] {
        let today = calendar.startOfDay(for: now)
        var result: [DailyStat] = []
        for offset in stride(from: dayCount - 1, through: 0, by: -1) {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let dayAttempts = attempts.filter {
                calendar.isDate($0.createdAt, inSameDayAs: day) && $0.judgement.countsTowardMastery
            }
            let daySessions = sessions.filter { calendar.isDate($0.startedAt, inSameDayAs: day) }
            result.append(
                DailyStat(
                    date: day,
                    questionCount: dayAttempts.count,
                    correctCount: dayAttempts.filter { $0.judgement.isCorrect }.count,
                    studySeconds: daySessions.reduce(0) { $0 + $1.duration },
                    starsEarned: daySessions.reduce(0) { $0 + $1.starsEarned }
                )
            )
        }
        return result
    }

    /// 教科ごとの統計。
    public func subjectStats(
        attempts: [AttemptRecord],
        snapshots: [Skill: MasterySnapshot]
    ) -> [SubjectStat] {
        let subjectMastery = estimator.subjectMastery(from: snapshots)
        // 複数 return を含むクロージャなので戻り値型を明示しておく。
        return Subject.allCases.compactMap { subject -> SubjectStat? in
            let relevant = attempts.filter { $0.skill.subject == subject && $0.judgement.countsTowardMastery }
            let lastPracticed = snapshots
                .filter { $0.key.subject == subject }
                .compactMap { $0.value.lastPracticedAt }
                .max()
            guard !relevant.isEmpty || lastPracticed != nil else { return nil }
            return SubjectStat(
                subject: subject,
                attempts: relevant.count,
                correctCount: relevant.filter { $0.judgement.isCorrect }.count,
                mastery: subjectMastery[subject] ?? 0,
                lastPracticedAt: lastPracticed
            )
        }
    }

    /// 学習した日数（ユニークな日付の数）。
    public func learningDays(attempts: [AttemptRecord], sessions: [SessionRecord]) -> Int {
        var days = Set<Date>()
        for attempt in attempts {
            days.insert(calendar.startOfDay(for: attempt.createdAt))
        }
        for session in sessions {
            days.insert(calendar.startOfDay(for: session.startedAt))
        }
        return days.count
    }

    /// 最近の学習内容。
    public func recentActivities(
        sessions: [SessionRecord],
        mealSessions: [MealSessionRecord],
        limit: Int = 10
    ) -> [RecentActivity] {
        var items: [RecentActivity] = sessions.map { session in
            let title: String
            switch session.kind {
            case .dailyChallenge: title = "きょうのチャレンジ"
            case .freePlay: title = session.subject?.parentTitle ?? "じゆうにあそぶ"
            case .mealTimer: title = "ごはんタイマー"
            }
            let accuracyText = session.questionCount > 0
                ? "\(session.correctCount)/\(session.questionCount)問正解"
                : "—"
            return RecentActivity(
                date: session.startedAt,
                title: title,
                detail: "\(accuracyText)・★\(session.starsEarned)"
            )
        }
        items.append(contentsOf: mealSessions.map { meal in
            let characterName = CharacterCatalog.character(id: meal.characterID)?.name ?? "キャラクター"
            let minutes = Int((meal.actualDuration / 60).rounded())
            return RecentActivity(
                date: meal.startedAt,
                title: "ごはんタイマー",
                detail: "\(characterName)と \(minutes)分"
            )
        })
        return Array(items.sorted { $0.date > $1.date }.prefix(limit))
    }

    /// 全体サマリー。
    public func summarize(
        attempts: [AttemptRecord],
        sessions: [SessionRecord],
        mealSessions: [MealSessionRecord],
        snapshots: [Skill: MasterySnapshot],
        now: Date,
        dayCount: Int = 7
    ) -> ProgressSummary {
        let counted = attempts.filter { $0.judgement.countsTowardMastery }
        let stats = subjectStats(attempts: attempts, snapshots: snapshots)
        let ranked = stats.filter { $0.attempts > 0 }.sorted { $0.mastery > $1.mastery }
        // 教科が少ないときに「全部が得意」にならないよう、上位・下位の数を抑える。
        let sideCount = min(2, max(1, ranked.count / 2))
        let strengths = ranked.isEmpty ? [] : Array(ranked.prefix(sideCount).map(\.subject))
        let weaknesses = ranked.isEmpty
            ? []
            : Array(ranked.suffix(sideCount).map(\.subject).filter { !strengths.contains($0) })

        return ProgressSummary(
            totalQuestions: counted.count,
            totalCorrect: counted.filter { $0.judgement.isCorrect }.count,
            totalStars: sessions.reduce(0) { $0 + $1.starsEarned },
            learningDays: learningDays(attempts: attempts, sessions: sessions),
            challengesCompleted: sessions.filter { $0.kind == .dailyChallenge }.count,
            mealsCompleted: mealSessions.count,
            totalStudySeconds: sessions.reduce(0) { $0 + $1.duration },
            dailyStats: dailyStats(attempts: attempts, sessions: sessions, now: now, dayCount: dayCount),
            subjectStats: stats,
            strengths: strengths,
            weaknesses: weaknesses,
            recentActivities: recentActivities(sessions: sessions, mealSessions: mealSessions)
        )
    }

    /// アンロック判定に使う進捗へ変換する。
    public func unlockProgress(from summary: ProgressSummary, snapshots: [Skill: MasterySnapshot]) -> UnlockProgress {
        UnlockProgress(
            totalStars: summary.totalStars,
            learningDays: summary.learningDays,
            mealsCompleted: summary.mealsCompleted,
            challengesCompleted: summary.challengesCompleted,
            subjectMastery: estimator.subjectMastery(from: snapshots)
        )
    }
}
