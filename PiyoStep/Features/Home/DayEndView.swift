import SwiftUI
import PiyoCore

/// きょうは おしまい。
///
/// ★や新しく手に入ったものは、問題を解き終えるたびには受け取らず、
/// その日の遊び終わりに ここでまとめて受け取る。
/// 幼児にとって「受け取る画面」が毎回挟まるのは待ち時間でしかないため。
struct DayEndView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.piyoLayout) private var layout

    @State private var summary: DayEndSummary = .empty
    @State private var animateStars = false

    var body: some View {
        ZStack {
            PiyoBackground(tint: PiyoTheme.cheer)
            ConfettiView(isActive: animateStars && summary.didPlay)

            layoutBody
                .padding(CGFloat(layout.sized(24)))
                .piyoContentWidth(layout)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(A11yID.dayEnd)
        .onAppear {
            summary = environment.makeDayEndSummary()
            animateStars = true
            if !summary.newlyUnlocked.isEmpty {
                environment.play(.unlock)
            } else if summary.didPlay {
                environment.play(.star)
            }
            environment.speak(spokenSummary)
        }
    }

    /// 横向きは、キャラクターとまとめを左右に分ける。
    /// 縦に積むと高さが足りず「おやすみ」が画面の外に出てしまう。
    @ViewBuilder
    private var layoutBody: some View {
        if layout.shape.isLandscape {
            HStack(alignment: .center, spacing: CGFloat(layout.spacing)) {
                VStack(spacing: CGFloat(layout.sized(16))) {
                    character
                    message
                }
                .frame(maxWidth: .infinity)

                ScrollView {
                    VStack(spacing: CGFloat(layout.sized(18))) {
                        summaryCard
                        doneButton
                    }
                    .padding(.vertical, 4)
                }
                .frame(maxWidth: .infinity)
            }
        } else {
            ScrollView {
                VStack(spacing: CGFloat(layout.sized(22))) {
                    character
                    message
                    summaryCard
                    doneButton
                }
                .padding(.vertical, 8)
            }
        }
    }

    // MARK: - パーツ

    private var character: some View {
        CharacterArtView(
            character: environment.buddyCharacter,
            mood: summary.didPlay ? .happy : .idle,
            size: CGFloat(layout.artSized(170))
        )
    }

    private var message: some View {
        Text(summary.childMessage)
            .piyoFont(.title)
            .foregroundStyle(PiyoTheme.text)
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.6)
    }

    private var summaryCard: some View {
        PiyoCard {
            VStack(spacing: CGFloat(layout.sized(16))) {
                Text("きょうの ★")
                    .piyoFont(.body)
                    .foregroundStyle(PiyoTheme.textSoft)

                HStack(spacing: 10) {
                    Image(systemName: "star.fill")
                        .font(.system(size: CGFloat(layout.fontSize(38))))
                        .foregroundStyle(PiyoTheme.cheer)
                        .scaleEffect(animateStars ? 1.0 : 0.4)
                        .animation(.spring(response: 0.5, dampingFraction: 0.5), value: animateStars)
                    Text("\(summary.starsEarned)")
                        .piyoFont(size: 48, weight: .heavy)
                        .foregroundStyle(PiyoTheme.text)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("きょうの ★は \(summary.starsEarned)こ")
                .accessibilityIdentifier(A11yID.dayEndStars)

                if summary.didPlay {
                    Text(playedText)
                        .piyoFont(.body)
                        .foregroundStyle(PiyoTheme.textSoft)
                        .multilineTextAlignment(.center)
                } else {
                    Text("きょうは まだ あそんでいないよ")
                        .piyoFont(.body)
                        .foregroundStyle(PiyoTheme.textSoft)
                }

                if !summary.newlyUnlocked.isEmpty {
                    Divider()
                    unlockList
                }

                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .font(.system(size: CGFloat(layout.fontSize(14)), weight: .bold))
                        .foregroundStyle(PiyoTheme.cheer)
                    Text("ぜんぶで \(summary.totalStars)こ")
                        .piyoFont(.caption)
                        .foregroundStyle(PiyoTheme.textSoft)
                }
            }
        }
    }

    /// 新しく手に入ったもの。ここで はじめて見せる。
    private var unlockList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("あたらしく てにいれたよ！")
                .piyoFont(.headline)
                .foregroundStyle(PiyoTheme.primaryDeep)

            ForEach(summary.newlyUnlocked) { item in
                HStack(spacing: 12) {
                    Image(systemName: "gift.fill")
                        .font(.system(size: CGFloat(layout.fontSize(26)), weight: .bold))
                        .foregroundStyle(PiyoTheme.cheer)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(PiyoTheme.cheer.opacity(0.18)))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.category.childTitle)
                            .piyoFont(.caption)
                            .foregroundStyle(PiyoTheme.textSoft)
                        Text(item.name)
                            .piyoFont(.headline)
                            .foregroundStyle(PiyoTheme.text)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    Spacer(minLength: 0)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: PiyoTheme.smallCornerRadius, style: .continuous)
                        .fill(PiyoTheme.surfaceSunken)
                )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("あたらしい \(item.category.childTitle)、\(item.name)")
                .accessibilityIdentifier("\(A11yID.dayEndUnlock)\(item.id)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var doneButton: some View {
        BigButton(color: PiyoTheme.success, action: finishDay) {
            HStack(spacing: 10) {
                Image(systemName: summary.didPlay ? "moon.zzz.fill" : "house.fill")
                Text(summary.didPlay ? "おやすみ！ また あした" : "ホームへ")
                    .piyoFont(.headline)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
        }
        .accessibilityIdentifier(A11yID.dayEndDone)
    }

    // MARK: - 文言

    private var playedText: String {
        var parts: [String] = []
        if summary.questionCount > 0 {
            parts.append("\(summary.questionCount)もん やったよ")
        }
        if summary.mealCount > 0 {
            parts.append("ごはんタイマー \(summary.mealCount)かい")
        }
        return parts.isEmpty ? "きょうも あそんだね" : parts.joined(separator: "・")
    }

    private var spokenSummary: String {
        guard summary.didPlay else { return summary.childMessage }
        var text = "きょうは ほしを \(summary.starsEarned)こ あつめたよ。"
        for item in summary.newlyUnlocked {
            text += " あたらしい \(item.category.childTitle)、\(item.name)を てにいれたよ！"
        }
        text += " " + summary.childMessage
        return text
    }

    // MARK: - 操作

    /// 受け取った。次の「きょうの まとめ」はここから先のぶんになる。
    private func finishDay() {
        environment.haptics.success()
        if summary.didPlay {
            environment.finishDay()
        }
        environment.stopSpeaking()
        dismiss()
    }
}
