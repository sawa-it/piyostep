import SwiftUI

/// 幼児でも押しやすい大きなボタン。
struct BigButton<Label: View>: View {
    @Environment(\.piyoLayout) private var layout

    var color: Color = PiyoTheme.primary
    /// 指定が無ければ、画面の広さに合わせた最小サイズ。
    var minHeight: CGFloat?
    var isEnabled: Bool = true
    var action: () -> Void
    @ViewBuilder var label: Label

    @State private var isPressed = false

    private var resolvedMinHeight: CGFloat {
        minHeight ?? CGFloat(layout.minimumTapSize)
    }

    var body: some View {
        Button(action: {
            guard isEnabled else { return }
            action()
        }) {
            label
                .frame(maxWidth: .infinity, minHeight: resolvedMinHeight)
                .padding(.horizontal, 16)
                .background(shape)
                .foregroundStyle(.white)
                // 押した分だけ沈む。影も一緒に縮めると、厚みのあるものを
                // 押した感じになり、反応したことが幼児にも伝わる。
                .offset(y: isPressed ? 3 : 0)
                .scaleEffect(isPressed ? 0.98 : 1.0)
                .animation(.spring(response: 0.22, dampingFraction: 0.7), value: isPressed)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }

    /// 上を明るく、下を暗くしたひとつの面。平らな単色より押せるものに見える。
    private var shape: some View {
        let base = isEnabled ? color : PiyoTheme.outline
        return RoundedRectangle(cornerRadius: PiyoTheme.cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [base.opacity(0.92), base],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: PiyoTheme.cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.30), lineWidth: 1.5)
                    .blendMode(.plusLighter)
            )
            .shadow(
                color: base.opacity(isEnabled ? 0.42 : 0.2),
                radius: isPressed ? 4 : 12,
                x: 0,
                y: isPressed ? 2 : 7
            )
    }
}

/// アイコンと文字を縦に並べた定番のかたち。
struct IconTitleButton: View {
    @Environment(\.piyoLayout) private var layout

    var systemImage: String
    var title: String
    var color: Color = PiyoTheme.primary
    var minHeight: CGFloat?
    var action: () -> Void

    var body: some View {
        BigButton(color: color, minHeight: minHeight ?? CGFloat(layout.sized(116)), action: action) {
            VStack(spacing: 10) {
                // アイコンを丸で囲うと、色の面の上でも形が読み取りやすい。
                Image(systemName: systemImage)
                    .font(.system(size: CGFloat(layout.fontSize(32)), weight: .bold))
                    .frame(
                        width: CGFloat(layout.sized(56)),
                        height: CGFloat(layout.sized(56))
                    )
                    .background(Circle().fill(Color.white.opacity(0.22)))
                Text(title)
                    .piyoFont(.headline)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
            .padding(.vertical, 12)
        }
    }
}

/// 丸い戻るボタン。
struct BackCircleButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 28, weight: .heavy))
                .foregroundStyle(PiyoTheme.text)
                .frame(width: 64, height: 64)
                .background(Circle().fill(PiyoTheme.surface).shadow(color: .black.opacity(0.08), radius: 6, y: 3))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("もどる")
    }
}

/// 白いカード風の大きな選択肢ボタン。
struct ChoiceCardButton<Content: View>: View {
    @Environment(\.piyoLayout) private var layout

    var isHighlighted: Bool = false
    var highlightColor: Color = PiyoTheme.primary
    var action: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        Button(action: action) {
            content
                .frame(maxWidth: .infinity, minHeight: CGFloat(layout.sized(104)))
                .background(
                    RoundedRectangle(cornerRadius: PiyoTheme.cornerRadius, style: .continuous)
                        .fill(isHighlighted ? highlightColor.opacity(0.10) : PiyoTheme.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: PiyoTheme.cornerRadius, style: .continuous)
                        .stroke(
                            isHighlighted ? highlightColor : PiyoTheme.outline.opacity(0.8),
                            lineWidth: isHighlighted ? 6 : 2
                        )
                )
                // 選んだものは、色と縁だけでなく形でも分かるようにする。
                .overlay(alignment: .topTrailing) {
                    if isHighlighted {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(highlightColor)
                            .padding(10)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .shadow(
                    color: PiyoTheme.shadow.opacity(isHighlighted ? 0.14 : 0.08),
                    radius: isHighlighted ? 14 : 8,
                    y: 5
                )
                .scaleEffect(isHighlighted ? 1.02 : 1.0)
                .animation(.spring(response: 0.28, dampingFraction: 0.75), value: isHighlighted)
        }
        .buttonStyle(.plain)
    }
}
