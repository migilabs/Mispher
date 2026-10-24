// PROTOTYPE, throwaway. Records with one of three recorder setups and logs everything the
// device test needs: timings, route, interruptions, engine changes, file survival.
import ActivityKit
import AVFoundation
import UIKit

enum ProbeMode: String, CaseIterable, Identifiable {
    case recorderM4A = "recorder-m4a"
    case engineCAF = "engine-caf"
    case engineChunks = "engine-chunks-m4a"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .recorderM4A: return "AVAudioRecorder → one .m4a"
        case .engineCAF: return "AVAudioEngine → one .caf"
        case .engineChunks: return "AVAudioEngine → 30 s .m4a chunks"
        }
    }
}

enum ProbeError: Error {
    case recordFailed
    case noInput
}

@MainActor
final class ProbeRecorder: ObservableObject {
    static let shared = ProbeRecorder()

    static let recordingsDir: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    @Published private(set) var isRecording = false
    @Published private(set) var status = "Idle"

    private let session = AVAudioSession.sharedInstance()
    private let log = ProbeLog.shared
    private var mode: ProbeMode = .recorderM4A
    private var recorder: AVAudioRecorder?
    private var engine: AVAudioEngine?
    private var writer: EngineWriter?
    private var activity: Activity<ProbeActivityAttributes>?
    private var recordingName = ""
    private var segment = 0
    private var startUptime: TimeInterval = 0
    private var firstAudioTimer: Timer?

