import SwiftUI

/// 幼児でも押しやすい大きなボタン。
struct BigButton<Label: View>: View {
    var color: Color = PiyoTheme.primary
    var minHeight: CGFloat = PiyoTheme.minimumTapSize
    var isEnabled: Bool = true
    var action: () -> Void
    @ViewBuilder var label: Label

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            guard isEnabled else { return }
            action()
        }) {
            label
                .frame(maxWidth: .infinity, minHeight: minHeight)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: PiyoTheme.cornerRadius, style: .continuous)
                        .fill(isEnabled ? color : PiyoTheme.outline)
                        .shadow(
                            color: (isEnabled ? color : PiyoTheme.outline).opacity(0.45),
                            radius: isPressed ? 3 : 10,
                            x: 0,
                            y: isPressed ? 2 : 6
                        )
                )
                .foregroundStyle(.white)
                .scaleEffect(isPressed ? 0.97 : 1.0)
                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isPressed)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

/// アイコンと文字を縦に並べた定番のかたち。
struct IconTitleButton: View {
    var systemImage: String
    var title: String
    var color: Color = PiyoTheme.primary
    var minHeight: CGFloat = 120
    var action: () -> Void

    var body: some View {
        BigButton(color: color, minHeight: minHeight, action: action) {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 40, weight: .bold))
                Text(title)
                    .font(PiyoTheme.headlineFont)
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
    var isHighlighted: Bool = false
    var highlightColor: Color = PiyoTheme.primary
    var action: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        Button(action: action) {
            content
                .frame(maxWidth: .infinity, minHeight: 110)
                .background(
                    RoundedRectangle(cornerRadius: PiyoTheme.cornerRadius, style: .continuous)
                        .fill(PiyoTheme.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: PiyoTheme.cornerRadius, style: .continuous)
                        .stroke(isHighlighted ? highlightColor : PiyoTheme.outline, lineWidth: isHighlighted ? 6 : 3)
                )
                .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }
}
