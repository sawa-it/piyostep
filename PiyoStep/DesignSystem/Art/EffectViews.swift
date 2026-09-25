import SwiftUI
import PiyoCore

/// 正解したときの紙吹雪。
struct ConfettiView: View {
    var isActive: Bool
    var pieceCount: Int = 24

    private let colors: [Color] = [
        PiyoTheme.primary, PiyoTheme.cheer, PiyoTheme.success, PiyoTheme.calm,
        Color.pink, Color.purple
    ]

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(0 ..< pieceCount, id: \.self) { index in
                    ConfettiPiece(
                        color: colors[index % colors.count],
                        startX: CGFloat((index * 37) % 100) / 100 * proxy.size.width,
                        height: proxy.size.height,
                        delay: Double(index % 8) * 0.06,
                        isActive: isActive
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct ConfettiPiece: View {
    var color: Color
    var startX: CGFloat
    var height: CGFloat
    var delay: Double
    var isActive: Bool

    @State private var progress: CGFloat = 0

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(color)
            .frame(width: 10, height: 14)
            .rotationEffect(.degrees(Double(progress) * 540))
            .position(x: startX, y: progress * height)
            .opacity(isActive ? 1 - Double(progress) * 0.4 : 0)
            .onChange(of: isActive) { _, active in
                guard active else {
                    progress = 0
                    return
                }
                progress = 0
                withAnimation(.easeIn(duration: 1.6).delay(delay)) {
                    progress = 1
                }
            }
    }
}

/// 獲得した★の表示。
struct StarRewardView: View {
    var stars: Int
    var maximum: Int = 3
    var size: CGFloat = 40

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0 ..< maximum, id: \.self) { index in
                Image(systemName: index < stars ? "star.fill" : "star")
                    .font(.system(size: size, weight: .bold))
                    .foregroundStyle(index < stars ? PiyoTheme.cheer : PiyoTheme.outline)
                    .scaleEffect(index < stars ? 1.0 : 0.85)
                    .animation(
                        .spring(response: 0.4, dampingFraction: 0.55).delay(Double(index) * 0.12),
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
    var barCount: Int = 7

    @State private var phase: Double = 0

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0 ..< barCount, id: \.self) { index in
                Capsule()
                    .fill(color)
                    .frame(width: 8, height: barHeight(for: index))
                    .animation(.easeInOut(duration: 0.22), value: level)
                    .animation(.easeInOut(duration: 0.4), value: phase)
            }
        }
        .frame(height: 56)
        .onAppear { updateAnimation() }
        // 聞き取りは画面が出たあとに始まる（読み上げが終わってから）ので、
        // 出た瞬間だけでなく状態が変わったときにも動かす。
        .onChange(of: isListening) { _, _ in updateAnimation() }
        .accessibilityHidden(true)
    }

    private func updateAnimation() {
        if isListening {
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                phase = 1
            }
        } else {
            withAnimation(.easeInOut(duration: 0.2)) {
                phase = 0
            }
        }
    }

    private func barHeight(for index: Int) -> CGFloat {
        guard isListening else { return 10 }
        let center = Double(barCount - 1) / 2
        let distance = abs(Double(index) - center) / max(1, center)
        let shape = 1.0 - distance * 0.55
        let animated = 0.5 + 0.5 * sin(phase * .pi * 2 + Double(index))
        let amplitude = max(0.12, min(1.0, level)) * shape * (0.6 + 0.4 * animated)
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

/// アンロック演出。
struct UnlockBanner: View {
    var item: UnlockableItem
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "gift.fill")
                .font(.system(size: 54))
                .foregroundStyle(PiyoTheme.cheer)
            Text("あたらしい \(item.category.childTitle)！")
                .piyoFont(.headline)
                .foregroundStyle(PiyoTheme.text)
            Text(item.name)
                .piyoFont(.title)
                .foregroundStyle(PiyoTheme.primaryDeep)
            BigButton(color: PiyoTheme.success, action: onDismiss) {
                Text("やったー！")
                    .piyoFont(.headline)
            }
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: PiyoTheme.cornerRadius, style: .continuous)
                .fill(PiyoTheme.surface)
                .shadow(color: .black.opacity(0.18), radius: 24, y: 10)
        )
        .padding(28)
    }
}
