import SwiftUI
import PiyoCore

/// ごはんの乗ったお皿。`fullness` が 1.0 で満杯、0.0 で完食。
struct PlateView: View {
    var fullness: Double
    var tablewareArtKey: String = "white"
    var size: CGFloat = 150
    var foodName: String = "ごはん"

    private var clampedFullness: Double {
        min(max(fullness, 0), 1)
    }

    private var plateColor: Color {
        switch tablewareArtKey {
        case "flower": return Color(red: 1.0, green: 0.90, blue: 0.94)
        case "star": return Color(red: 0.92, green: 0.95, blue: 1.0)
        case "rainbow": return Color(red: 0.95, green: 1.0, blue: 0.93)
        default: return .white
        }
    }

    var body: some View {
        ZStack {
            // お皿
            Ellipse()
                .fill(plateColor)
                .frame(width: size, height: size * 0.62)
                .shadow(color: .black.opacity(0.10), radius: 8, y: 5)
            Ellipse()
                .stroke(PiyoTheme.outline, lineWidth: 3)
                .frame(width: size, height: size * 0.62)
            Ellipse()
                .stroke(decorationColor, lineWidth: 5)
                .frame(width: size * 0.78, height: size * 0.48)

            // ごはん
            if clampedFullness > 0.02 {
                Ellipse()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 1.0, green: 0.87, blue: 0.62), Color(red: 0.96, green: 0.72, blue: 0.40)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(
                        width: size * 0.62 * clampedFullness.squareRoot(),
                        height: size * 0.38 * clampedFullness.squareRoot()
                    )
                    .offset(y: -size * 0.02)
                    .animation(.easeInOut(duration: 0.5), value: clampedFullness)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: size * 0.26))
                    .foregroundStyle(PiyoTheme.success)
                    .transition(.scale)
            }
        }
        .frame(width: size, height: size * 0.7)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(clampedFullness <= 0.02 ? "\(foodName)を たべおわった" : "\(foodName)が のこっている")
    }

    private var decorationColor: Color {
        switch tablewareArtKey {
        case "flower": return Color.pink.opacity(0.6)
        case "star": return PiyoTheme.calm.opacity(0.7)
        case "rainbow": return PiyoTheme.cheer.opacity(0.8)
        default: return PiyoTheme.outline.opacity(0.7)
        }
    }
}

/// キャラクターがどこまで食べ進んだかだけを見せる帯。
///
/// 子どもの進み具合は自分のお皿で分かるので、帯はキャラクターの分だけにして
/// 「追いかける相手」がはっきり見えるようにする。
struct CharacterProgressBar: View {
    var progress: Double
    var character: CharacterDefinition

    private var clamped: Double { min(max(progress, 0), 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(character.name)
                .font(PiyoTheme.captionFont)
                .foregroundStyle(PiyoTheme.textSoft)
            GeometryReader { proxy in
                let width = max(0, proxy.size.width)
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(PiyoTheme.surfaceSunken)
                    Capsule()
                        .fill(PiyoTheme.color(hex: character.accentColorHex).opacity(0.35))
                        .frame(width: width * clamped)
                    CharacterArtView(character: character, mood: .eating, size: 52, isAnimated: false)
                        .offset(x: max(0, min(width - 52, width * clamped - 26)))
                    Image(systemName: "flag.checkered")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(PiyoTheme.textSoft)
                        .offset(x: max(0, width - 24))
                }
                .animation(.easeInOut(duration: 0.4), value: clamped)
            }
            .frame(height: 56)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier(A11yID.mealCharacterProgress)
        .accessibilityLabel("\(character.name)は \(Int(clamped * 100))パーセント")
    }
}

/// 茶碗とごはん。経過に合わせてごはんの山が小さくなる。
///
/// 器の下端が枠の下端にそろうように置き、ごはんは器のふちの上に乗せる。
struct RiceBowlView: View {
    var fullness: Double
    var size: CGFloat = 150
    var foodName: String = "ごはん"

    private var clamped: Double { min(max(fullness, 0), 1) }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.clear
                .frame(width: size, height: size * 0.78)

            // ごはんの山。器のふちに乗せ、減るほど低くなる。
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.93, blue: 0.74),
                            Color(red: 0.95, green: 0.80, blue: 0.53)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(Ellipse().stroke(Color(red: 0.82, green: 0.66, blue: 0.42), lineWidth: 2))
                .frame(width: size * 0.72, height: size * 0.26 * clamped)
                .offset(y: -size * 0.47)
                .opacity(clamped > 0.02 ? 1 : 0)
                .animation(.easeInOut(duration: 0.5), value: clamped)

            BowlShape()
                .fill(Color.white)
                .overlay(BowlShape().stroke(PiyoTheme.outline, lineWidth: 3))
                .frame(width: size, height: size * 0.5)

            if clamped <= 0.02 {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: size * 0.22))
                    .foregroundStyle(PiyoTheme.success)
                    .offset(y: -size * 0.58)
                    .transition(.scale)
            }
        }
        .frame(width: size, height: size * 0.78, alignment: .bottom)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(clamped <= 0.02 ? "\(foodName)を たべおわった" : "\(foodName)が のこっている")
    }
}

