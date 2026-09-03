import PuckaroundKit
import SwiftUI

@main
struct PuckaroundApp: App {
    /// The seeded ephemeral store when launched with `-puckaround-demo`
    /// (the screenshot stage — see `DemoMode`), else the real one.
    private let demoStore = DemoMode.storeIfRequested()

    var body: some Scene {
        WindowGroup {
            AppRoot()
                .defaultAppStorage(demoStore ?? .standard)
        }
    }
}
