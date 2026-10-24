# Recording probe (PROTOTYPE, throwaway)

A throwaway iPhone app for the Mispher map ticket [Device test: how does Recording behave on the iPhone 14 Pro Max?](https://github.com/migilabs/Mispher/issues/21). It records with one of three recorder setups and logs every event to `probe-log.txt`.

Lives on the `prototype/recording-probe` branch only, never merged. Mispher's real app starts fresh in P0 and takes only the facts this probe finds.

> Written without a compiler: the environment that wrote it has no Xcode. Every Apple API was checked against Apple's documentation, but expect a small fix or two on first build.

## Set up (once)

1. Install XcodeGen and generate the project:
   ```bash
   brew install xcodegen
   cd Prototypes/RecordingProbe
   xcodegen
   open RecordingProbe.xcodeproj
   ```
2. In Xcode, select your team under **Signing & Capabilities** for both targets, **RecordingProbe** and **RecordingProbeWidgets**.
3. Run on the iPhone. Allow microphone access the first time, by tapping **Start (in app)** once and then **Stop**.
4. Add both controls, **Probe start (background)** and **Probe start (open app)**, to Control Center, and one of them to the Lock Screen.
5. For Back Tap: in the Shortcuts app, create a shortcut that runs the Rec Probe action **Probe: start recording (background)**. Then choose that shortcut under Settings › Accessibility › Touch › Back Tap › Double Tap.

Settings in the app apply at the next Start. Use a test passage, never a real conversation.

## Checklist

Use the default recorder (**AVAudioRecorder → one .m4a**) unless a step says otherwise. After each step, tap **Stop**.

**1. Start from a control**
- 1a. Swipe the app away. Lock the phone. Tap **Probe start (background)** in Control Center (on the Lock Screen too). Does it record? The log shows `PROCESS LAUNCH`, `START requested`, `session active` or `session activation FAILED`, and `first audio after … ms`.
- 1b. Same with **Probe start (open app)**, Face ID included.
- 1c. Same with Back Tap, phone locked.
- Also note roughly how long from tap to the recording indicator, by eye.

**2. Interruptions while locked** (start, lock, then):
- 2a. Call yourself from another phone and decline.
- 2b. Call yourself and answer, talk 20 s, hang up.
- 2c. Siri ("Hey Siri, what time is it?").
- 2d. A timer going off.
- 2e. Unlock, start a voice memo in Voice Memos, stop it, lock again.
- 2f. Repeat 2a with **No interruptions from system alerts** on, and call alerts set to banner style.
- The log shows `INTERRUPTION began/ended`, `shouldResume`, and whether `session reactivated` or `reactivation REFUSED` (with an error such as `'!int'`).

**3. App killed mid-Recording** (for each of the three recorders):
- 3a. Swipe the app away while recording.
- 3b. While running from Xcode, press Stop in Xcode (a stand-in for the system killing it).
- Reopen the app and tap **Check all files**. The log shows `readable, … s` or `UNREADABLE` per file.

**4. AirPods Pro 2** (high-quality mode on):
- 4a. Start with AirPods in. The log line `ROUTE at start` shows `hq.supported` / `hq.enabled` and the sample rate.
- 4b. While recording: take one AirPod out, then both, put them in the case and close it, put them back in, and let them switch to the Mac (play something there).
- 4c. Repeat 4b with each engine recorder.
- The log shows each `ROUTE CHANGE reason=…`, what `AVAudioRecorder` does 0 and 2 s after the change, and `ENGINE CONFIGURATION CHANGE` with new segments for the engine recorders.
- 4d. Repeat 4a with high-quality mode off, to compare sample rates.

## Report back

Tap **Share log file**, or take `probe-log.txt` from Files › On My iPhone › Rec Probe. Paste the log, or a summary, into the ticket. The log holds no audio content, only events, routes and timings.
