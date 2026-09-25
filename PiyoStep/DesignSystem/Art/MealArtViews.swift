import SwiftUI
import PiyoCore

/// ごはんの乗ったお皿。`fullness` が 1.0 で満杯、0.0 で完食。
///
/// 食べものは上からかじられていくように見せる（下だけ残す）。
/// 食べきると、きらきらと「ごちそうさま」の印に変わる。
struct PlateView: View {
    var fullness: Double
    var tablewareArtKey: String = "white"
    var size: CGFloat = 150
    var foodName: String = "ごはん"

    private var clampedFullness: Double {
        min(max(fullness, 0), 1)
    }

    private var isFinished: Bool { clampedFullness <= 0.02 }

    private var plateColors: [Color] {
        switch tablewareArtKey {
        case "flower": return [Color(red: 1.0, green: 0.94, blue: 0.96), Color(red: 1.0, green: 0.86, blue: 0.91)]
        case "star": return [Color(red: 0.95, green: 0.97, blue: 1.0), Color(red: 0.86, green: 0.92, blue: 1.0)]
        case "rainbow": return [Color(red: 0.97, green: 1.0, blue: 0.95), Color(red: 0.88, green: 0.98, blue: 0.86)]
        default: return [Color.white, Color(red: 0.95, green: 0.94, blue: 0.91)]
        }
    }

    private var rimColor: Color {
        switch tablewareArtKey {
        case "flower": return Color(red: 0.96, green: 0.55, blue: 0.70)
        case "star": return PiyoTheme.calm
        case "rainbow": return PiyoTheme.success
        default: return PiyoTheme.outline
        }
    }

    var body: some View {
        ZStack {
            plate
            if isFinished {
                ZStack {
                    ArtImage(asset: .sparkles, size: size * 0.34)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: size * 0.18, weight: .bold))
                        .foregroundStyle(.white, PiyoTheme.success)
                        .offset(x: size * 0.16, y: size * 0.10)
                }
                .offset(y: -size * 0.05)
                .transition(.scale.combined(with: .opacity))
            } else {
                food
            }
        }
        .frame(width: size, height: size * 0.7)
        .animation(.spring(response: 0.45, dampingFraction: 0.7), value: isFinished)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isFinished ? "\(foodName)を たべおわった" : "\(foodName)が のこっている")
    }

    private var plate: some View {
        ZStack {
            Ellipse()
                .fill(
                    LinearGradient(colors: plateColors, startPoint: .top, endPoint: .bottom)
                )
                .frame(width: size, height: size * 0.60)
                .shadow(color: PiyoTheme.shadow.opacity(0.16), radius: size * 0.06, y: size * 0.04)
            Ellipse()
                .stroke(rimColor.opacity(0.7), lineWidth: max(2, size * 0.02))
                .frame(width: size, height: size * 0.60)
            Ellipse()
                .stroke(rimColor.opacity(0.35), lineWidth: max(1.5, size * 0.012))
                .frame(width: size * 0.74, height: size * 0.42)
            // ふちの模様。お皿ごとに違う小さな絵を散らす。
            if let pattern = ArtCatalog.tablewarePattern(tablewareArtKey) {
                ForEach(0 ..< 6, id: \.self) { index in
                    let angle = Double(index) / 6 * 2 * .pi + 0.4
                    ArtImage(asset: pattern, size: size * 0.11)
                        .offset(x: CGFloat(cos(angle)) * size * 0.44, y: CGFloat(sin(angle)) * size * 0.25)
                }
            }
        }
        .offset(y: size * 0.05)
    }

    private var food: some View {
        let foodSize = size * 0.50
        let remaining = CGFloat(clampedFullness.squareRoot())
        return ArtImage(asset: ArtCatalog.food(named: foodName), size: foodSize)
            .mask(alignment: .bottom) {
                // 上からかじられていく。残りの高さだけ見せる。
                Rectangle()
                    .frame(width: foodSize, height: foodSize * max(0.06, remaining))
            }
            .shadow(color: PiyoTheme.shadow.opacity(0.18), radius: size * 0.03, y: size * 0.02)
            .offset(y: -size * 0.08)
            .animation(.easeInOut(duration: 0.45), value: clampedFullness)
    }
}

/// ゴールまでのトラック。子どもとキャラクターの位置を並べて見せる。
struct RaceTrackView: View {
    var childProgress: Double
    var characterProgress: Double
    var character: CharacterDefinition
    var childName: String

    var body: some View {
        VStack(spacing: 14) {
            lane(
                progress: childProgress,
                color: PiyoTheme.primary,
                label: childName.isEmpty ? "きみ" : childName,
                identifier: A11yID.mealChildProgress
            ) {
                AnyView(
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [PiyoTheme.primary, PiyoTheme.primaryDeep],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .shadow(color: PiyoTheme.primary.opacity(0.4), radius: 6, y: 3)
                        Image(systemName: "figure.child")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 46, height: 46)
                )
            }

            lane(
                progress: characterProgress,
                color: PiyoTheme.color(hex: character.accentColorHex),
                label: character.name,
                identifier: A11yID.mealCharacterProgress
            ) {
                AnyView(
                    CharacterArtView(character: character, mood: .eating, size: 52, isAnimated: false)
                )
            }
        }
    }

    private func lane(
        progress: Double,
        color: Color,
        label: String,
        identifier: String,
        @ViewBuilder marker: @escaping () -> AnyView
    ) -> some View {
        let clamped = min(max(progress, 0), 1)
        return VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .piyoFont(.caption)
                .foregroundStyle(PiyoTheme.textSoft)
            GeometryReader { proxy in
                let width = proxy.size.width
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(PiyoTheme.surfaceSunken)
                    // 走った分だけ色がつく。先端は少し明るくして進んでいる感じを出す。
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.25), color.opacity(0.55)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, width * clamped))
                    // まんなかの点線。トラックらしさが出る。
                    Path { path in
                        path.move(to: CGPoint(x: 26, y: 24))
                        path.addLine(to: CGPoint(x: width - 26, y: 24))
                    }
                    .stroke(color.opacity(0.35), style: StrokeStyle(lineWidth: 2, dash: [6, 8]))
                    ArtImage(asset: .flag, size: 30)
                        .offset(x: width - 34, y: -4)
                    marker()
                        .offset(x: max(0, min(width - 46, width * clamped - 23)))
                }
                .animation(.easeInOut(duration: 0.4), value: clamped)
            }
            .frame(height: 48)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier(identifier)
        .accessibilityLabel("\(label)は \(Int(clamped * 100))パーセント")
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
                        .piyoFont(.body)
                        .foregroundStyle(PiyoTheme.textSoft)
                } else {
                    ForEach(0 ..< count, id: \.self) { _ in
                        block()
                    }
                }
            }
            .frame(minHeight: blockSize * 3, alignment: .bottom)
            Text(title)
                .piyoFont(size: 13, weight: .semibold)
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
