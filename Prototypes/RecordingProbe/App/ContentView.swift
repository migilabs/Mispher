// PROTOTYPE, throwaway. One screen: settings, start/stop, file checks and the live log.
import SwiftUI

struct ContentView: View {
    @ObservedObject private var recorder = ProbeRecorder.shared
    @ObservedObject private var log = ProbeLog.shared
    @AppStorage("mode") private var mode = ProbeMode.recorderM4A.rawValue
    @AppStorage("highQuality") private var highQuality = true
    @AppStorage("noAlertInterruptions") private var noAlertInterruptions = false
    @AppStorage("mixWithOthers") private var mixWithOthers = false
    @State private var files: [URL] = []

    var body: some View {
        NavigationStack {
            List {
                Section("Status") {
                    Text(recorder.status)
                    Button(recorder.isRecording ? "Stop" : "Start (in app)") {
                        Task {
                            if recorder.isRecording {
                                await recorder.stop(trigger: "in-app-button")
                            } else {
                                await recorder.start(trigger: "in-app-button")
                            }
                            files = recorder.recordingFiles()
                        }
                    }
                    Button("Log route now") { recorder.logRoute("manual") }
                }

                Section("Settings (apply at next Start)") {
                    Picker("Recorder", selection: $mode) {
                        ForEach(ProbeMode.allCases) { Text($0.label).tag($0.rawValue) }
                    }
                    Toggle("AirPods high-quality mode", isOn: $highQuality)
                    Toggle("No interruptions from system alerts", isOn: $noAlertInterruptions)
                    Toggle("Mixable session (.mixWithOthers)", isOn: $mixWithOthers)
                }

                Section("Recordings") {
                    ForEach(files, id: \.self) { Text($0.lastPathComponent).font(.caption) }
                    Button("Check all files") {
                        recorder.checkFiles()
                        files = recorder.recordingFiles()
                    }
                }

                Section("Log") {
                    ShareLink("Share log file", item: log.fileURL)
                    ForEach(Array(log.lines.enumerated().reversed()), id: \.offset) { entry in
                        Text(entry.element).font(.caption2.monospaced())
                    }
                }

                Section("Reset") {
                    Button("End stale Live Activities") {
                        Task { await recorder.endStaleLiveActivities() }
                    }
                    Button("Delete log and recordings", role: .destructive) {
                        recorder.deleteRecordings()
                        log.clear()
                        files = []
                    }
                }
            }
            .navigationTitle("Rec Probe")
            .onAppear { files = recorder.recordingFiles() }
        }
    }
}
