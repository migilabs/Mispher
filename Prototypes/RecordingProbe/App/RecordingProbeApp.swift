// PROTOTYPE, throwaway. Entry point; logs process launches and lifecycle changes so a
// background start by an intent shows up in the log.
import SwiftUI
import UIKit

@main
struct RecordingProbeApp: App {
    @Environment(\.scenePhase) private var scenePhase

    init() {
        ProbeLog.shared.log("PROCESS LAUNCH")
        NotificationCenter.default.addObserver(forName: UIApplication.willTerminateNotification, object: nil, queue: .main) { _ in
            ProbeLog.shared.log("willTerminate")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .onChange(of: scenePhase) { _, phase in
            ProbeLog.shared.log("scenePhase=\(phase)")
        }
    }
}
