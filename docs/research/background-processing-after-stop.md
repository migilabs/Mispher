# Can the iPhone finish upload, transcription and Protocol writing after Stop without the app in the foreground?
Ticket: https://github.com/migilabs/Mispher/issues/7 · Researched 2026-10-24

## Answer

- **Yes, when Stop happens in the foreground.** `BGContinuedProcessingTask` (iOS 26.0+, name verified) keeps work running after the user leaves the app, with network and CPU, no published time limit, and progress in a system Live Activity. It must be submitted from the foreground after a user action and can't start from the background. **High.**
- **Locking the phone is the main risk.** Apple DTS confirmed a bug where the task pauses or expires on a truly locked device. They expected a fix in 26.1, but a developer reports failures on 26.1 and 26.2 beta 3. **Medium; needs a device test.**
- **The task needs progress at least every ~30 s** (unpublished, Apple DTS). Waiting for the Transcript or Claude produces none, so the app must report time-based progress. **Medium-high.**
- **A background `URLSession` survives suspension and system kills, but can't promise 5 minutes for a chain.** File uploads with JSON responses work, and the app wakes for about 30 s afterwards. Each later request started from the background is discretionary and rate-limited. **High on the mechanics, medium on the latency.**
- **`beginBackgroundTask` (about 30 s) and `BGProcessingTask` (idle device, often overnight) can't carry the pipeline.** They only bridge the hand-off or retry later. **High.**
- **The app can update its own Live Activity whenever it runs in the background.** Push updates need an APNs server, which Mispher doesn't have. The system's Live Activity for the task may appear next to Mispher's own. **High / medium.**
- **Swiping the app away cancels everything:** the continued task (silently), queued requests and background transfers, with no background relaunch. After a system kill, transfers continue and the app is relaunched, but a running continued task is gone. Persist every step and resume. **High.**

## Findings

