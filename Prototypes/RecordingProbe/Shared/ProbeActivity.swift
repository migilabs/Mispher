// PROTOTYPE, throwaway. Shared by the app and the widget extension.
import ActivityKit
import Foundation

struct ProbeActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var status: String
        var startedAt: Date
    }

    /// Which entry point started the Recording, e.g. "intent-background".
    var trigger: String
}
