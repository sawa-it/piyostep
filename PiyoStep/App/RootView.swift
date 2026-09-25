import SwiftUI
import PiyoCore

struct RootView: View {
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        ZStack {
            if environment.profile == nil {
                OnboardingView()
                    .transition(.opacity)
            } else {
                HomeView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: environment.profile?.id)
    }
}
