import SwiftUI
import PiyoCore

/// 保護者画面へ入る前のゲート。子どもが偶然通り抜けられないようにする。
struct ParentGateView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.piyoLayout) private var layout

    var onPass: () -> Void
    var onCancel: () -> Void

    @State private var model = ParentGateViewModel()
    @State private var showsError = false

    private let digits = [1, 2, 3, 4, 5, 6, 7, 8, 9]

    var body: some View {
        ZStack {
            PiyoTheme.surfaceSunken.ignoresSafeArea()

            VStack(spacing: CGFloat(layout.sized(16))) {
                HStack {
                    Button("とじる", action: onCancel)
                        .piyoFont(.body)
                        .foregroundStyle(PiyoTheme.textSoft)
                        .accessibilityIdentifier(A11yID.parentGateCancel)
                    Spacer()
                }

                gateBody

                if showsError {
                    Text("もういちど おねがいします")
                        .piyoFont(.caption)
                        .foregroundStyle(.red)
                }

                Spacer(minLength: 0)
            }
            .padding(CGFloat(layout.sized(20)))
            .frame(maxWidth: layout.shape.isLandscape ? 720 : 420)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(A11yID.parentGate)
    }

    /// 横向きは、問題と数字パッドを左右に置く。
    /// 縦に積むと、高さ 390pt の画面で数字パッドが下に出てしまう。
    @ViewBuilder
    private var gateBody: some View {
        if layout.shape.isLandscape {
            HStack(alignment: .top, spacing: CGFloat(layout.spacing)) {
                VStack(spacing: 12) { lockMark; instruction; question; inputField }
                    .frame(maxWidth: .infinity)
                keypad
                    .frame(maxWidth: .infinity)
            }
        } else {
            VStack(spacing: CGFloat(layout.sized(18))) {
                lockMark
                instruction
                question
                inputField
                keypad
            }
        }
    }

    private var lockMark: some View {
        Image(systemName: "lock.shield.fill")
            .font(.system(size: CGFloat(layout.fontSize(40))))
            .foregroundStyle(PiyoTheme.textSoft)
    }

    private var instruction: some View {
        Text(ParentGate.instructionText)
            .piyoFont(.caption)
            .foregroundStyle(PiyoTheme.textSoft)
            .multilineTextAlignment(.center)
    }

    private var question: some View {
        Text(model.questionText)
            .piyoFont(size: 40, weight: .heavy)
            .foregroundStyle(PiyoTheme.text)
            .accessibilityIdentifier(A11yID.parentGateQuestion)
    }

    private var inputField: some View {
        Text(model.input.isEmpty ? "—" : model.input)
            .piyoFont(size: 40, weight: .heavy)
            .foregroundStyle(showsError ? .red : PiyoTheme.primaryDeep)
            .frame(maxWidth: .infinity, minHeight: CGFloat(layout.sized(64)))
            .background(
                RoundedRectangle(cornerRadius: PiyoTheme.smallCornerRadius)
                    .fill(PiyoTheme.surface)
            )
    }

    private var keypad: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3),
            spacing: 10
        ) {
            ForEach(digits, id: \.self) { digit in
                padButton("\(digit)") { model.append(digit: digit) }
                    .accessibilityIdentifier("\(A11yID.parentGateDigit)\(digit)")
            }
            padButton("C") { model.clear() }
            padButton("0") { model.append(digit: 0) }
                .accessibilityIdentifier("\(A11yID.parentGateDigit)0")
            Button(action: submit) {
                Image(systemName: "arrow.right")
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: padHeight)
                    .background(RoundedRectangle(cornerRadius: 14).fill(PiyoTheme.primary))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(A11yID.parentGateSubmit)
        }
    }

    /// 保護者が押すので、子ども向けほど大きくしなくてよい。
    private var padHeight: CGFloat { CGFloat(layout.sized(56)) }

    private func padButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .piyoFont(size: 26, weight: .heavy)
                .foregroundStyle(PiyoTheme.text)
                .frame(maxWidth: .infinity, minHeight: padHeight)
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
