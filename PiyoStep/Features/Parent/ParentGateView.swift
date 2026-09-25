import SwiftUI
import PiyoCore

/// 保護者画面へ入る前のゲート。子どもが偶然通り抜けられないようにする。
struct ParentGateView: View {
    @Environment(AppEnvironment.self) private var environment

    var onPass: () -> Void
    var onCancel: () -> Void

    @State private var model = ParentGateViewModel()
    @State private var showsError = false

    private let digitRows = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]

    var body: some View {
        PiyoLayoutReader { _ in
            ZStack {
                PiyoTheme.surfaceSunken.ignoresSafeArea()

                VStack(spacing: 12) {
                    HStack {
                        Button("とじる", action: onCancel)
                            .font(PiyoTheme.bodyFont)
                            .foregroundStyle(PiyoTheme.textSoft)
                            .accessibilityIdentifier(A11yID.parentGateCancel)
                        Spacer()
                    }

                    // 横向きでは問題とキーパッドを左右に分ける。
                    // 縦に積んだままだと、横向きでキーパッドが画面の外に出てしまう。
                    AdaptivePanes(spacing: 20) {
                        question
                    } trailing: {
                        keypad
                    }
                }
                .padding(20)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(A11yID.parentGate)
    }

    private var question: some View {
        VStack(spacing: 14) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 40))
                .foregroundStyle(PiyoTheme.textSoft)

            Text(ParentGate.instructionText)
                .font(PiyoTheme.captionFont)
                .foregroundStyle(PiyoTheme.textSoft)
                .multilineTextAlignment(.center)

            Text(model.questionText)
                .font(PiyoTheme.childFont(size: 40, weight: .heavy))
                .foregroundStyle(PiyoTheme.text)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .accessibilityIdentifier(A11yID.parentGateQuestion)

            Text(model.input.isEmpty ? "—" : model.input)
                .font(PiyoTheme.childFont(size: 36, weight: .heavy))
                .foregroundStyle(showsError ? .red : PiyoTheme.primaryDeep)
                .frame(maxWidth: .infinity, minHeight: 64)
                .background(
                    RoundedRectangle(cornerRadius: PiyoTheme.smallCornerRadius)
                        .fill(PiyoTheme.surface)
                )

            if showsError {
                Text("もういちど おねがいします")
                    .font(PiyoTheme.captionFont)
                    .foregroundStyle(.red)
            }
        }
    }

    /// 12 個しかないので遅延生成しない。画面外のボタンも要素として存在させておく。
    private var keypad: some View {
        Grid(horizontalSpacing: 10, verticalSpacing: 10) {
            ForEach(digitRows, id: \.self) { row in
                GridRow {
                    ForEach(row, id: \.self) { digit in
                        padButton("\(digit)") { model.append(digit: digit) }
                            .accessibilityIdentifier("\(A11yID.parentGateDigit)\(digit)")
                    }
                }
            }
            GridRow {
                padButton("C") { model.clear() }
                padButton("0") { model.append(digit: 0) }
                    .accessibilityIdentifier("\(A11yID.parentGateDigit)0")
                Button(action: submit) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(RoundedRectangle(cornerRadius: 14).fill(PiyoTheme.primary))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(A11yID.parentGateSubmit)
            }
        }
        .frame(maxWidth: 420)
    }

    private func padButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(PiyoTheme.childFont(size: 26, weight: .heavy))
                .foregroundStyle(PiyoTheme.text)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(RoundedRectangle(cornerRadius: 14).fill(PiyoTheme.surface))
        }
        .buttonStyle(.plain)
    }

    private func submit() {
        if model.submit() {
            showsError = false
            onPass()
        } else {
            showsError = true
        }
    }
}