/// 下にすぼまった茶碗の形。
struct BowlShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let inset = rect.width * 0.18
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - inset, y: rect.maxY),
            control: CGPoint(x: rect.maxX - inset * 0.3, y: rect.maxY * 0.75)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + inset, y: rect.maxY),
            control: CGPoint(x: rect.midX, y: rect.maxY + rect.height * 0.22)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.minY),
            control: CGPoint(x: rect.minX + inset * 0.3, y: rect.maxY * 0.75)
        )
        path.closeSubpath()
        return path
    }
}

/// 食事中のキャラクター。手におはしとスプーンを持ち、目の前の茶碗から食べる。
///
/// いまの活動（もぐもぐ・ひとやすみ・おうえん）で動きが変わる。
struct MealSceneView: View {
    var character: CharacterDefinition
    var activity: CharacterActivity
    var bowlFullness: Double
    var message: String
    var size: CGFloat = 220

    @State private var animates = false

    private var mood: CharacterMood {
        switch activity {
        case .eating: return .eating
        case .resting: return .resting
        case .cheering, .finished: return .cheering
        }
    }

    /// 動きの周期。急いでいるときほど速い。
    private var cycle: Double {
        switch activity {
        case .eating: return 0.45
        case .cheering: return 0.3
        case .resting: return 1.4
        case .finished: return 1.0
        }
    }

    private var bodyOffset: CGFloat {
        switch activity {
        case .eating: return animates ? -6 : 6
        case .cheering: return animates ? -16 : 0
        case .resting: return animates ? 3 : -3
        case .finished: return 0
        }
    }

    private var tilt: Double {
        switch activity {
        case .eating: return animates ? 4 : -4
        case .cheering: return animates ? -6 : 6
        case .resting: return animates ? -3 : 3
        case .finished: return 0
        }
    }

    /// おはしを持つ手が口へ運ばれる量。
    private var chopstickLift: CGFloat {
        activity == .eating ? (animates ? -size * 0.16 : 0) : 0
    }

    var body: some View {
        VStack(spacing: 10) {
            speechBubble

            ZStack {
                // からだ
                CharacterArtView(character: character, mood: mood, size: size, isAnimated: false)
                    .rotationEffect(.degrees(tilt))
                    .offset(y: bodyOffset)

                decoration

                // 両手と食器。からだより手前、茶碗より奥。
                hand(isLeading: true)
                hand(isLeading: false)

                // 目の前の茶碗。顔にかからないよう、からだの下半分に置く。
                RiceBowlView(
                    fullness: bowlFullness,
                    size: size * 0.44,
                    foodName: character.favoriteFood
                )
                .offset(y: size * 0.40)
            }
            .frame(width: size * 1.5, height: size * 1.1)
            .background(alignment: .bottom) {
                // テーブル
                Capsule()
                    .fill(PiyoTheme.surfaceSunken)
                    .frame(width: size * 1.05, height: size * 0.045)
                    .offset(y: -size * 0.1)
            }

            Text(activity.childCaption)
                .font(PiyoTheme.bodyFont)
                .foregroundStyle(PiyoTheme.primaryDeep)
        }
        .onAppear(perform: restartAnimation)
        .onChange(of: activity) { _, _ in restartAnimation() }
    }

    /// 手と食器。先行する手（おはし）は食べるたびに口へ上がる。
    private func hand(isLeading: Bool) -> some View {
        let direction: CGFloat = isLeading ? -1 : 1
        return ZStack {
            // 食器
            Capsule()
                .fill(PiyoTheme.outline)
                .frame(width: size * 0.035, height: size * 0.3)
                .rotationEffect(.degrees(isLeading ? -28 : 28))
                .offset(x: direction * size * 0.05, y: -size * 0.12)
            if !isLeading {
                // スプーンのすくう部分
                Ellipse()
                    .fill(PiyoTheme.outline)
                    .frame(width: size * 0.09, height: size * 0.07)
                    .offset(x: size * 0.12, y: -size * 0.24)
            }
            // て
            Circle()
                .fill(PiyoTheme.color(hex: character.primaryColorHex))
                .overlay(Circle().stroke(PiyoTheme.outline.opacity(0.5), lineWidth: 2))
                .frame(width: size * 0.13)
        }
        .offset(
            x: direction * size * 0.36,
            y: size * 0.18 + (isLeading ? chopstickLift : 0)
        )
    }

