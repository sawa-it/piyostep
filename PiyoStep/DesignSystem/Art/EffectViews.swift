import SwiftUI
import PiyoCore

/// 正解したときの紙吹雪。
///
/// 一枚ずつ「落ちる速さ・横のゆれ・回転」が違い、放物線で落ちる。
/// 時刻から位置を決めるので、途中で画面が組み替わっても破綻しない。
struct ConfettiView: View {
    var isActive: Bool
    var pieceCount: Int = 36

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startedAt: Date?

    private static let colors: [Color] = [
        PiyoTheme.primary, PiyoTheme.cheer, PiyoTheme.success, PiyoTheme.calm,
        Color(red: 0.98, green: 0.55, blue: 0.70), Color(red: 0.71, green: 0.56, blue: 0.91)
    ]

    private var isReduced: Bool {
        PiyoMotion.isReduced(accessibilityReduceMotion: reduceMotion)
    }

    var body: some View {
        GeometryReader { proxy in
            if let startedAt, !isReduced {
                TimelineView(.animation(minimumInterval: 1.0 / 40)) { context in
                    let elapsed = context.date.timeIntervalSince(startedAt)
                    Canvas { canvas, size in
                        guard elapsed < ConfettiPiece.duration else { return }
                        for index in 0 ..< pieceCount {
                            ConfettiPiece(index: index, colors: Self.colors).draw(in: &canvas, size: size, time: elapsed)
                        }
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            if isActive { startedAt = Date() }
        }
        .onChange(of: isActive) { _, active in
            startedAt = active ? Date() : nil
        }
    }
}

/// 紙吹雪 1 枚。番号から決まる乱数で、形・色・出る位置・落ち方を変える。
private struct ConfettiPiece {
    static let duration: Double = 2.6

    let index: Int
    let colors: [Color]

    private func noise(_ salt: Int) -> Double {
        // 番号ごとに安定した 0〜1 の値。
        let value = sin(Double(index * 127 + salt * 311) * 12.9898) * 43758.5453
        return value - floor(value)
    }

    func draw(in canvas: inout GraphicsContext, size: CGSize, time: Double) {
        let delay = noise(1) * 0.7
        let t = time - delay
        guard t > 0 else { return }

        let startX = size.width * (0.05 + 0.9 * noise(2))
        let launch = -(size.height * (0.10 + 0.25 * noise(3)))
        let fall = size.height * (0.55 + 0.35 * noise(4))
        let sway = size.width * 0.06 * sin(t * (2.2 + noise(5) * 2.5) + noise(6) * 6.28)
        let progress = t / (Self.duration - delay)
        let y = size.height * 0.12 + launch * t + fall * t * t
        let x = startX + sway

        let width = 7 + 6 * noise(7)
        let height = 9 + 7 * noise(8)
        let spin = t * (3 + noise(9) * 5)
        let flip = abs(cos(t * (4 + noise(10) * 4)))
        let opacity = max(0, 1 - max(0, progress - 0.7) / 0.3)

        var context = canvas
        context.opacity = opacity
        context.translateBy(x: x, y: y)
        context.rotate(by: .radians(spin))
        let shapeIndex = index % 3
        let rect = CGRect(x: -width / 2, y: -height / 2, width: width, height: height * max(0.15, flip))
        let color = colors[index % colors.count]
        switch shapeIndex {
        case 0:
            context.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(color))
        case 1:
            context.fill(Path(ellipseIn: rect), with: .color(color))
        default:
            var ribbon = Path()
            ribbon.move(to: CGPoint(x: rect.minX, y: rect.minY))
            ribbon.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.minY))
            context.stroke(ribbon, with: .color(color), lineWidth: 3)
        }
    }
}

/// 正解の瞬間に、まわりへ飛び散るきらきら。
struct SparkleBurstView: View {
    var isActive: Bool
    var color: Color = PiyoTheme.cheer
    var size: CGFloat = 160

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress: CGFloat = 0