    private init() {
        let center = NotificationCenter.default
        center.addObserver(forName: AVAudioSession.interruptionNotification, object: session, queue: .main) { [weak self] note in
            MainActor.assumeIsolated { self?.handleInterruption(note) }
        }
        center.addObserver(forName: AVAudioSession.routeChangeNotification, object: session, queue: .main) { [weak self] note in
            MainActor.assumeIsolated { self?.handleRouteChange(note) }
        }
        center.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: session, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.handleMediaServicesReset() }
        }
        center.addObserver(forName: .AVAudioEngineConfigurationChange, object: nil, queue: .main) { [weak self] note in
            MainActor.assumeIsolated { self?.handleEngineConfigurationChange(note) }
        }
    }

    // MARK: Start and stop

    func start(trigger: String) async {
        let t0 = ProcessInfo.processInfo.systemUptime
        log.log("START requested trigger=\(trigger) appState=\(Self.appState())")
        guard !isRecording else {
            log.log("START ignored: already recording")
            return
        }
        let defaults = UserDefaults.standard
        mode = ProbeMode(rawValue: defaults.string(forKey: "mode") ?? "") ?? .recorderM4A
        let highQuality = defaults.object(forKey: "highQuality") as? Bool ?? true
        let noAlertInterruptions = defaults.bool(forKey: "noAlertInterruptions")
        startUptime = t0
        segment = 0
        recordingName = Self.timestamp()

        // AudioRecordingIntent: the recording stops unless a Live Activity runs for its whole length.
        startLiveActivity(trigger: trigger)

        do {
            var options: AVAudioSession.CategoryOptions = [.allowBluetoothHFP]
            if highQuality { options.insert(.bluetoothHighQualityRecording) }
            try session.setCategory(.playAndRecord, mode: .default, options: options)
            try session.setPrefersNoInterruptionsFromSystemAlerts(noAlertInterruptions)
            try session.setActive(true)
            log.log("session active after \(Self.ms(since: t0)) ms (highQuality=\(highQuality) noAlertInterruptions=\(noAlertInterruptions))")
        } catch {
            log.log("session activation FAILED after \(Self.ms(since: t0)) ms: \(describe(error))")
            status = "Session refused"
            await endLiveActivity()
            return
        }
        logRoute("at start")

        do {
            try beginSegment(reason: "start")
        } catch {
            log.log("recording FAILED to start: \(describe(error))")
            status = "Start failed"
            await endLiveActivity()
            return
        }
        isRecording = true
        status = "Recording: \(mode.label)"
    }

    func stop(trigger: String) async {
        log.log("STOP requested trigger=\(trigger) appState=\(Self.appState())")
        firstAudioTimer?.invalidate()
        firstAudioTimer = nil
        recorder?.stop()
        recorder = nil
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
        writer?.finish()
        writer = nil
        do {
            try session.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            log.log("session deactivation failed: \(describe(error))")
        }
        let segments = segment
        isRecording = false
        status = "Idle"
        await endLiveActivity()
        log.log("STOP done, segments=\(segments)")
    }

    // MARK: Segments

    private func beginSegment(reason: String) throws {
        segment += 1
        let base = "\(recordingName)-\(mode.rawValue)-seg\(segment)"
        switch mode {
        case .recorderM4A:
            let url = Self.recordingsDir.appendingPathComponent(base + ".m4a")
            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: session.sampleRate,
                AVNumberOfChannelsKey: 1,
                AVEncoderBitRateKey: 32_000,
            ]
            let newRecorder = try AVAudioRecorder(url: url, settings: settings)
            guard newRecorder.record() else { throw ProbeError.recordFailed }
            recorder = newRecorder
            watchFirstAudio(of: newRecorder)
        case .engineCAF, .engineChunks:
            let newEngine = AVAudioEngine()
            let input = newEngine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0 else { throw ProbeError.noInput }
            let newWriter = try EngineWriter(
                directory: Self.recordingsDir,
                baseName: base,
                format: format,
                chunkSeconds: mode == .engineChunks ? 30 : nil,
                startUptime: startUptime,
                log: log
            )
            input.installTap(onBus: 0, bufferSize: 4096, format: format) { buffer, _ in
                newWriter.write(buffer)
            }
            newEngine.prepare()
            try newEngine.start()
            engine = newEngine
            writer = newWriter
        }
        log.log("SEGMENT \(segment) started (\(reason)) mode=\(mode.rawValue) sampleRate=\(session.sampleRate) inputChannels=\(session.inputNumberOfChannels)")
    }

    /// AVAudioRecorder has no buffer callback, so poll until audio arrives.
    private func watchFirstAudio(of recorder: AVAudioRecorder) {
        firstAudioTimer?.invalidate()
        let since = startUptime
        firstAudioTimer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { [weak self] timer in
            MainActor.assumeIsolated {
                guard recorder.currentTime > 0 else { return }
                self?.log.log("first audio after \(Self.ms(since: since)) ms since START (AVAudioRecorder)")
                timer.invalidate()
            }
        }
    }

    // MARK: Notifications

    private func handleInterruption(_ note: Notification) {
        guard let info = note.userInfo,
              let typeRaw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeRaw) else { return }
        let reasonRaw = info[AVAudioSessionInterruptionReasonKey] as? UInt
        let reason = reasonRaw.map(Self.interruptionReasonName) ?? "none"
        switch type {
        case .began:
            log.log("INTERRUPTION began reason=\(reason) appState=\(Self.appState()) recorder.isRecording=\(recorder?.isRecording ?? false) engine.isRunning=\(engine?.isRunning ?? false)")
            if isRecording { status = "Interrupted" }
        case .ended:
            let optionsRaw = info[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let shouldResume = AVAudioSession.InterruptionOptions(rawValue: optionsRaw).contains(.shouldResume)
            log.log("INTERRUPTION ended shouldResume=\(shouldResume) reason=\(reason) appState=\(Self.appState())")
            if isRecording { resume(after: "interruption") }
        @unknown default:
            log.log("INTERRUPTION unknown type raw=\(typeRaw)")
        }
    }

    private func resume(after cause: String) {
        do {
            try session.setActive(true)
            log.log("session reactivated after \(cause) appState=\(Self.appState())")
        } catch {
            log.log("session reactivation REFUSED after \(cause) appState=\(Self.appState()): \(describe(error))")
            status = "Resume refused"
            return
        }
        switch mode {
        case .recorderM4A:
            if let recorder {
                let resumed = recorder.record()
                log.log("AVAudioRecorder.record() after \(cause) -> \(resumed), currentTime=\(String(format: "%.1f", recorder.currentTime)) s")
            }
        case .engineCAF, .engineChunks:
            restartEngineSegment(reason: "resume after \(cause)")
        }
        status = "Recording: \(mode.label)"
    }

    private func handleRouteChange(_ note: Notification) {
        let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt ?? 999
        let reason = AVAudioSession.RouteChangeReason(rawValue: raw).map(Self.routeChangeReasonName) ?? "raw \(raw)"
        let previous = (note.userInfo?[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription)
            .map { Self.describeInputs($0.inputs) } ?? "?"
        log.log("ROUTE CHANGE reason=\(reason) previousInputs=[\(previous)] appState=\(Self.appState())")
        logRoute("after route change")
        guard isRecording, mode == .recorderM4A, let recorder else { return }
        log.log("AVAudioRecorder right after route change: isRecording=\(recorder.isRecording) currentTime=\(String(format: "%.1f", recorder.currentTime)) s")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            MainActor.assumeIsolated {
                guard let self, let recorder = self.recorder else { return }
                self.log.log("AVAudioRecorder 2 s after route change: isRecording=\(recorder.isRecording) currentTime=\(String(format: "%.1f", recorder.currentTime)) s")
            }
        }
    }

    private func handleEngineConfigurationChange(_ note: Notification) {
        guard let changed = note.object as? AVAudioEngine, changed === engine else { return }
        log.log("ENGINE CONFIGURATION CHANGE isRunning=\(changed.isRunning) appState=\(Self.appState())")
        guard isRecording else { return }
        restartEngineSegment(reason: "engine configuration change")
    }

    private func restartEngineSegment(reason: String) {
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
        writer?.finish()
        writer = nil
        do {
            try beginSegment(reason: reason)
        } catch {
            log.log("new segment FAILED (\(reason)): \(describe(error))")
            status = "Segment failed"
        }
    }

    private func handleMediaServicesReset() {
        log.log("MEDIA SERVICES RESET appState=\(Self.appState()); recording objects are now invalid")
        recorder = nil
        engine = nil
        writer?.finish()
        writer = nil
        if isRecording { status = "Media services reset" }
    }

    // MARK: Route logging

    func logRoute(_ context: String) {
        let inputs = Self.describeInputs(session.currentRoute.inputs)
        let available = (session.availableInputs ?? []).map { $0.portType.rawValue }.joined(separator: ", ")
        log.log("ROUTE \(context): inputs=[\(inputs)] available=[\(available)] sampleRate=\(session.sampleRate) inputChannels=\(session.inputNumberOfChannels) ioBuffer=\(String(format: "%.4f", session.ioBufferDuration))")
    }

    nonisolated private static func describeInputs(_ ports: [AVAudioSessionPortDescription]) -> String {
        ports.map { port in
            var text = "\(port.portType.rawValue) '\(port.portName)'"
            if let bluetooth = port.bluetoothMicrophoneExtension {
                let hq = bluetooth.highQualityRecording
                text += " hq.supported=\(hq.isSupported) hq.enabled=\(hq.isEnabled)"
            }
            return text
        }.joined(separator: ", ")
    }

    // MARK: Live Activity

    private func startLiveActivity(trigger: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            log.log("Live Activities are turned off for this app")
            return
        }
        let state = ProbeActivityAttributes.ContentState(status: "Recording", startedAt: Date())
        do {
            activity = try Activity.request(
                attributes: ProbeActivityAttributes(trigger: trigger),
                content: ActivityContent(state: state, staleDate: nil)
            )
            log.log("Live Activity started id=\(activity?.id ?? "?")")
        } catch {
            log.log("Live Activity FAILED: \(describe(error))")
        }
    }

    private func endLiveActivity() async {
        guard let current = activity else { return }
        let final = ProbeActivityAttributes.ContentState(status: "Stopped", startedAt: current.content.state.startedAt)
        await current.end(ActivityContent(state: final, staleDate: nil), dismissalPolicy: .immediate)
        activity = nil
        log.log("Live Activity ended")
    }

    /// Ends Live Activities left over from a run that was killed.
    func endStaleLiveActivities() async {
        for stale in Activity<ProbeActivityAttributes>.activities where stale.id != activity?.id {
            await stale.end(nil, dismissalPolicy: .immediate)
            log.log("ended stale Live Activity id=\(stale.id)")
        }
    }

    // MARK: File checks (checklist item 3)

    func recordingFiles() -> [URL] {
        let urls = (try? FileManager.default.contentsOfDirectory(at: Self.recordingsDir, includingPropertiesForKeys: nil)) ?? []
        return urls.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    func checkFiles() {
        let files = recordingFiles()
        log.log("CHECK \(files.count) file(s)")
        for url in files {
            let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? -1
            do {
                let file = try AVAudioFile(forReading: url)
                let seconds = Double(file.length) / file.processingFormat.sampleRate
                log.log("CHECK \(url.lastPathComponent): readable, \(String(format: "%.1f", seconds)) s, \(size) bytes")
            } catch {
                log.log("CHECK \(url.lastPathComponent): UNREADABLE, \(size) bytes, \(describe(error))")
            }
        }
    }

    func deleteRecordings() {
        for url in recordingFiles() { try? FileManager.default.removeItem(at: url) }
        log.log("deleted all recordings")
    }

    // MARK: Helpers

    static func appState() -> String {
        switch UIApplication.shared.applicationState {
        case .active: return "active"
        case .inactive: return "inactive"
        case .background: return "background"
        @unknown default: return "unknown"
        }
    }

    nonisolated private static func ms(since start: TimeInterval) -> Int {
        Int((ProcessInfo.processInfo.systemUptime - start) * 1000)
    }

    nonisolated private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }

    nonisolated private static func interruptionReasonName(_ raw: UInt) -> String {
        guard let reason = AVAudioSession.InterruptionReason(rawValue: raw) else { return "raw \(raw)" }
        switch reason {
        case .default: return "default"
        case .builtInMicMuted: return "builtInMicMuted"
        case .routeDisconnected: return "routeDisconnected"
        default: return "raw \(raw)"
        }
    }

    nonisolated private static func routeChangeReasonName(_ reason: AVAudioSession.RouteChangeReason) -> String {
        switch reason {
        case .unknown: return "unknown"
        case .newDeviceAvailable: return "newDeviceAvailable"
        case .oldDeviceUnavailable: return "oldDeviceUnavailable"
        case .categoryChange: return "categoryChange"
        case .override: return "override"
        case .wakeFromSleep: return "wakeFromSleep"
        case .noSuitableRouteForCategory: return "noSuitableRouteForCategory"
        case .routeConfigurationChange: return "routeConfigurationChange"
        @unknown default: return "raw \(reason.rawValue)"
        }
    }
}

