# What does iOS 26 allow for starting a Recording from a control and keeping it running 60+ minutes in the background?
Ticket: https://github.com/migilabs/Mispher/issues/5 · Researched 2026-10-24

## Answer

- **The documented path.** A Control Center or Lock Screen control runs an App Intent. To record without opening the app, the intent conforms to `AudioRecordingIntent` and `LiveActivityIntent`, starts a Live Activity, and keeps it running for the whole Recording. Apple says that without one "the audio recording stops". **High** (documentation).
- **Unproven on a locked phone with the app not running.** In Feb 2026 an Apple DTS engineer wrote that "a privacy block … prevents recording sessions from activating in the background". Developers on iOS 26 report activation failures. **Low** confidence that the background path works. This is device test #1.
- **The fallback.** An intent with `supportedModes = .foreground(.immediate)` opens the app. On a locked phone, Face ID comes first. **High** that it works; **unknown** whether it starts within 2 s.
- **Entry points on the 14 Pro Max.** Control Center control, Lock Screen control, Siri or Shortcuts (through App Shortcuts), and Back Tap running a Shortcut. It has no Action Button. **High**, except Back Tap while locked (**unverified**).
- **Running for 60+ minutes.** Needs `audio` in `UIBackgroundModes` plus an active `.playAndRecord` or `.record` session. Recording continues with the screen locked. No documented time limit; the Live Activity caps at 8 h. **High**.
- **Interruptions.** Every one stops capture, and the audio during it is lost. Resuming automatically works in the foreground. In the background, the normal locked case, reactivation is likely refused. **Medium-low**.

| Event | Capture stops? | Resumes automatically? | How the app finds out | Audio lost |
|---|---|---|---|---|
| Call/FaceTime declined | Yes, unless banner style + `setPrefersNoInterruptionsFromSystemAlerts(true)` | `.ended` is sent; background reactivation unverified (low) | `interruptionNotification` `.began`/`.ended` | Ringing time |
| Call/FaceTime answered | Yes | App may be suspended; reports say background `setActive` fails `'!int'` (medium-low) | `.began`; `.ended` late or never | Whole call and beyond |
| Siri | Yes | `.ended` + `.shouldResume`, possibly only after Siri's card is dismissed (low) | `.began`/`.ended` | Siri time |
| Alarm/timer | Yes | `.ended` after dismissal (medium); background reactivation unverified | `.began`/`.ended` | Until dismissed |
| Other app takes mic | Yes, nonmixable foreground app wins (medium) | Only if that app releases it; background restart likely refused | `.began`, reason `.default` | Until the user returns |
| Media services reset | Yes | Apple: wait for user action (high) | `mediaServicesWereResetNotification` | Until restart |
| Killed by system/user | Yes | No (high) | Possibly `applicationWillTerminate`, not guaranteed | Unfinalized tail, or the whole `.m4a` (gap) |

## Findings