    var body: some View {
        ZStack {
            ForEach(0 ..< 8, id: \.self) { index in
                let angle = Double(index) / 8 * 2 * .pi
                Image(systemName: index % 2 == 0 ? "sparkle" : "star.fill")
                    .font(.system(size: size * (index % 2 == 0 ? 0.12 : 0.08), weight: .bold))
                    .foregroundStyle(color)
                    .scaleEffect(0.3 + progress * 0.9)
                    .opacity(progress < 0.15 ? 0 : Double(1 - progress))
                    .offset(
                        x: CGFloat(cos(angle)) * size * 0.5 * progress,
                        y: CGFloat(sin(angle)) * size * 0.5 * progress
                    )
            }
            Circle()
                .stroke(color.opacity(0.5), lineWidth: 6)
                .frame(width: size * progress, height: size * progress)
                .opacity(Double(1 - progress))
        }
        .frame(width: size, height: size)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear { fire() }
        .onChange(of: isActive) { _, _ in fire() }
    }

    private func fire() {
        guard isActive, !PiyoMotion.isReduced(accessibilityReduceMotion: reduceMotion) else { return }
        progress = 0
        withAnimation(.easeOut(duration: 0.8)) {
            progress = 1
        }
    }
}

/// 獲得した★の表示。取った星は色付きの絵で、まだの星は薄く。
struct StarRewardView: View {
    var stars: Int
    var maximum: Int = 3
    var size: CGFloat = 40

    var body: some View {
        HStack(spacing: size * 0.18) {
            ForEach(0 ..< maximum, id: \.self) { index in
                let earned = index < stars
                ArtImage(asset: .star, size: size)
                    .saturation(earned ? 1 : 0)
                    .opacity(earned ? 1 : 0.28)
                    .scaleEffect(earned ? 1.0 : 0.82)
                    .rotationEffect(.degrees(earned ? 0 : -20))
                    .shadow(color: PiyoTheme.cheer.opacity(earned ? 0.5 : 0), radius: size * 0.2)
                    .animation(
                        .spring(response: 0.45, dampingFraction: 0.5).delay(Double(index) * 0.14),
                        value: stars
                    )
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("★が \(stars)こ")
    }
}

/// 音声入力中の波形。
struct VoiceWaveformView: View {
    var level: Double
    var isListening: Bool
    var color: Color = PiyoTheme.primary
    var barCount: Int = 9

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startedAt = Date()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !isListening || PiyoMotion.isReduced(accessibilityReduceMotion: reduceMotion))) { context in
            let phase = context.date.timeIntervalSince(startedAt)
            HStack(spacing: 6) {
                ForEach(0 ..< barCount, id: \.self) { index in
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.7), color],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 8, height: barHeight(for: index, phase: phase))
                        .animation(.easeInOut(duration: 0.22), value: level)
                }
            }
        }
        .frame(height: 56)
        .accessibilityHidden(true)
    }

    private func barHeight(for index: Int, phase: Double) -> CGFloat {
        guard isListening else { return 10 }
        let center = Double(barCount - 1) / 2
        let distance = abs(Double(index) - center) / max(1, center)
        let shape = 1.0 - distance * 0.55
        let animated = 0.5 + 0.5 * sin(phase * 5.5 + Double(index) * 0.9)
        let amplitude = max(0.12, min(1.0, level)) * shape * (0.55 + 0.45 * animated)
        return CGFloat(12 + amplitude * 44)
    }
}

/// 進捗バー（何問中の何問目か）。
struct SessionProgressBar: View {
    var current: Int
    var total: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0 ..< max(1, total), id: \.self) { index in
                Capsule()
                    .fill(
                        index < current
                            ? AnyShapeStyle(
                                LinearGradient(
                                    colors: [PiyoTheme.cheer, PiyoTheme.primary],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            : AnyShapeStyle(PiyoTheme.outline.opacity(0.45))
                    )
                    // いま解いている 1 本だけ太くして、どこまで来たかを分かりやすくする。
                    .frame(height: index == current ? 14 : 10)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: current)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier(A11yID.sessionProgress)
        .accessibilityLabel("\(total)もんちゅう \(min(current + 1, total))もんめ")
    }
}