/// Writes engine buffers on the audio thread: one .caf, or rotating 30 s AAC chunks.
final class EngineWriter: @unchecked Sendable {
    private let lock = NSLock()
    private let directory: URL
    private let baseName: String
    private let format: AVAudioFormat
    private let chunkFrames: AVAudioFramePosition?
    private let startUptime: TimeInterval
    private let log: ProbeLog
    private var file: AVAudioFile?
    private var chunk = 0
    private var framesInChunk: AVAudioFramePosition = 0
    private var sawFirstBuffer = false

    init(directory: URL, baseName: String, format: AVAudioFormat, chunkSeconds: Double?, startUptime: TimeInterval, log: ProbeLog) throws {
        self.directory = directory
        self.baseName = baseName
        self.format = format
        self.chunkFrames = chunkSeconds.map { AVAudioFramePosition($0 * format.sampleRate) }
        self.startUptime = startUptime
        self.log = log
        try openNextFile()
    }

    func write(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        defer { lock.unlock() }
        if !sawFirstBuffer {
            sawFirstBuffer = true
            let ms = Int((ProcessInfo.processInfo.systemUptime - startUptime) * 1000)
            log.log("first audio after \(ms) ms since START (AVAudioEngine, \(format.sampleRate) Hz, \(format.channelCount) ch)")
        }
        do {
            if let limit = chunkFrames, framesInChunk >= limit {
                file?.close()
                try openNextFile()
            }
            try file?.write(from: buffer)
            framesInChunk += AVAudioFramePosition(buffer.frameLength)
        } catch {
            log.log("engine write FAILED: \(describe(error))")
        }
    }

    func finish() {
        lock.lock()
        file?.close()
        file = nil
        lock.unlock()
    }

    private func openNextFile() throws {
        chunk += 1
        framesInChunk = 0
        if chunkFrames != nil {
            let url = directory.appendingPathComponent("\(baseName)-chunk\(chunk).m4a")
            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: format.sampleRate,
                AVNumberOfChannelsKey: format.channelCount,
                AVEncoderBitRateKey: 32_000,
            ]
            file = try AVAudioFile(forWriting: url, settings: settings, commonFormat: format.commonFormat, interleaved: format.isInterleaved)
        } else {
            let url = directory.appendingPathComponent("\(baseName).caf")
            file = try AVAudioFile(forWriting: url, settings: format.settings, commonFormat: format.commonFormat, interleaved: format.isInterleaved)
        }
    }
}
