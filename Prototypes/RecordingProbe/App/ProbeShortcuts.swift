// PROTOTYPE, throwaway. Makes the intents available in Shortcuts, so Back Tap can run them.
import AppIntents

struct ProbeShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartBackgroundRecordingIntent(),
            phrases: ["Start \(.applicationName) background recording"],
            shortTitle: "Start (background)",
            systemImageName: "mic.fill"
        )
        AppShortcut(
            intent: StartForegroundRecordingIntent(),
            phrases: ["Start \(.applicationName) recording in the app"],
            shortTitle: "Start (open app)",
            systemImageName: "mic"
        )
        AppShortcut(
            intent: StopRecordingIntent(),
            phrases: ["Stop \(.applicationName) recording"],
            shortTitle: "Stop",
            systemImageName: "stop.fill"
        )
    }
}
