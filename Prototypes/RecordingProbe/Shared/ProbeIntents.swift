// PROTOTYPE, throwaway. Compiled into both targets so controls and the Live Activity
// can reference the intents; `perform` only does work in the app process.
import AppIntents

/// Checklist item 1: start from a control without opening the app.
struct StartBackgroundRecordingIntent: AudioRecordingIntent, LiveActivityIntent {
    static let title: LocalizedStringResource = "Probe: start recording (background)"
    static let description: IntentDescription? = IntentDescription("Starts a probe Recording without opening the app.")

    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        await ProbeRecorder.shared.start(trigger: "intent-background")
        #endif
        return .result()
    }
}

/// Checklist item 1, fallback: start from a control by opening the app.
struct StartForegroundRecordingIntent: AppIntent {
    static let title: LocalizedStringResource = "Probe: start recording (open app)"
    static let description: IntentDescription? = IntentDescription("Opens the app and starts a probe Recording.")
    static let supportedModes: IntentModes = .foreground(.immediate)

    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        await ProbeRecorder.shared.start(trigger: "intent-foreground")
        #endif
        return .result()
    }
}

struct StopRecordingIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Probe: stop recording"

    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        await ProbeRecorder.shared.stop(trigger: "intent-stop")
        #endif
        return .result()
    }
}
