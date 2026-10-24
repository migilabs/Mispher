// PROTOTYPE, throwaway. Append-only event log: Documents/probe-log.txt, visible in the
// Files app (On My iPhone › Rec Probe) and shareable from the app.
import Foundation

final class ProbeLog: ObservableObject {
    static let shared = ProbeLog()

    @Published private(set) var lines: [String] = []

    let fileURL: URL
    private let queue = DispatchQueue(label: "probe.log")
    private let formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = docs.appendingPathComponent("probe-log.txt")
        if let existing = try? String(contentsOf: fileURL, encoding: .utf8) {
            lines = Array(existing.split(separator: "\n").suffix(300).map(String.init))
        }
    }

    /// Safe to call from any thread, including the audio render thread.
    func log(_ message: String) {
        let uptime = String(format: "%.3f", ProcessInfo.processInfo.systemUptime)
        let line = "\(formatter.string(from: Date())) up=\(uptime) \(message)"
        queue.async {
            if let data = (line + "\n").data(using: .utf8) {
                if let handle = try? FileHandle(forWritingTo: self.fileURL) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    try? handle.close()
                } else {
                    try? data.write(to: self.fileURL)
                }
            }
            DispatchQueue.main.async {
                self.lines.append(line)
                if self.lines.count > 300 { self.lines.removeFirst(self.lines.count - 300) }
            }
        }
    }

    func clear() {
        queue.async {
            try? FileManager.default.removeItem(at: self.fileURL)
            DispatchQueue.main.async { self.lines = [] }
        }
    }
}

/// Renders an OSStatus such as 560557684 as its four-character code ('!int').
func fourCC(_ code: Int) -> String {
    let value = UInt32(truncatingIfNeeded: code)
    let bytes = [24, 16, 8, 0].map { UInt8((value >> UInt32($0)) & 0xFF) }
    guard bytes.allSatisfy({ $0 >= 32 && $0 < 127 }) else { return String(code) }
    return "'" + String(decoding: bytes, as: UTF8.self) + "'"
}

func describe(_ error: Error) -> String {
    let ns = error as NSError
    return "\(ns.domain) \(ns.code) \(fourCC(ns.code)) \(ns.localizedDescription)"
}