### Starting from a control
- **Where controls live.** Controls appear in Control Center, on the Lock Screen and on the Action button, and each runs an App Intent ([Creating controls](https://developer.apple.com/documentation/widgetkit/creating-controls-to-perform-actions-across-the-system), [ControlWidgetButton](https://developer.apple.com/documentation/widgetkit/controlwidgetbutton)). The HIG recommends "launching a Live Activity from a control" ([HIG](https://developer.apple.com/design/human-interface-guidelines/controls)). The default `authenticationPolicy` lets an intent run "including when the device is locked" ([doc](https://developer.apple.com/documentation/appintents/appintent/authenticationpolicy)). High.
- **Process.** A widget intent runs in the extension. It runs in the app's process only if it is a `LiveActivityIntent`, `AudioPlaybackIntent`, `ForegroundContinuableIntent` or `PushToTalkTransmissionIntent`, or if it opens the app ([doc](https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities)). `AudioRecordingIntent` is not on that list, hence the pairing with `LiveActivityIntent`. High.
- **`AudioRecordingIntent`** (iOS 18+): "the system displays an audio recording indicator… you must start a Live Activity when you begin the audio recording and keep it active as long as you record audio" ([doc](https://developer.apple.com/documentation/appintents/audiorecordingintent)).
- **`LiveActivityIntent`**: "the system launches your app process without opening the app, performs the intent, and starts the Live Activity" ([doc](https://developer.apple.com/documentation/appintents/liveactivityintent)). WWDC24 says that for "recording" there are intents "that make it possible to do these things from the background" ([WWDC24 10176](https://developer.apple.com/videos/play/wwdc2024/10176/)).
- **iOS 26 changes.** `supportedModes` (`.background`, `.foreground(.immediate | .dynamic | .deferred)`) replaces the deprecated `openAppWhenRun` and `ForegroundContinuableIntent` ([doc](https://developer.apple.com/documentation/appintents/appintent/supportedmodes), [doc](https://developer.apple.com/documentation/appintents/appintent/openappwhenrun)). With `.dynamic`, the intent can call `continueInForeground`, which "will throw an error" if the launch is denied ([WWDC25 275](https://developer.apple.com/videos/play/wwdc2025/275/)).
- **Counter-evidence.**
  - DTS, Feb 2026, answering a question about a Bluetooth trigger: "There's a privacy block in place that prevents recording sessions from activating in the background." Only CallKit, LiveCommunicationKit and PushToTalk are exempt ([816408](https://developer.apple.com/forums/thread/816408)). He did not address intents started from system UI.
  - Unanswered iOS 26 threads: `setActive` fails with `'!pla'` in an `AudioRecordingIntent` on the Lock Screen ([836958](https://developer.apple.com/forums/thread/836958)); "Target is not foreground" when starting the Live Activity ([815725](https://developer.apple.com/forums/thread/815725), with a non-staff reply).
  - *Secondary (GitHub):* on a device, a Control Center control "recorded only after opening the app" ([sempere #29](https://github.com/anthonytw/sempere/pull/29)).
- **Latency and Back Tap.** Apple publishes no latency figure. Back Tap (Settings › Accessibility › Touch) can run a Shortcut ([Shortcuts guide](https://support.apple.com/guide/shortcuts/apd897693606/ios); host blocked here, content taken from a search result).

### Keeping it running
- **Background mode.** "To continue recording audio when your app transitions to the background (for example, when the screen locks), add the `audio` value" ([`.record`](https://developer.apple.com/documentation/avfaudio/avaudiosession/category-swift.struct/record)).
- **Category.** `.record` silences "virtually all output", so Apple recommends `.playAndRecord`, which is nonmixable by default ([doc](https://developer.apple.com/documentation/avfaudio/avaudiosession/category-swift.struct/playandrecord), archived [guidelines](https://developer.apple.com/library/archive/documentation/Audio/Conceptual/AudioSessionProgrammingGuide/AudioGuidelinesByAppType/AudioGuidelinesByAppType.html)). High.
- **Modes.**
  - `.measurement` minimizes system processing ([doc](https://developer.apple.com/documentation/avfaudio/avaudiosession/mode-swift.struct/measurement)).
  - `.voiceChat` processing applies only with the Voice I/O unit ([doc](https://developer.apple.com/documentation/avfaudio/avaudiosession/mode-swift.struct/voicechat)).
  - The iOS 26 AirPods option `bluetoothHighQualityRecording` needs mode `.default` and "isn't currently supported in the European Union". Apple pairs it with `setPrefersNoInterruptionsFromSystemAlerts` ([doc](https://developer.apple.com/documentation/avfaudio/avaudiosession/categoryoptions-swift.struct/bluetoothhighqualityrecording)).
- **Indicator.** The system recording indicator plus the Live Activity on the Lock Screen and in the Dynamic Island.
- **Limits.** Apple documents no limit for background audio. A Live Activity lasts "up to eight hours", and the user can switch Live Activities off ([ActivityKit](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities)).

### Interruptions
- **Notifications.** On iOS 26: `interruptionNotification` `.began`/`.ended`, where `.ended` may carry `.shouldResume` ([doc](https://developer.apple.com/documentation/avfaudio/avaudiosession/interruptionnotification), [doc](https://developer.apple.com/documentation/avfaudio/avaudiosession/interruptionoptions/shouldresume)). iOS 27 replaces these with life-cycle notifications that "don't get out of sync when the system can't deliver an end event" ([doc](https://developer.apple.com/documentation/avfaudio/handling-audio-interruptions)). Interruption reasons: `.default`, `.builtInMicMuted`, `.routeDisconnected` ([doc](https://developer.apple.com/documentation/avfaudio/avaudiosession/interruptionreason)).
- **Archived guide** (2017, medium). AVFoundation pauses recording automatically. "Your app may be suspended following an interruption. This happens when a user accepts a phone call. If a user instead ignores a call, or dismisses an alarm, the system issues an 'interruption ended' message." A begin may have no matching end ([guide](https://developer.apple.com/library/archive/documentation/Audio/Conceptual/AudioSessionProgrammingGuide/HandlingAudioInterruptions/HandlingAudioInterruptions.html)).
- **Calls.** With banner-style call alerts, `setPrefersNoInterruptionsFromSystemAlerts(true)` means the system "only interrupts the audio session if the user accepts the call"; it has "no effect" with the full-screen style ([doc](https://developer.apple.com/documentation/avfaudio/avaudiosession/setprefersnointerruptionsfromsystemalerts(_:))).
- **Background restart.**
  - `'!int'` means "make a nonmixable audio session active while the app was in the background" ([doc](https://developer.apple.com/documentation/coreaudiotypes/avaudiosession/errorcode/cannotinterruptothers)).
  - `cannotStartRecording` covers "a mixable recording from the background" ([doc](https://developer.apple.com/documentation/coreaudiotypes/avaudiosession/errorcode/cannotstartrecording)).
  - DTS, 2020, about playback: don't resume in the background; resume in the foreground ([652395](https://developer.apple.com/forums/thread/652395)).
  - Non-staff, 2026: after a call, `.ended` arrives but `setActive` fails `'!int'` ([813278](https://developer.apple.com/forums/thread/813278)).
  - Non-staff, 2019, the opposite: background restart worked "if I was already recording before the interruption" ([120038](https://developer.apple.com/forums/thread/120038?page=3)).
- **Siri.** `siriIsRecording` blocks some operations ([doc](https://developer.apple.com/documentation/coreaudiotypes/avaudiosession/errorcode/siriisrecording)). A non-staff report says `.ended` arrives only after Siri's card closes ([849429](https://developer.apple.com/forums/thread/849429)).
- **Alarms.** `.record` "doesn't prevent phone calls, alarms, or other nonmixable audio sessions from interrupting" ([doc](https://developer.apple.com/documentation/avfaudio/avaudiosession/category-swift.struct/record)).
- **Media services reset.** Don't restart "recording… until initiated by user action" ([doc](https://developer.apple.com/documentation/avfaudio/avaudiosession/mediaserviceswereresetnotification)).
- **Termination.** `applicationWillTerminate` only "may be called" for an app running in the background ([doc](https://developer.apple.com/documentation/uikit/uiapplicationdelegate/applicationwillterminate(_:))). What survives:
  - CAF permits an unfinalized data size of −1 ([spec](https://developer.apple.com/library/archive/documentation/MusicAudio/Reference/CAFSpec/CAF_spec/CAF_spec.html)).
  - `AVAssetWriter.movieFragmentInterval` keeps a "partially written movie" readable ([doc](https://developer.apple.com/documentation/avfoundation/avassetwriter/moviefragmentinterval)).
  - Whether an `AVAudioRecorder` `.m4a` survives being killed is undocumented.

## Gaps
1. **Locked, cold start (device test, top priority).** Kill the app, lock the phone, tap the Control Center control and the Lock Screen control. Log `Activity.request` and `setActive` errors. Repeat with the phone unlocked and Mispher in the background.
2. **Latency.** Time from tap to first buffer, on the background path and on `.foreground(.immediate)` with Face ID.
3. **Resume per interruption (device test).** Declined and answered call, FaceTime, Siri, alarm, timer, Voice Memos taking the mic, each foreground and locked. Log notifications, options and `setActive` results. Also test whether a Live Activity button (`LiveActivityIntent` + `AudioRecordingIntent`) can resume capture.
4. Whether a locked iPhone always shows incoming calls full screen.
5. Whether Back Tap fires while locked.
6. A 60-minute locked run, and the file's state after a force-quit.
7. AirPods high-quality recording in Switzerland.
8. Whether Mispher can capture at all during an active call.

## Implications for Mispher
- **Start path.** Choose between a background start, an app-opening start (Face ID), or a `.dynamic` hybrid. This depends on Gap 1, and the 2 s goal may need "from unlocked".
- **Control and Stop.** Choose button or toggle, and decide where Stop lives (Live Activity, control, app).
- **Live Activity.** It is required for the background path. Decide the behaviour when Live Activities are switched off.
- **Interruption policy.** Decide whether to try resuming automatically, how to prompt the user when a background resume is refused, and how the Protocol marks the gap. A new Segment per interruption is already in the glossary.
- **Incoming calls.** Decide whether to set `setPrefersNoInterruptionsFromSystemAlerts(true)`.
- **Crash safety.** Choose between one `.m4a` written live and CAF or chunked files converted at Stop. Decide how an orphaned Recording is recovered.
- **Session configuration.** Choose category, mode (`.default` vs `.measurement`) and mixability.
- **iOS 27.** It runs on the 14 Pro Max according to [secondary reports](https://9to5mac.com/2026/06/08/ios-27-here-are-all-the-compatible-iphone-models/). Plan for the new notifications.

## Sources
- https://developer.apple.com/documentation/appintents/audiorecordingintent
- https://developer.apple.com/documentation/appintents/liveactivityintent
- https://developer.apple.com/documentation/widgetkit/controlwidgetbutton
- https://developer.apple.com/documentation/widgetkit/creating-controls-to-perform-actions-across-the-system
- https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities
- https://developer.apple.com/design/human-interface-guidelines/controls
- https://developer.apple.com/documentation/appintents/appintent/authenticationpolicy
- https://developer.apple.com/documentation/appintents/appintent/supportedmodes
- https://developer.apple.com/documentation/appintents/appintent/openappwhenrun
- https://developer.apple.com/videos/play/wwdc2024/10176/
- https://developer.apple.com/videos/play/wwdc2024/10157/
- https://developer.apple.com/videos/play/wwdc2025/275/
- https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities
- https://developer.apple.com/documentation/avfaudio/avaudiosession/category-swift.struct/record
- https://developer.apple.com/documentation/avfaudio/avaudiosession/category-swift.struct/playandrecord
- https://developer.apple.com/documentation/avfaudio/avaudiosession/mode-swift.struct/measurement
- https://developer.apple.com/documentation/avfaudio/avaudiosession/mode-swift.struct/voicechat
- https://developer.apple.com/documentation/avfaudio/avaudiosession/categoryoptions-swift.struct/bluetoothhighqualityrecording
- https://developer.apple.com/documentation/avfaudio/handling-audio-interruptions
- https://developer.apple.com/documentation/avfaudio/avaudiosession/interruptionnotification
- https://developer.apple.com/documentation/avfaudio/avaudiosession/interruptionoptions/shouldresume
- https://developer.apple.com/documentation/avfaudio/avaudiosession/interruptionreason
- https://developer.apple.com/documentation/avfaudio/avaudiosession/setprefersnointerruptionsfromsystemalerts(_:)
- https://developer.apple.com/documentation/coreaudiotypes/avaudiosession/errorcode/cannotinterruptothers
- https://developer.apple.com/documentation/coreaudiotypes/avaudiosession/errorcode/cannotstartrecording
- https://developer.apple.com/documentation/coreaudiotypes/avaudiosession/errorcode/siriisrecording
- https://developer.apple.com/documentation/avfaudio/avaudiosession/mediaserviceswereresetnotification
- https://developer.apple.com/documentation/uikit/uiapplicationdelegate/applicationwillterminate(_:)
- https://developer.apple.com/documentation/avfoundation/avassetwriter/moviefragmentinterval
- https://developer.apple.com/library/archive/documentation/Audio/Conceptual/AudioSessionProgrammingGuide/HandlingAudioInterruptions/HandlingAudioInterruptions.html
- https://developer.apple.com/library/archive/documentation/Audio/Conceptual/AudioSessionProgrammingGuide/AudioGuidelinesByAppType/AudioGuidelinesByAppType.html
- https://developer.apple.com/library/archive/documentation/MusicAudio/Reference/CAFSpec/CAF_spec/CAF_spec.html
- https://developer.apple.com/forums/thread/816408 (Apple DTS)
- https://developer.apple.com/forums/thread/652395 (Apple DTS)
- https://developer.apple.com/forums/thread/836958 (secondary)
- https://developer.apple.com/forums/thread/815725 (secondary)
- https://developer.apple.com/forums/thread/813278 (secondary)
- https://developer.apple.com/forums/thread/120038?page=3 (secondary)
- https://developer.apple.com/forums/thread/849429 (secondary)
- https://github.com/anthonytw/sempere/pull/29 (secondary)
- https://support.apple.com/guide/shortcuts/apd897693606/ios (not opened directly)
- https://9to5mac.com/2026/06/08/ios-27-here-are-all-the-compatible-iphone-models/ (secondary)
