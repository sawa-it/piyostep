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

    var isEyesClosed: Bool {
        self == .resting || self == .happy
    }
}

/// 画像アセットを使わず、図形だけでキャラクターを描く。
struct CharacterArtView: View {
    var character: CharacterDefinition
    var mood: CharacterMood = .idle
    var size: CGFloat = 140
    /// 着せ替えアイテムの artKey（cap / ribbon / crown / glasses / scarf）
    var costumeArtKey: String? = nil
    var isAnimated: Bool = true

    @State private var phase: Double = 0

    private var primary: Color { PiyoTheme.color(hex: character.primaryColorHex) }
    private var accent: Color { PiyoTheme.color(hex: character.accentColorHex) }

    var body: some View {
        ZStack {
            earsAndExtras
            bodyShape
            face
            arms
            costume
            moodDecoration
        }
        .frame(width: size, height: size)
        .offset(y: bobOffset)
        .rotationEffect(.degrees(tiltAngle))
        .animation(.easeInOut(duration: 0.6), value: mood)
        .onAppear {
            guard isAnimated else { return }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                phase = 1
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(character.name)
    }

    // MARK: - パーツ

    private var bodyShape: some View {
        ZStack {
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [primary.opacity(0.95), primary],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size * 0.78, height: size * 0.72)
            Ellipse()
                .fill(Color.white.opacity(0.75))
                .frame(width: size * 0.44, height: size * 0.38)
                .offset(y: size * 0.14)
        }
    }

    @ViewBuilder
    private var earsAndExtras: some View {
        switch character.artStyle {
        case .cat:
            HStack(spacing: size * 0.30) {
                Triangle().fill(primary).frame(width: size * 0.18, height: size * 0.18)
                Triangle().fill(primary).frame(width: size * 0.18, height: size * 0.18)
            }
            .offset(y: -size * 0.32)
        case .bear:
            HStack(spacing: size * 0.38) {
                Circle().fill(primary).frame(width: size * 0.22)
                Circle().fill(primary).frame(width: size * 0.22)
            }
            .offset(y: -size * 0.28)
        case .rabbit:
            HStack(spacing: size * 0.14) {
                Capsule().fill(primary).frame(width: size * 0.12, height: size * 0.34)
                Capsule().fill(primary).frame(width: size * 0.12, height: size * 0.34)
            }
            .offset(y: -size * 0.38)
        case .chick:
            // ちょんとした毛
            Capsule()
                .fill(accent)
                .frame(width: size * 0.06, height: size * 0.14)
                .offset(y: -size * 0.40)
        case .penguin:
            Ellipse()
                .fill(accent)
                .frame(width: size * 0.86, height: size * 0.78)
                .offset(y: size * 0.01)
        case .dinosaur:
            HStack(spacing: size * 0.06) {
                ForEach(0 ..< 3, id: \.self) { _ in
                    Triangle().fill(accent).frame(width: size * 0.12, height: size * 0.12)
                }
            }
            .offset(y: -size * 0.34)
        }
    }

    private var face: some View {
        VStack(spacing: size * 0.05) {
            HStack(spacing: size * 0.20) {
                eye
                eye
            }
            mouth
        }
        .offset(y: -size * 0.06)
    }

    @ViewBuilder
    private var eye: some View {
        if mood.isEyesClosed {
            ClosedEye()
                .stroke(PiyoTheme.text, style: StrokeStyle(lineWidth: size * 0.025, lineCap: .round))
                .frame(width: size * 0.13, height: size * 0.07)
        } else {
            ZStack {
                Circle()
                    .fill(PiyoTheme.text)
                    .frame(width: size * 0.10)
                Circle()
                    .fill(Color.white)
                    .frame(width: size * 0.035)
                    .offset(x: size * 0.02, y: -size * 0.02)
            }
        }
    }

    @ViewBuilder
    private var mouth: some View {
        switch character.artStyle {
        case .chick, .penguin:
            Triangle()
                .fill(PiyoTheme.cheer)
                .frame(width: size * 0.13, height: mouthOpenness)
                .rotationEffect(.degrees(180))
        default:
            Smile()
                .stroke(PiyoTheme.text, style: StrokeStyle(lineWidth: size * 0.022, lineCap: .round))
                .frame(width: size * 0.16, height: mouthOpenness)
        }
    }

