import SwiftUI
import PiyoCore

@main
struct PiyoStepApp: App {
    @State private var environment: AppEnvironment

    init() {
        let created = AppEnvironmentFactory.makeLive()
        created.bootstrap()
        _environment = State(initialValue: created)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(environment)
                .task {
                    await environment.loadPurchases()
                }
        }
    }
}
