import SwiftUI
import PiyoCore

struct RootView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var hasCheckedLaunchAd = false

    var body: some View {
        // 画面の実寸から寸法を決めて下へ配る。回転・分割表示にそのまま追従する。
        PiyoLayoutReader {
            content
        }
    }

    private var content: some View {
        ZStack {
            if environment.profile == nil {
                OnboardingView()
                    .transition(.opacity)
            } else {
                HomeView()
                    .transition(.opacity)
            }

            if environment.isShowingLaunchAd {
                LaunchAdView {
                    environment.isShowingLaunchAd = false
                }
                .transition(.opacity)
                .zIndex(10)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: environment.profile?.id)
        .animation(.easeInOut(duration: 0.25), value: environment.isShowingLaunchAd)
        .onAppear {
            guard !hasCheckedLaunchAd else { return }
            hasCheckedLaunchAd = true
            // 広告は起動時のみ。学習中・ご飯タイマー中は表示しない。
            if environment.adPresenter.shouldPresentLaunchAd(adsRemoved: environment.settings.adsRemoved) {
                environment.adPresenter.markLaunchAdPresented()
                environment.isShowingLaunchAd = true
            }
        }
    }
}

/// 起動時にだけ出す広告枠。
/// 実際の広告 SDK を入れるときは、この View の中身だけを差し替えればよい。
struct LaunchAdView: View {
    var onClose: () -> Void

    /// 子どもの誤タップを防ぐため、閉じるボタンは少し待ってから有効にする。
    @State private var remainingSeconds = 3

    var body: some View {
        ZStack {
            Color.black.opacity(0.82).ignoresSafeArea()

            VStack(spacing: 24) {
                HStack {
                    Spacer()
                    Button(action: onClose) {
                        HStack(spacing: 8) {
                            Image(systemName: "xmark")
                            Text(remainingSeconds > 0 ? "\(remainingSeconds)" : "とじる")
                        }
                        .piyoFont(.body)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 22)
                        .frame(height: 56)
                        .background(Capsule().fill(Color.white.opacity(remainingSeconds > 0 ? 0.15 : 0.32)))
                    }
                    .buttonStyle(.plain)
                    .disabled(remainingSeconds > 0)
                    .accessibilityIdentifier(A11yID.launchAdClose)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)

                Spacer()

                VStack(spacing: 16) {
                    Image(systemName: "megaphone.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.white.opacity(0.9))
                    Text("ひろこく")
                        .piyoFont(.headline)
                        .foregroundStyle(.white)
                    Text("この枠に広告が表示されます。\n学習中とごはんタイマー中には表示されません。")
                        .piyoFont(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.75))
                }
                .padding(32)
                .frame(maxWidth: 420)
                .background(
                    RoundedRectangle(cornerRadius: PiyoTheme.cornerRadius, style: .continuous)
                        .fill(Color.white.opacity(0.10))
                )

                Spacer()
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(A11yID.launchAd)
        .onAppear(perform: startCountdown)
    }

    private func startCountdown() {
        guard remainingSeconds > 0 else { return }
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            Task { @MainActor in
                remainingSeconds -= 1
                if remainingSeconds <= 0 {
                    timer.invalidate()
                }
            }
        }
    }
}