    private var arms: some View {
        HStack {
            Capsule()
                .fill(primary)
                .frame(width: size * 0.10, height: size * 0.22)
                .rotationEffect(.degrees(mood == .cheering ? -50 : -10), anchor: .top)
            Spacer()
            Capsule()
                .fill(primary)
                .frame(width: size * 0.10, height: size * 0.22)
                .rotationEffect(.degrees(mood == .cheering ? 50 : 10), anchor: .top)
        }
        .frame(width: size * 0.88)
        .offset(y: size * 0.06)
    }

    @ViewBuilder
    private var costume: some View {
        switch costumeArtKey {
        case "cap":
            Capsule()
                .fill(PiyoTheme.calm)
                .frame(width: size * 0.46, height: size * 0.14)
                .offset(y: -size * 0.30)
        case "ribbon":
            HStack(spacing: -size * 0.02) {
                Triangle().fill(Color.pink).frame(width: size * 0.12, height: size * 0.12)
                    .rotationEffect(.degrees(-90))
                Triangle().fill(Color.pink).frame(width: size * 0.12, height: size * 0.12)
                    .rotationEffect(.degrees(90))
            }
            .offset(x: size * 0.22, y: -size * 0.24)
        case "crown":
            Crown()
                .fill(PiyoTheme.cheer)
                .frame(width: size * 0.34, height: size * 0.18)
                .offset(y: -size * 0.34)
        case "glasses":
            HStack(spacing: size * 0.06) {
                Circle().stroke(PiyoTheme.text, lineWidth: size * 0.02).frame(width: size * 0.16)
                Circle().stroke(PiyoTheme.text, lineWidth: size * 0.02).frame(width: size * 0.16)
            }
            .offset(y: -size * 0.10)
        case "scarf":
            Capsule()
                .fill(Color.red.opacity(0.8))
                .frame(width: size * 0.52, height: size * 0.10)
                .offset(y: size * 0.12)
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var moodDecoration: some View {
        switch mood {
        case .resting:
            Text("zzz")
                .font(PiyoTheme.childFont(size: size * 0.16))
                .foregroundStyle(PiyoTheme.textSoft)
                .offset(x: size * 0.34, y: -size * 0.30)
        case .happy:
            Image(systemName: "sparkles")
                .font(.system(size: size * 0.20))
                .foregroundStyle(PiyoTheme.cheer)
                .offset(x: size * 0.34, y: -size * 0.28)
        case .listening:
            Image(systemName: "ear.fill")
                .font(.system(size: size * 0.16))
                .foregroundStyle(accent)
                .offset(x: size * 0.36, y: -size * 0.10)
        case .thinking:
            Text("？")
                .font(PiyoTheme.childFont(size: size * 0.22))
                .foregroundStyle(PiyoTheme.textSoft)
                .offset(x: size * 0.34, y: -size * 0.30)
        case .cheering:
            Image(systemName: "hands.clap.fill")
                .font(.system(size: size * 0.16))
                .foregroundStyle(PiyoTheme.cheer)
                .offset(x: size * 0.36, y: -size * 0.26)
        case .idle, .eating:
            EmptyView()
        }
    }

    // MARK: - アニメーション量

    private var bobOffset: CGFloat {
        guard isAnimated else { return 0 }
        switch mood {
        case .eating: return CGFloat(phase) * size * 0.03
        case .cheering: return -CGFloat(phase) * size * 0.05
        case .resting: return CGFloat(phase) * size * 0.012
        default: return CGFloat(phase) * size * 0.015
        }
    }

    private var tiltAngle: Double {
        switch mood {
        case .listening: return 8
        case .cheering: return isAnimated ? (phase * 6 - 3) : 0
        default: return 0
        }
    }

    private var mouthOpenness: CGFloat {
        switch mood {
        case .eating: return size * (0.06 + 0.05 * CGFloat(phase))
        case .happy, .cheering: return size * 0.10
        case .resting: return size * 0.04
        default: return size * 0.06
        }
    }
}

// MARK: - 形

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

struct Smile: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.midX, y: rect.maxY * 1.6)
        )
        return path
    }
}

struct ClosedEye: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY),
            control: CGPoint(x: rect.midX, y: rect.minY - rect.height)
        )
        return path
    }
}

struct Crown: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.width * 0.3, y: rect.height * 0.45))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.width * 0.7, y: rect.height * 0.45))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
