import SwiftUI
import PiyoCore

/// キャラクターの表情・しぐさ。
enum CharacterMood: Equatable {
    case idle
    case happy
    case eating
    case resting
    case cheering
    case listening
    case thinking
}

/// キャラクター。絵はフリー素材（Fluent Emoji）、動きはこちらで付ける。
///
/// 絵そのものは 1 枚だが、はずむ・ちぢむ・かたむく・気持ちの小物、で
/// 「いま何をしているか」が伝わるようにする。
struct CharacterArtView: View {
    var character: CharacterDefinition
    var mood: CharacterMood = .idle
    var size: CGFloat = 140
    /// 着せ替えアイテムの artKey（cap / ribbon / crown / glasses / scarf）
    var costumeArtKey: String? = nil
    var isAnimated: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startDate = Date()

    private var shouldAnimate: Bool {
        isAnimated && !PiyoMotion.isReduced(accessibilityReduceMotion: reduceMotion)
    }

    var body: some View {
        Group {
            if shouldAnimate {
                TimelineView(.animation(minimumInterval: 1.0 / 40)) { context in
                    figure(time: context.date.timeIntervalSince(startDate))
                }
            } else {
                figure(time: 0.4)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(character.name)
    }

    // MARK: - 組み立て

    /// 絵の一辺。まわりに小物を置く余白を残す。
    private var box: CGFloat { size * 0.84 }

    private func figure(time: Double) -> some View {
        let motion = CharacterMotion(mood: mood, time: shouldAnimate ? time : 0, size: size)
        return ZStack {
            groundShadow(motion: motion)

            ZStack {
                ArtImage(asset: ArtCatalog.character(character.artStyle), size: box)
                costume
            }
            .frame(width: box, height: box)
            .scaleEffect(x: motion.scaleX, y: motion.scaleY, anchor: .bottom)
            .rotationEffect(.degrees(motion.tilt), anchor: .bottom)
            .offset(y: motion.lift)

            moodDecoration(time: time)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: mood)
    }

    /// 足元の影。はずむと小さくなり、床から離れたことが分かる。
    private func groundShadow(motion: CharacterMotion) -> some View {
        Ellipse()
            .fill(PiyoTheme.shadow.opacity(0.16 * motion.shadowScale))
            .frame(width: box * 0.62 * motion.shadowScale, height: box * 0.12 * motion.shadowScale)
            .blur(radius: 3)
            .offset(y: box * 0.47)
    }

    // MARK: - きせかえ

    private var anchors: FaceAnchors {
        FaceAnchors.anchors(for: character.artStyle)
    }

    @ViewBuilder
    private var costume: some View {
        if let key = costumeArtKey, let asset = ArtCatalog.costume(key) {
            let a = anchors
            switch key {
            case "cap":
                ArtImage(asset: asset, size: box * a.width * 0.72)
                    .rotationEffect(.degrees(-8))
                    .offset(x: box * (a.centerX - 0.5 - 0.01), y: box * (a.headTop - 0.5 - 0.03))
            case "crown":
                ArtImage(asset: asset, size: box * a.width * 0.60)
                    .offset(x: box * (a.centerX - 0.5), y: box * (a.headTop - 0.5 - 0.05))
            case "ribbon":
                ArtImage(asset: asset, size: box * a.width * 0.42)
                    .rotationEffect(.degrees(12))
                    .offset(x: box * (a.centerX - 0.5 + a.width * 0.34), y: box * (a.headTop - 0.5 + 0.02))
            case "glasses":
                ArtImage(asset: asset, size: box * a.width * 0.92)
                    .offset(x: box * (a.centerX - 0.5), y: box * (a.eyes - 0.5))
            case "scarf":
                ArtImage(asset: asset, size: box * a.width * 0.62)
                    .offset(x: box * (a.centerX - 0.5), y: box * (a.neck - 0.5 + 0.05))
            default:
                EmptyView()
            }
        }
    }

    // MARK: - 気持ちの小物

    @ViewBuilder
    private func moodDecoration(time: Double) -> some View {
        let wave = shouldAnimate ? sin(time * 2 * .pi / 1.4) : 0.3
        let side = box * 0.5
        switch mood {
        case .happy:
            ArtImage(asset: .sparkles, size: size * 0.30)
                .scaleEffect(0.9 + 0.12 * wave)
                .rotationEffect(.degrees(8 * wave))
                .offset(x: side * 0.86, y: -side * 0.72)
                .transition(.scale.combined(with: .opacity))
        case .cheering:
            ArtImage(asset: .partyPopper, size: size * 0.32)
                .scaleEffect(x: -1)
                .rotationEffect(.degrees(-10 + 8 * wave))
                .offset(x: -side * 0.92, y: -side * 0.70)
                .transition(.scale.combined(with: .opacity))
            ArtImage(asset: .sparkles, size: size * 0.26)
                .scaleEffect(0.85 + 0.15 * wave)
                .offset(x: side * 0.90, y: -side * 0.78)
                .transition(.scale.combined(with: .opacity))
        case .resting:
            let cycle = shouldAnimate ? (time / 2.6).truncatingRemainder(dividingBy: 1) : 0.35
            ArtImage(asset: .zzz, size: size * 0.28)
                .opacity(1 - cycle * 0.9)
                .scaleEffect(0.7 + cycle * 0.5)
                .offset(x: side * 0.80, y: -side * (0.55 + cycle * 0.45))
                .transition(.opacity)
        case .listening:
            ListeningWaves(phase: shouldAnimate ? time : 0.2)
                .stroke(
                    PiyoTheme.color(hex: character.accentColorHex),
                    style: StrokeStyle(lineWidth: max(2, size * 0.028), lineCap: .round)
                )
                .frame(width: size * 0.34, height: size * 0.34)
                .offset(x: -side * 0.98, y: -side * 0.30)
                .transition(.opacity)
        case .thinking:
            ZStack {
                ArtImage(asset: .thoughtBalloon, size: size * 0.40)
                ArtImage(asset: .question, size: size * 0.15)
                    .offset(x: size * 0.03, y: -size * 0.05)
            }
            .offset(x: side * 0.86, y: -side * (0.76 + 0.04 * wave))
            .transition(.scale.combined(with: .opacity))
        case .eating:
            let chew = shouldAnimate ? 0.5 + 0.5 * sin(time * 2 * .pi / 0.55) : 0.4
            ArtImage(asset: ArtCatalog.food(named: character.favoriteFood), size: size * 0.30)
                .rotationEffect(.degrees(-12 + 10 * chew))
                .offset(x: side * 0.80, y: side * (0.30 - 0.10 * chew))
                .transition(.scale.combined(with: .opacity))
        case .idle:
            EmptyView()
        }
    }
}

/// 気持ちごとの動きの量。時間から決めるので、同じ時刻なら同じ姿勢になる。
private struct CharacterMotion {
    var scaleX: CGFloat = 1
    var scaleY: CGFloat = 1
    var tilt: Double = 0
    var lift: CGFloat = 0
    var shadowScale: CGFloat = 1

    init(mood: CharacterMood, time: Double, size: CGFloat) {
        func cycle(_ seconds: Double) -> Double { sin(time * 2 * .pi / seconds) }

        switch mood {
        case .idle:
            // 呼吸。縦にふくらむ分だけ横をしぼる。
            let breath = cycle(2.4)
            scaleY = 1 + 0.025 * breath
            scaleX = 1 - 0.015 * breath
        case .happy:
            // 小さくはずむ。地面で少しつぶれ、空中でのびる。
            let hop = abs(cycle(0.95))
            lift = -hop * size * 0.06
            scaleY = 0.97 + 0.07 * hop
            scaleX = 1.03 - 0.05 * hop
            tilt = 3 * cycle(1.9)
            shadowScale = 1 - hop * 0.35
        case .cheering:
            // 大きくはずんで左右にゆれる。
            let hop = abs(cycle(0.7))
            lift = -hop * size * 0.10
            scaleY = 0.96 + 0.09 * hop
            scaleX = 1.04 - 0.06 * hop
            tilt = 7 * cycle(1.4)
            shadowScale = 1 - hop * 0.45
        case .eating:
            // もぐもぐ。上下にちぢむ。
            let chew = 0.5 + 0.5 * cycle(0.55)
            scaleY = 1 - 0.06 * chew
            scaleX = 1 + 0.035 * chew
            tilt = -3 + 2 * cycle(1.1)
        case .resting:
            // ゆっくり呼吸して、少しかたむく。
            let breath = cycle(3.2)
            scaleY = 1 + 0.02 * breath
            scaleX = 1 - 0.012 * breath
            tilt = -7
        case .listening:
            // 音のほうへ耳をかたむける。
            let breath = cycle(2.0)
            scaleY = 1 + 0.02 * breath
            tilt = 10 + 2 * cycle(1.6)
        case .thinking:
            let breath = cycle(2.2)
            scaleY = 1 + 0.02 * breath
            tilt = -4 + 3 * cycle(2.2)
        }
    }
}

/// 絵の中で「頭のてっぺん・目・首」がどこにあるか（0〜1、上が 0）。
/// きせかえの小物を置く位置に使う。
private struct FaceAnchors {
    var headTop: CGFloat
    var eyes: CGFloat
    var neck: CGFloat
    var centerX: CGFloat
    /// 頭の幅（絵の一辺に対する割合）
    var width: CGFloat

    static func anchors(for style: CharacterArtStyle) -> FaceAnchors {
        switch style {
        case .chick: return FaceAnchors(headTop: 0.13, eyes: 0.31, neck: 0.44, centerX: 0.50, width: 0.58)
        case .bear: return FaceAnchors(headTop: 0.17, eyes: 0.46, neck: 0.86, centerX: 0.50, width: 0.88)
        case .cat: return FaceAnchors(headTop: 0.16, eyes: 0.47, neck: 0.86, centerX: 0.50, width: 0.84)
        case .rabbit: return FaceAnchors(headTop: 0.30, eyes: 0.62, neck: 0.90, centerX: 0.50, width: 0.78)
        case .penguin: return FaceAnchors(headTop: 0.12, eyes: 0.30, neck: 0.42, centerX: 0.50, width: 0.60)
        case .dinosaur: return FaceAnchors(headTop: 0.08, eyes: 0.20, neck: 0.33, centerX: 0.44, width: 0.46)
        }
    }
}

/// 聞いているときの、音の波（3 本の弧）。
private struct ListeningWaves: Shape {
    var phase: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.maxX, y: rect.midY)
        for index in 0 ..< 3 {
            let pulse = 0.5 + 0.5 * sin(phase * 2 * .pi / 1.2 - Double(index) * 0.9)
            let radius = rect.width * (0.28 + 0.24 * CGFloat(index)) * CGFloat(0.9 + 0.1 * pulse)
            path.addArc(
                center: center,
                radius: radius,
                startAngle: .degrees(150),
                endAngle: .degrees(210),
                clockwise: false
            )
        }
        return path
    }
}

// MARK: - 形（ほかの演出からも使う）

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

#Preview {
    VStack(spacing: 24) {
        HStack(spacing: 20) {
            ForEach(CharacterCatalog.all) { character in
                CharacterArtView(character: character, mood: .happy, size: 110)
            }
        }
        HStack(spacing: 20) {
            CharacterArtView(character: CharacterCatalog.fallback, mood: .eating, size: 110)
            CharacterArtView(character: CharacterCatalog.fallback, mood: .resting, size: 110)
            CharacterArtView(character: CharacterCatalog.fallback, mood: .cheering, size: 110)
            CharacterArtView(character: CharacterCatalog.fallback, mood: .listening, size: 110)
            CharacterArtView(character: CharacterCatalog.fallback, mood: .thinking, size: 110, costumeArtKey: "crown")
        }
    }
    .padding()
    .background(PiyoTheme.background)
}