### BGContinuedProcessingTask
- **Availability:** iOS, iPadOS and Mac Catalyst 26.0+ ([class](https://developer.apple.com/documentation/backgroundtasks/bgcontinuedprocessingtask)). The 14 Pro Max runs iOS 26 ([Apple Support](https://support.apple.com/en-us/123705), seen via search). Only the GPU is device-gated ([gpu](https://developer.apple.com/documentation/backgroundtasks/bgcontinuedprocessingtaskrequest/resources/gpu)), and Mispher doesn't need it. **High.**
- **Start from the foreground:** the request is created "on behalf of the currently foregrounded app" ([init](https://developer.apple.com/documentation/backgroundtasks/bgcontinuedprocessingtaskrequest/init(identifier:title:subtitle:))), and submission "needs to occur as a result of a person's action" ([request](https://developer.apple.com/documentation/backgroundtasks/bgcontinuedprocessingtaskrequest)). WWDC25 says to avoid automatic workloads ([session 227](https://developer.apple.com/videos/play/wwdc2025/227/)). DTS: "you're not going to be able to start new tasks once you enter the background," so retries belong inside the one task ([forum](https://developer.apple.com/forums/thread/808756)). **High.**
- **Identifiers and registration:** use a wildcard identifier `<bundle-id>.<context>.*` with a unique suffix per task, and register the handler when the user acts ([session 227](https://developer.apple.com/videos/play/wwdc2025/227/)). Registering an identifier twice kills the app ([register](https://developer.apple.com/documentation/backgroundtasks/bgtaskscheduler/register(fortaskwithidentifier:using:launchhandler:))). **High.**
- **Submission strategy:** the default `.queue` may wait behind other tasks ([queue](https://developer.apple.com/documentation/backgroundtasks/bgcontinuedprocessingtaskrequest/submissionstrategy/queue)). `.fail` throws `immediateRunIneligible` instead ([error](https://developer.apple.com/documentation/backgroundtasks/bgtaskscheduler/error/code/immediaterunineligible)). iOS 26 can fail silently ([developer report](https://developer.apple.com/forums/thread/838434)), and iOS 27 deprecates `submit(_:)` so that apps can "capture all error conditions" ([doc](https://developer.apple.com/documentation/backgroundtasks/bgtaskscheduler/submittaskrequest(_:completionhandler:))). **High.**
- **Progress and expiry:**
  - The system terminates tasks with "minimal or no progress" first ([class](https://developer.apple.com/documentation/backgroundtasks/bgcontinuedprocessingtask)), and it asks the user whether to continue a slow task ([session 227](https://developer.apple.com/videos/play/wwdc2025/227/)).
  - DTS puts the cadence at "~30s" and recommends updates every 1–2 s ([forum](https://developer.apple.com/forums/thread/805554)). Set progress directly, because child `Progress` objects are "very likely" buggy here ([DTS](https://developer.apple.com/forums/thread/809182)).
  - Developers report expiry from high CPU or heat, after which the task shows a fixed "Task Failed" ([forum, developer report](https://developer.apple.com/forums/thread/815830)).
  - The expiration handler can't tell a user cancel from a system expiry, which DTS calls "a significant oversight" ([forum](https://developer.apple.com/forums/thread/805088)).
  - **Medium-high.**
- **UI:** a system Live Activity shows the title and subtitle, which the app can change with `updateTitle(_:subtitle:)`. The user can cancel the task there ([article](https://developer.apple.com/documentation/backgroundtasks/performing-long-running-tasks-on-ios-and-ipados)). On iPhone it appears only once the app is backgrounded ([DTS](https://developer.apple.com/forums/thread/802073)). **High.**
- **Locked device:** DTS says the task "was intended to keep the device awake" and expected FB19916760 to be fixed in 26.1. A later report describes expiry while the phone is "truly locked" on 26.1 and 26.2 beta 3 (FB21233240) ([forum](https://developer.apple.com/forums/thread/796138)). The 26.1–26.5 release notes are silent. **Medium.**
- **How DTS frames it:** a lifecycle API "much closer to `beginBackgroundTask`" than a scheduler. Start the work immediately and treat the task as a backup ([forum](https://developer.apple.com/forums/thread/808756)).

### Background URLSession
- **Transfers run in a separate process** and continue while the app is suspended or after the system terminates it ([background(withIdentifier:)](https://developer.apple.com/documentation/foundation/urlsessionconfiguration/background(withidentifier:))). **High.**
- **Uploads must come from a file**, so the multipart body is written to disk first ([Downloading files in the background](https://developer.apple.com/documentation/foundation/downloading-files-in-the-background)). After the upload, the task "behaves like a data task" and delivers the response body to the delegate ([URLSessionUploadTask](https://developer.apple.com/documentation/foundation/urlsessionuploadtask)). Data tasks don't run while the app is suspended ([Quinn](https://developer.apple.com/forums/thread/812219)). **High.**
- **Waking the app:** once a session's tasks finish, the system wakes or relaunches the app through [`handleEventsForBackgroundURLSession`](https://developer.apple.com/documentation/uikit/uiapplicationdelegate/application(_:handleeventsforbackgroundurlsession:completionhandler:)) ([`.backgroundTask(.urlSession)`](https://developer.apple.com/documentation/swiftui/backgroundtask) in SwiftUI). The wake window is "typically around 30 seconds" ([Apple staff](https://developer.apple.com/forums/thread/827707)). **High / medium.**
- **Latency:**
  - Tasks started in the background are always discretionary and may wait for Wi-Fi and power ([isDiscretionary](https://developer.apple.com/documentation/foundation/urlsessionconfiguration/isdiscretionary)).
  - A rate limiter delays new tasks more after each relaunch ([Downloading files…](https://developer.apple.com/documentation/foundation/downloading-files-in-the-background)).
  - Background sessions "prioritise device resources and bandwidth over latency" ([Quinn](https://developer.apple.com/forums/thread/812219)).
  - So a chain from upload to Transcript to Claude can run while the app is suspended, but its timing has no bound. **Medium-high.**
- **Retries:** background uploads are "automatically retried" after a timeout, and the idle timeout defaults to 60 s ([timeoutIntervalForRequest](https://developer.apple.com/documentation/foundation/urlsessionconfiguration/timeoutintervalforrequest)). Inference: a transcription that keeps the server silent for over 60 s could be sent and billed twice. **Medium.**

### Other mechanisms
- **`beginBackgroundTask`:** gives "finite" time and should be called before the app leaves the foreground ([doc](https://developer.apple.com/documentation/uikit/uiapplication/beginbackgroundtask(withname:expirationhandler:))). Quinn says "about 30 seconds" per app, not per task ([forum](https://developer.apple.com/forums/thread/85066)). **High.**
- **`BGProcessingTask`:** runs "only when the device is idle" and stops once the user picks up the device ([doc](https://developer.apple.com/documentation/backgroundtasks/bgprocessingtask)). It can run many hours later ([Quinn](https://developer.apple.com/forums/thread/14853)). For uploads like these, Quinn suggests combining a background session, a continued processing task and a processing task as the fallback ([forum](https://developer.apple.com/forums/thread/827707)). **High.**
- **`BGAppRefreshTask`** (up to 30 s, system-timed, [strategies](https://developer.apple.com/documentation/backgroundtasks/choosing-background-strategies-for-your-app)) and the **audio mode** (only "as long as its session is active", [DTS](https://developer.apple.com/forums/thread/826462)) don't fit.

### Live Activity
- **Background updates:** the app can update or end its Live Activity in the background ([Activity](https://developer.apple.com/documentation/activitykit/activity)), within 4 KB and 8 hours ([Live Activities](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities)). While the app is suspended, the Live Activity changes only during wakes. **High.**
- **Throttling and push:** local throttling isn't documented (a [forum question](https://developer.apple.com/forums/thread/822595) about it has no answer), and push updates need a server that talks to APNs ([push](https://developer.apple.com/documentation/activitykit/starting-and-updating-live-activities-with-activitykit-push-notifications)).
- **Two Live Activities:** one app saw its own Live Activity and the task's "drift apart" and dropped the task ([GitHub PR, secondary](https://github.com/harmonyvt/cobalt/pull/50)).

### Killed mid-pipeline
- **User swipe:** a running continued task is cancelled "but the app doesn't receive an indication" ([article](https://developer.apple.com/documentation/backgroundtasks/performing-long-running-tasks-on-ios-and-ipados)), and queued requests are cancelled too ([queue](https://developer.apple.com/documentation/backgroundtasks/bgcontinuedprocessingtaskrequest/submissionstrategy/queue)). Transfers are cancelled with [`UserForceQuitApplication`](https://developer.apple.com/documentation/foundation/url-session-background-task-cancellation-reasons), and there is no background relaunch until the user opens the app ([background(withIdentifier:)](https://developer.apple.com/documentation/foundation/urlsessionconfiguration/background(withidentifier:)), [Quinn](https://developer.apple.com/forums/thread/685525)). **High.**
- **System kill:** transfers continue and the app is relaunched, and it recreates the session with the same identifier. If transfers are still running at launch, no delegate call arrives, so the app has to "cache the identifier value persistently" ([handleEvents](https://developer.apple.com/documentation/uikit/uiapplicationdelegate/application(_:handleeventsforbackgroundurlsession:completionhandler:))). No relaunch is documented for a continued task the system kills. **High / medium.**
- **What to persist:** per Recording, the step state, audio path, session ID, a task key (for example in [`taskDescription`](https://developer.apple.com/documentation/foundation/urlsessiontask/taskdescription)), each response as it arrives, and the Live Activity ID, so stale activities can be ended on launch ([Live Activities](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities)).
- **Locked device:**
  - Files stay readable after the first unlock ([file protection](https://developer.apple.com/documentation/uikit/encrypting-your-app-s-files)).
  - Keychain items default to `WhenUnlocked` ([doc](https://developer.apple.com/documentation/security/ksecattraccessiblewhenunlocked)), so a default-stored API key can't be read while the phone is locked. **High.**

## Gaps
- **The locked-device bug on current 26.x.** Device test: Stop in the app, lock at once, and log progress for a 60-min Recording.
- **Submission from the background.** Can a `LiveActivityIntent`, a control or Siri submit the task while Mispher is in the background? Device test.
- **Waits.** Does time-based progress through a 1–3 min server wait avoid the stall and "continue?" prompts? Device test.
- **Device tests for the rest:** the background-session chain's delays on Wi-Fi without power (the ~30 s wake window comes only from a forum post); two Live Activities and local throttling on the 14 Pro Max; and Low Power Mode or Background App Refresh off (a `BackgroundUpdatesDisabled` cancellation reason exists; neither setting's effect on continued tasks is documented).
- **The transcription API's shape** (one request or a job to poll), its server time and chunking: tickets #4 and #13.
- **Keeping the audio session active after Stop:** the policy and technical limits weren't researched.
- **WWDC26:** no background-execution session found. iOS 27 adds only `submitTaskRequest` and an inference entitlement ([release notes](https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-27-release-notes)).

## Implications for Mispher
- **#17 (Stop → Protocol lifecycle).** Decide:
  - which mechanism carries each step: a continued task running the whole chain with a standard session, or Quinn's combination (background upload, a continued task, and `BGProcessingTask` or the next launch as the fallback)
  - whether 5 minutes is promised only for "Stop in foreground, not locked"
  - the retry policy inside one task
  - how to handle duplicate calls caused by automatic timeout retries
  - a persisted per-step state machine that resumes on launch
- **#15 (start and stop).** In-app Stop can submit the task. Decide whether Stop from the Live Activity or a control opens the app, or accepts the weaker background path.
- **#15 / #17 (Live Activity).** Decide between one indicator and two: end Mispher's own Live Activity at Stop and rely on the system's title and subtitle, or keep both. Also decide how progress is modelled during waits.
- **#13 (pipeline).** Count background-friendliness as a criterion: fewer, larger HTTP requests mean fewer hops.
- **API keys.** Decide the Keychain accessibility, for example after first unlock.

## Sources
- https://developer.apple.com/documentation/backgroundtasks/bgcontinuedprocessingtask
- https://developer.apple.com/documentation/backgroundtasks/bgcontinuedprocessingtaskrequest
- https://developer.apple.com/documentation/backgroundtasks/bgcontinuedprocessingtaskrequest/init(identifier:title:subtitle:)
- https://developer.apple.com/documentation/backgroundtasks/performing-long-running-tasks-on-ios-and-ipados
- https://developer.apple.com/documentation/backgroundtasks/bgcontinuedprocessingtaskrequest/submissionstrategy/queue
- https://developer.apple.com/documentation/backgroundtasks/bgcontinuedprocessingtaskrequest/resources/gpu
- https://developer.apple.com/documentation/backgroundtasks/bgtaskscheduler/error/code/immediaterunineligible
- https://developer.apple.com/documentation/backgroundtasks/bgtaskscheduler/register(fortaskwithidentifier:using:launchhandler:)
- https://developer.apple.com/documentation/backgroundtasks/bgtaskscheduler/submittaskrequest(_:completionhandler:)
- https://developer.apple.com/documentation/backgroundtasks/bgprocessingtask
- https://developer.apple.com/documentation/backgroundtasks/choosing-background-strategies-for-your-app
- https://developer.apple.com/videos/play/wwdc2025/227/
- https://developer.apple.com/documentation/uikit/uiapplication/beginbackgroundtask(withname:expirationhandler:)
- https://developer.apple.com/documentation/foundation/downloading-files-in-the-background
- https://developer.apple.com/documentation/foundation/urlsessionconfiguration/background(withidentifier:)
- https://developer.apple.com/documentation/foundation/urlsessionconfiguration/isdiscretionary
- https://developer.apple.com/documentation/foundation/urlsessionconfiguration/timeoutintervalforrequest
- https://developer.apple.com/documentation/foundation/urlsessionuploadtask
- https://developer.apple.com/documentation/foundation/urlsessiontask/taskdescription
- https://developer.apple.com/documentation/foundation/url-session-background-task-cancellation-reasons
- https://developer.apple.com/documentation/uikit/uiapplicationdelegate/application(_:handleeventsforbackgroundurlsession:completionhandler:)
- https://developer.apple.com/documentation/swiftui/backgroundtask
- https://developer.apple.com/documentation/activitykit/activity
- https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities
- https://developer.apple.com/documentation/activitykit/starting-and-updating-live-activities-with-activitykit-push-notifications
- https://developer.apple.com/documentation/security/ksecattraccessiblewhenunlocked
- https://developer.apple.com/documentation/uikit/encrypting-your-app-s-files
- https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-27-release-notes
- https://support.apple.com/en-us/123705 (seen via search only)
- Apple staff forum posts (Quinn, Kevin Elliott, WWDR): https://developer.apple.com/forums/thread/685525 · /85066 · /14853 · /812219 · /827707 · /808756 · /805554 · /809182 · /796138 · /805088 · /802073 · /826462
- Developer forum reports (secondary): https://developer.apple.com/forums/thread/815830 · /838434 · /822595
- Secondary: https://github.com/harmonyvt/cobalt/pull/50
