import SwiftUI
import PiyoCore

/// 保護者画面へ入る前のゲート。子どもが偶然通り抜けられないようにする。
struct ParentGateView: View {
    @Environment(AppEnvironment.self) private var environment

    var onPass: () -> Void
    var onCancel: () -> Void

    @State private var model = ParentGateViewModel()
    @State private var showsError = false

    private let digits = [1, 2, 3, 4, 5, 6, 7, 8, 9]

    var body: some View {
        ZStack {
            PiyoTheme.surfaceSunken.ignoresSafeArea()

            VStack(spacing: 20) {
                HStack {
                    Button("とじる", action: onCancel)
                        .font(PiyoTheme.bodyFont)
                        .foregroundStyle(PiyoTheme.textSoft)
                        .accessibilityIdentifier(A11yID.parentGateCancel)
                    Spacer()
                }

                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(PiyoTheme.textSoft)

                Text(ParentGate.instructionText)
                    .font(PiyoTheme.captionFont)
                    .foregroundStyle(PiyoTheme.textSoft)
                    .multilineTextAlignment(.center)

                Text(model.questionText)
                    .font(PiyoTheme.childFont(size: 40, weight: .heavy))
                    .foregroundStyle(PiyoTheme.text)
                    .accessibilityIdentifier(A11yID.parentGateQuestion)

                Text(model.input.isEmpty ? "—" : model.input)
                    .font(PiyoTheme.childFont(size: 40, weight: .heavy))
                    .foregroundStyle(showsError ? .red : PiyoTheme.primaryDeep)
                    .frame(maxWidth: .infinity, minHeight: 72)
                    .background(
                        RoundedRectangle(cornerRadius: PiyoTheme.smallCornerRadius)
                            .fill(PiyoTheme.surface)
                    )

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
                            .frame(maxWidth: .infinity, minHeight: 60)
                            .background(RoundedRectangle(cornerRadius: 14).fill(PiyoTheme.primary))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(A11yID.parentGateSubmit)
                }

                if showsError {
                    Text("もういちど おねがいします")
                        .font(PiyoTheme.captionFont)
                        .foregroundStyle(.red)
                }

                Spacer(minLength: 0)
            }
            .padding(24)
            .frame(maxWidth: 420)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(A11yID.parentGate)
    }

    private func padButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(PiyoTheme.childFont(size: 26, weight: .heavy))
                .foregroundStyle(PiyoTheme.text)
                .frame(maxWidth: .infinity, minHeight: 60)
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
