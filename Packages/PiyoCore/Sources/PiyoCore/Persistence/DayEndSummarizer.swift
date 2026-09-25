import Foundation

/// 「きょうは おしまい」の画面で見せる、その日のまとめ。
///
/// ★やアンロックは 1 回ごとに受け取らず、その日の遊び終わりにまとめて受け取る。
/// 問題を解き終えるたびに結果画面を挟むと、幼児には「まだ？」の待ち時間になるため。
public struct DayEndSummary: Equatable, Sendable {
    /// この期間に手に入れた★
    public let starsEarned: Int
    /// この期間に答えた問題数（聞き取れなかった音声は含まない）
    public let questionCount: Int
    public let correctCount: Int
    /// 学習セッションの回数（ごはんタイマーは含まない）
    public let sessionCount: Int
    /// ごはんタイマーの回数
    public let mealCount: Int
    /// まだ見せていない、新しく解放されたもの
    public let newlyUnlocked: [UnlockableItem]
    /// 通算の★
    public let totalStars: Int

    public init(
        starsEarned: Int,
        questionCount: Int,
        correctCount: Int,
        sessionCount: Int,
        mealCount: Int,
        newlyUnlocked: [UnlockableItem],
        totalStars: Int
    ) {
        self.starsEarned = starsEarned
        self.questionCount = questionCount
        self.correctCount = correctCount
        self.sessionCount = sessionCount
        self.mealCount = mealCount
        self.newlyUnlocked = newlyUnlocked
        self.totalStars = totalStars
    }

    /// その日なにかしら遊んだか。
    public var didPlay: Bool {
        sessionCount > 0 || mealCount > 0 || starsEarned > 0
    }

    /// 子どもに見せる、ねぎらいのことば。点数で評価しない。
    public var childMessage: String {
        guard didPlay else { return "また あそぼうね！" }
        if !newlyUnlocked.isEmpty {
            return "きょうも がんばったね！ あたらしい ものが ふえたよ！"
        }
        return "きょうも がんばったね！ また あした あそぼう！"
    }

    public static let empty = DayEndSummary(
        starsEarned: 0,
        questionCount: 0,
        correctCount: 0,
        sessionCount: 0,
        mealCount: 0,
        newlyUnlocked: [],
        totalStars: 0
    )
}

/// 履歴から「その日のまとめ」を計算する。
public struct DayEndSummarizer {
    private let calendar: Calendar

    public init(calendar: Calendar = .piyo) {
        self.calendar = calendar
    }

    /// - Parameters:
    ///   - lastDayEnd: 前回「おしまい」をした時刻。まだなら nil。
    ///   - now: いま。
    ///
    /// ★や問題数は「きょう（前回のおしまい以降）」だけを数える。
    /// アンロックは前回のおしまい以降ぜんぶを対象にする。おしまいを押さずに
    /// 日をまたいでも、手に入れたものを見せそびれないようにするため。
    public func summarize(
        sessions: [SessionRecord],
        attempts: [AttemptRecord],
        unlocks: [UnlockRecord],
        lastDayEnd: Date?,
        now: Date
    ) -> DayEndSummary {
        let startOfToday = calendar.startOfDay(for: now)

        // 「おしまい」をした瞬間そのものは受け取り済みなので、その時刻より後だけを数える。
        // 日付の区切りは、その日の 0 時ちょうども含める。
        func isInWindow(_ date: Date, since lastEnd: Date?) -> Bool {
            guard date <= now else { return false }
            if let lastEnd, lastEnd >= startOfToday {
                return date > lastEnd
            }
            return date >= startOfToday
        }
        func isAfterLastEnd(_ date: Date) -> Bool {
            guard date <= now else { return false }
            if let lastDayEnd {
                return date > lastDayEnd
            }
            return date >= startOfToday
        }

        let todaySessions = sessions.filter { isInWindow($0.startedAt, since: lastDayEnd) }
        let todayAttempts = attempts.filter {
            isInWindow($0.createdAt, since: lastDayEnd) && $0.judgement.countsTowardMastery
        }
        let newUnlocks = unlocks
            .filter { isAfterLastEnd($0.unlockedAt) }
            .sorted { $0.unlockedAt < $1.unlockedAt }
            .compactMap { UnlockCatalog.item(id: $0.itemID) }

        return DayEndSummary(
            starsEarned: todaySessions.reduce(0) { $0 + $1.starsEarned },
            questionCount: todayAttempts.count,
            correctCount: todayAttempts.filter { $0.judgement.isCorrect }.count,
            sessionCount: todaySessions.filter { $0.kind != .mealTimer }.count,
            mealCount: todaySessions.filter { $0.kind == .mealTimer }.count,
            newlyUnlocked: newUnlocks,
            totalStars: sessions.reduce(0) { $0 + $1.starsEarned }
        )
    }
}