/// 後ろでゆっくり回る光の帯。ごほうびの後ろに敷く。
struct SunburstView: View {
    var color: Color = PiyoTheme.cheer
    var rayCount: Int = 12

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startedAt = Date()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: PiyoMotion.isReduced(accessibilityReduceMotion: reduceMotion))) { context in
            let angle = context.date.timeIntervalSince(startedAt) * 12
            Sunburst(rayCount: rayCount)
                .fill(
                    RadialGradient(
                        colors: [color.opacity(0.45), color.opacity(0.0)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 260
                    )
                )
                .rotationEffect(.degrees(angle))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct Sunburst: Shape {
    var rayCount: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = max(rect.width, rect.height)
        let step = 2 * Double.pi / Double(rayCount)
        for index in 0 ..< rayCount {
            let start = Double(index) * step
            let end = start + step * 0.5
            path.move(to: center)
            path.addLine(to: CGPoint(x: center.x + radius * cos(start), y: center.y + radius * sin(start)))
            path.addLine(to: CGPoint(x: center.x + radius * cos(end), y: center.y + radius * sin(end)))
            path.closeSubpath()
        }
        return path
    }
}

/// アンロック演出。何が手に入ったかを、その絵で見せる。
struct UnlockBanner: View {
    var item: UnlockableItem
    var onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isRevealed = false

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                SunburstView(color: PiyoTheme.cheer)
                    .frame(width: 260, height: 260)
                    .clipShape(Circle())
                UnlockableItemArtView(item: item, size: 150)
                    .scaleEffect(isRevealed ? 1 : 0.3)
                    .rotationEffect(.degrees(isRevealed ? 0 : -25))
                ArtImage(asset: .sparkles, size: 56)
                    .offset(x: 84, y: -70)
                    .scaleEffect(isRevealed ? 1 : 0)
                ArtImage(asset: .sparkle, size: 34)
                    .offset(x: -88, y: 40)
                    .scaleEffect(isRevealed ? 1 : 0)
            }
            .frame(height: 220)
            .accessibilityHidden(true)

            Text("あたらしい \(item.category.childTitle)！")
                .piyoFont(.headline)
                .foregroundStyle(PiyoTheme.textSoft)
            Text(item.name)
                .piyoFont(.title)
                .foregroundStyle(PiyoTheme.primaryDeep)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)
                .lineLimit(2)
            BigButton(color: PiyoTheme.success, action: onDismiss) {
                Text("やったー！")
                    .piyoFont(.headline)
            }
        }
        .padding(28)
        .frame(maxWidth: 440)
        .background(
            RoundedRectangle(cornerRadius: PiyoTheme.cornerRadius, style: .continuous)
                .fill(PiyoTheme.surface)
                .shadow(color: PiyoTheme.shadow.opacity(0.22), radius: 28, y: 12)
        )
        .padding(28)
        .onAppear {
            if PiyoMotion.isReduced(accessibilityReduceMotion: reduceMotion) {
                isRevealed = true
            } else {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.55).delay(0.1)) {
                    isRevealed = true
                }
            }
        }
    }
}

/// アンロックできるものの絵。バッジ画面と、手に入れた瞬間の演出の両方で使う。
struct UnlockableItemArtView: View {
    var item: UnlockableItem
    var size: CGFloat = 80

    var body: some View {
        switch item.category {
        case .character:
            CharacterArtView(
                character: CharacterCatalog.character(id: item.artKey) ?? CharacterCatalog.fallback,
                mood: .happy,
                size: size,
                isAnimated: false
            )
        case .costume:
            if let asset = ArtCatalog.costume(item.artKey) {
                ArtImage(asset: asset, size: size * 0.82)
            }
        case .tableware:
            PlateView(fullness: 0.75, tablewareArtKey: item.artKey, size: size * 1.05)
        case .background:
            BackgroundSceneView(artKey: item.artKey, size: size)
        case .badge:
            ArtImage(asset: ArtCatalog.badge(item.artKey), size: size * 0.82)
        }
    }
}

/// はいけいの小さな景色。空の色と、その場所らしいものをひとつ。
struct BackgroundSceneView: View {
    var artKey: String
    var size: CGFloat = 80

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: ArtCatalog.backgroundColors(artKey),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            if artKey == "space" {
                ArtImage(asset: .rocket, size: size * 0.32)
                    .offset(x: -size * 0.28, y: -size * 0.40)
            }
            if artKey == "night" || artKey == "space" {
                ForEach(0 ..< 5, id: \.self) { index in
                    Circle()
                        .fill(Color.white.opacity(0.85))
                        .frame(width: size * 0.035)
                        .offset(
                            x: size * (CGFloat((index * 37) % 80) / 100 - 0.4),
                            y: -size * (0.2 + CGFloat((index * 53) % 50) / 100)
                        )
                }
            }
            ArtImage(asset: ArtCatalog.background(artKey), size: size * 0.55)
                .padding(.bottom, size * 0.08)
        }
        .frame(width: size * 1.25, height: size * 0.95)
    }
}