    private var speechBubble: some View {
        Text(message)
            .font(PiyoTheme.bodyFont)
            .foregroundStyle(PiyoTheme.text)
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.6)
            .lineLimit(2)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: PiyoTheme.smallCornerRadius, style: .continuous)
                    .fill(PiyoTheme.surface)
            )
            .id(message)
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.25), value: message)
    }

    /// 活動ごとの飾り。もぐもぐ中はごはんつぶが舞い、休むと zzz が出る。
    @ViewBuilder
    private var decoration: some View {
        switch activity {
        case .eating:
            ForEach(0 ..< 3, id: \.self) { index in
                Ellipse()
                    .fill(Color(red: 1.0, green: 0.98, blue: 0.94))
                    .frame(width: 12, height: 9)
                    .offset(
                        x: CGFloat(index - 1) * 26,
                        y: animates ? -size * 0.38 : -size * 0.14
                    )
                    .opacity(animates ? 0 : 0.9)
            }
        case .resting:
            Text("zzz")
                .font(PiyoTheme.childFont(size: 24, weight: .heavy))
                .foregroundStyle(PiyoTheme.calm)
                .offset(x: size * 0.3, y: animates ? -size * 0.44 : -size * 0.32)
                .opacity(animates ? 0.2 : 0.9)
        case .cheering:
            ForEach(0 ..< 3, id: \.self) { index in
                Image(systemName: "sparkle")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(PiyoTheme.cheer)
                    .offset(x: CGFloat(index - 1) * 46, y: -size * 0.4)
                    .scaleEffect(animates ? 1.25 : 0.7)
            }
        case .finished:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(PiyoTheme.success)
                .offset(x: size * 0.3, y: -size * 0.34)
        }
    }

    private func restartAnimation() {
        animates = false
        withAnimation(.easeInOut(duration: cycle).repeatForever(autoreverses: true)) {
            animates = true
        }
    }
}

/// 位（くらい）をブロックで見せる。
struct PlaceValueBlocksView: View {
    var value: Int
    var highlighted: NumberPlace? = nil
    var blockSize: CGFloat = 16

    private var breakdown: PlaceValueBreakdown {
        PlaceValueBreakdown(value: value)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 22) {
            if breakdown.hundreds > 0 {
                column(
                    title: NumberPlace.hundreds.childTitle,
                    count: breakdown.hundreds,
                    place: .hundreds
                ) {
                    AnyView(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(PiyoTheme.calm)
                            .frame(width: blockSize * 3, height: blockSize * 3)
                            .overlay(
                                Grid3x3()
                                    .stroke(Color.white.opacity(0.8), lineWidth: 1)
                                    .frame(width: blockSize * 3, height: blockSize * 3)
                            )
                    )
                }
            }
            if breakdown.tens > 0 || breakdown.hundreds > 0 {
                column(title: NumberPlace.tens.childTitle, count: breakdown.tens, place: .tens) {
                    AnyView(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(PiyoTheme.success)
                            .frame(width: blockSize, height: blockSize * 3)
                    )
                }
            }
            column(title: NumberPlace.ones.childTitle, count: breakdown.ones, place: .ones) {
                AnyView(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(PiyoTheme.primary)
                        .frame(width: blockSize, height: blockSize)
                )
            }
        }
    }

    private func column(
        title: String,
        count: Int,
        place: NumberPlace,
        @ViewBuilder block: @escaping () -> AnyView
    ) -> some View {
        VStack(spacing: 8) {
            HStack(alignment: .bottom, spacing: 4) {
                if count == 0 {
                    Text("0")
                        .font(PiyoTheme.bodyFont)
                        .foregroundStyle(PiyoTheme.textSoft)
                } else {
                    ForEach(0 ..< count, id: \.self) { _ in
                        block()
                    }
                }
            }
            .frame(minHeight: blockSize * 3, alignment: .bottom)
            Text(title)
                .font(PiyoTheme.childFont(size: 13, weight: .semibold))
                .foregroundStyle(highlighted == place ? PiyoTheme.primaryDeep : PiyoTheme.textSoft)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(highlighted == place ? PiyoTheme.cheer.opacity(0.25) : Color.clear)
        )
    }
}

struct Grid3x3: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for index in 1 ..< 3 {
            let x = rect.width / 3 * CGFloat(index)
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: rect.height))
            let y = rect.height / 3 * CGFloat(index)
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: rect.width, y: y))
        }
        return path
    }
}
