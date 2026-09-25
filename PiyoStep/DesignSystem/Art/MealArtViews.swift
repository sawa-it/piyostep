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
                        Circle().fill(PiyoTheme.primary)
                        Image(systemName: "figure.child")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 44, height: 44)
                )
            }

            lane(
                progress: characterProgress,
                color: PiyoTheme.color(hex: character.accentColorHex),
                label: character.name,
                identifier: A11yID.mealCharacterProgress
            ) {
                AnyView(
                    CharacterArtView(character: character, mood: .eating, size: 48, isAnimated: false)
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
                .font(PiyoTheme.captionFont)
                .foregroundStyle(PiyoTheme.textSoft)
            GeometryReader { proxy in
                let width = proxy.size.width
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(PiyoTheme.surfaceSunken)
                    Capsule()
                        .fill(color.opacity(0.35))
                        .frame(width: max(0, width * clamped))
                    marker()
                        .offset(x: max(0, min(width - 44, width * clamped - 22)))
                    Image(systemName: "flag.checkered")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(PiyoTheme.textSoft)
                        .offset(x: width - 22)
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
