// PROTOTYPE, throwaway. Two controls for Control Center and the Lock Screen, plus the Live
// Activity that AudioRecordingIntent requires while recording.
import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

@main
struct ProbeWidgets: WidgetBundle {
    var body: some Widget {
        ProbeBackgroundStartControl()
        ProbeForegroundStartControl()
        ProbeLiveActivity()
    }
}

/// Checklist item 1: start without opening the app.
struct ProbeBackgroundStartControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.migilabs.mispher.recordingprobe.start-background") {
            ControlWidgetButton(action: StartBackgroundRecordingIntent()) {
                Label("Probe: background", systemImage: "mic.fill")
            }
        }
        .displayName("Probe start (background)")
    }
}

/// Checklist item 1, fallback: start by opening the app.
struct ProbeForegroundStartControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.migilabs.mispher.recordingprobe.start-foreground") {
            ControlWidgetButton(action: StartForegroundRecordingIntent()) {
                Label("Probe: open app", systemImage: "mic")
            }
        }
        .displayName("Probe start (open app)")
    }
}

struct ProbeLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ProbeActivityAttributes.self) { context in
            HStack {
                Image(systemName: "mic.fill")
                VStack(alignment: .leading) {
                    Text("Rec Probe: \(context.state.status)")
                    Text(context.state.startedAt, style: .timer)
                        .monospacedDigit()
                }
                Spacer()
                Button(intent: StopRecordingIntent()) {
                    Label("Stop", systemImage: "stop.fill")
                }
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "mic.fill")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.startedAt, style: .timer)
                        .monospacedDigit()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Button(intent: StopRecordingIntent()) {
                        Label("Stop", systemImage: "stop.fill")
                    }
                }
            } compactLeading: {
                Image(systemName: "mic.fill")
            } compactTrailing: {
                Text(context.state.startedAt, style: .timer)
                    .monospacedDigit()
                    .frame(width: 44)
            } minimal: {
                Image(systemName: "mic.fill")
            }
        }
    }
}
