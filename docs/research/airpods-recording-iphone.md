# How do AirPods record on an iPhone 14 Pro Max under iOS 26?
Ticket: https://github.com/migilabs/Mispher/issues/6 · Researched 2026-10-24

> How this was read: developer.apple.com pages were read directly. This environment's proxy blocked www.apple.com and support.apple.com, so claims from those sites come from search-engine extracts, marked "(extract)".

## Answer

- **There are two quality tiers.** With the iOS 26 opt-in `AVAudioSession.CategoryOptions.bluetoothHighQualityRecording` and supported AirPods, the app gets "full-bandwidth", "high sample rate" audio. Otherwise the AirPods mic runs over Bluetooth HFP at about 16 kHz mono. Apple publishes no rate for the high-quality mode; one secondary report measured 48 kHz. **Confidence: high on the API, medium on the rates.**
- **The AirPods model limits the high-quality mode, not the iPhone.** Apple names only H2 AirPods: AirPods 4 (with or without ANC), AirPods Pro 2 and 3, AirPods 5 and AirPods Max 2. It requires iOS 26 and lists no iPhone models, so the 14 Pro Max is probably included. **Medium.**
- **Switzerland is unknown.** Apple's API doc says the mode "isn't currently supported in the European Union". The AirPods guide says using AirPods as a camera mic is unavailable "including the EU". Neither source mentions Switzerland or the EEA. Switzerland is not in the EU, so the feature is probably available there, but only a device test can show it. **Low.**
- **For speech recognition, 16 kHz HFP is probably enough bandwidth.** Whisper resamples all input to 16 kHz, so HFP cuts no frequencies that Whisper-family models use. Any difference in quality comes from compression, on-device voice processing and how far each speaker is from the mic. **Medium.**
- **iOS records from the built-in mic unless the app opts in.** Without `.allowBluetoothHFP` (or the high-quality option), the AirPods mic isn't offered as an input at all. With it, iOS picks the most recently connected device ("last in wins"), so it usually picks the AirPods. `setPreferredInput(_:)` pins the choice, and the new `AVInputPickerInteraction` lets the user choose. **High.**
- **iOS reports every route change; whether recording stops depends on the API.** `AVAudioSession.routeChangeNotification` arrives with reason `.oldDeviceUnavailable` or `.newDeviceAvailable`. `AVAudioEngine` stops itself when the input's sample rate or channel count changes, as it does going from HFP at 16 kHz to the built-in mic. Apple doesn't document what `AVAudioRecorder` does. **High for the engine, low for the recorder.**
- **Which reason each AirPods event produces is undocumented.** The events in question are taking them out, closing the case, and auto-switching to the Mac. This needs a device test. **Low.**

## Findings

### 1. High-quality ("studio-quality") AirPods recording
- **API.** The option is `bluetoothHighQualityRecording` on iOS/iPadOS/Mac Catalyst 26.0 and later. It "enables full-bandwidth audio when the Bluetooth route supports it, such as on certain AirPods models". It works only in the `default` session mode. It can be combined with `allowBluetoothHFP`, which then serves as the fallback. The doc carries an "Important" box saying it "isn't currently supported in the European Union". It also says the mode "may increase input latency" and recommends `setPrefersNoInterruptionsFromSystemAlerts(_:)` while recording ([doc](https://developer.apple.com/documentation/avfaudio/avaudiosession/categoryoptions-swift.struct/bluetoothhighqualityrecording)).
- **Checking support at runtime.** Read `currentRoute.inputs.first?.bluetoothMicrophoneExtension?.highQualityRecording` and its `isSupported` / `isEnabled` properties ([extension](https://developer.apple.com/documentation/avfaudio/avaudiosessionportdescription/bluetoothmicrophoneextension), [capability](https://developer.apple.com/documentation/avfaudio/avaudiosessioncapability)). There is no separate port type for this mode ([Port](https://developer.apple.com/documentation/avfaudio/avaudiosession/port)).
- **What WWDC25 says.** It is a "high quality, high sample rate" option with a media tuning "like … a LAV microphone" over "a more reliable bluetooth link". Adding it to `allowBluetoothHFP` makes it the default ([WWDC25 session 251](https://developer.apple.com/videos/play/wwdc2025/251/)). `AVCaptureSession` has an equivalent property ([doc](https://developer.apple.com/documentation/avfoundation/avcapturesession/configuresapplicationaudiosessionforbluetoothhighqualityrecording)).
- **Supported models.** Firmware 8A356 brings it to AirPods 4 (with or without ANC), AirPods Pro 2 and AirPods Pro 3 "when used with an iOS 26 … supported iPhone" ([AirPods firmware](https://support.apple.com/en-us/106340), extract). The camera-mic guide adds AirPods 5 and AirPods Max 2 and says the feature is unavailable "in all countries or regions, including the EU" ([AirPods guide](https://support.apple.com/guide/airpods/use-airpods-with-camera-apps-dev8e2a2ba2e/web), extract). The 14 Pro Max is on Apple's iOS 26 list ([compatible iPhones](https://support.apple.com/guide/iphone/iphe3fa5df43/ios), extract). The newsroom posts add only "may not be available in all regions" ([2025](https://www.apple.com/newsroom/2025/06/airpods-now-more-versatile-with-studio-quality-audio-recording-and-camera-remote/), [AirPods Max 2](https://www.apple.com/newsroom/2026/03/apple-introduces-airpods-max-2-powered-by-h2/), extracts).
- **Switzerland.** No Apple source found mentions Switzerland or the EEA for this feature. For a different feature, Live Translation, Apple restricted users based on both their location and their Apple Account region ([AirPods firmware](https://support.apple.com/en-us/106340), extract). Which test applies to this feature is unknown.
- **Measured behavior (secondary).** In a LiveKit issue, an iPhone 17 Pro Max on iOS 26.6.1 with AirPods Pro reported a session sample rate of 48000 with the option on and 16000 on plain HFP. The port type stayed `BluetoothHFP` in both cases ([GitHub issue, secondary](https://github.com/livekit/client-sdk-react-native/issues/467)).

### 2. The HFP fallback
- Apple's accessory spec says devices on iOS 5 and later support Wide Band Speech (HFP 1.6) and use it whenever the accessory does. It defines wide band as 16 kHz and narrow band as 8 kHz, the latter "supported but not recommended" ([Accessory Design Guidelines R31](https://developer.apple.com/accessories/Accessory-Design-Guidelines.pdf), §57.11.3.7 and §47.5.1). A 16 kHz sample rate carries audio up to 8 kHz at most (Nyquist), and 8 kHz carries up to 4 kHz. The LiveKit report above saw 16 kHz mono with AirPods (secondary).
- Apple names an AAC-ELD codec for AirPods FaceTime calls ([AirPods 3 newsroom](https://www.apple.com/newsroom/2021/10/introducing-the-next-generation-of-airpods/), extract), but nothing says recording apps get it. Choosing an HFP input also moves the output to HFP ([allowBluetooth doc](https://developer.apple.com/documentation/avfaudio/avaudiosession/categoryoptions-swift.struct/allowbluetooth)).
- **For speech recognition.** Whisper's code fixes `SAMPLE_RATE = 16000` ([openai/whisper](https://github.com/openai/whisper/blob/main/whisper/audio.py)). Apple's Siri guidance for accessories asks for at least 20 dB SNR. It warns that single-channel noise reduction and AGC "will be detrimental to the speech recognition accuracy" (ADG §47.5). Apple doesn't document which processing the AirPods apply on the HFP path.

### 3. Choosing the AirPods mic over the built-in mic
- `allowBluetoothHFP` (renamed from `allowBluetooth`) "makes Bluetooth Hands-Free Profile (HFP) devices available for audio input". It works only with `.record` and `.playAndRecord` ([doc](https://developer.apple.com/documentation/avfaudio/avaudiosession/categoryoptions-swift.struct/allowbluetoothhfp)). Without it, paired HFP devices "don't show up as available audio input routes" ([allowBluetooth](https://developer.apple.com/documentation/avfaudio/avaudiosession/categoryoptions-swift.struct/allowbluetooth)).
- With the option set, the route follows "last in wins", meaning the most recently connected device is used ([Audio Session Programming Guide, archived 2017](https://developer.apple.com/library/archive/documentation/Audio/Conceptual/AudioSessionProgrammingGuide/AudioSessionBasics/AudioSessionBasics.html)).
- `setPreferredInput(_:)` takes a port from `availableInputs`. Call it only after setting the category and mode and activating the session, then confirm it via `currentRoute` ([doc](https://developer.apple.com/documentation/avfaudio/avaudiosession/setpreferredinput(_:))). `preferredInput` becomes `nil` when that port disappears, so the app has to set it again when the AirPods return ([doc](https://developer.apple.com/documentation/avfaudio/avaudiosession/preferredinput)).
- `AVInputPickerInteraction` (iOS 26) shows the system microphone picker ([doc](https://developer.apple.com/documentation/avkit/avinputpickerinteraction)). The system remembers the user's choice per app ([WWDC25](https://developer.apple.com/videos/play/wwdc2025/251/)).

### 4. Route changes mid-Recording
- `routeChangeNotification` arrives on a secondary thread. It carries the reason and the previous route ([doc](https://developer.apple.com/documentation/avfaudio/avaudiosession/routechangenotification)). Apple's article says removing a device gives `.oldDeviceUnavailable` and connecting one gives `.newDeviceAvailable` ([article](https://developer.apple.com/documentation/avfaudio/responding-to-audio-route-changes)). Other possible reasons include `.routeConfigurationChange` and `.noSuitableRouteForCategory` ([enum](https://developer.apple.com/documentation/avfaudio/avaudiosession/routechangereason)).
- **Taking them out.** With Automatic Ear Detection on, removing both AirPods moves audio to the iPhone. With the microphone set to "Always Left/Right", that AirPod's mic stays in use even when it is out of the ear or in the case ([AirPods settings](https://support.apple.com/en-us/108764), extract).
- **Auto-switching.** Apple says sound shouldn't switch automatically during "a phone call, a FaceTime call or a video conference". Setting "When Last Connected to This iPhone" turns auto-switching off ([Switch AirPods](https://support.apple.com/en-us/104988), extract). Whether a recording app counts as a conversation isn't documented.
- **AVAudioEngine.** When the input hardware's sample rate or channel count changes, "the audio engine stops, uninitializes itself" and posts `AVAudioEngineConfigurationChangeNotification`; the app must restart it ([doc](https://developer.apple.com/documentation/avfaudio/avaudioengineconfigurationchangenotification)). A switch at an unchanged rate (48 kHz high-quality AirPods to a 48 kHz built-in mic) might not stop it (inference).
- **AVAudioRecorder.** It records "from the system's active input device". Nothing in its docs covers a route change mid-file ([doc](https://developer.apple.com/documentation/avfaudio/avaudiorecorder)).

## Gaps
1. **The apple.com and support.apple.com extracts are unconfirmed.** Open the pages and check the EU sentence and the model lists.
2. **High-quality mode's sample rate, channels and codec are unknown.** Device test: log `sampleRate`, `inputNumberOfChannels`, the port type and `highQualityRecording.isSupported/isEnabled`.
3. **Swiss availability is unknown.** Device test in Zurich: check `isSupported` with the option set.
4. **Which AirPods Michele owns is unknown.** First-generation AirPods Pro or AirPods 3 would mean HFP only.
5. **The reason code per AirPods event is unknown.** Device test with a logging build: one out, both out, case closed, auto-switch to the Mac, mic set to "Always Left".
6. **AVAudioRecorder across a route change is unknown.** Does it keep writing, write silence or stop? Device test.
7. **How well AirPods pick up other people in a meeting is unknown**, compared with the iPhone mic on the table. This is ticket #10.

## Implications for Mispher
- **#16 (which Audio source, and what happens when it changes).** Open decisions:
  - Opt into `bluetoothHighQualityRecording` with HFP as fallback? It requires the `default` mode.
  - Should returning AirPods take the Recording back? "Last in wins" does this unless the app pins the input.
  - Which signal starts a new Segment: the route change, the engine's configuration change, or both?
  - Should each Segment store its Audio source, sample rate and high-quality flag?
  - Which recording API? `AVAudioEngine` stops on a format change, a natural Segment boundary. `AVAudioRecorder` waits on gap 6.
- **#10 (Audio source comparison).** Compare the iPhone mic, AirPods over HFP and AirPods in high-quality mode in a real meeting, and run the Swiss `isSupported` check.
- **#4, #12, #13 (transcription pipeline).** Segments may differ in sample rate (16 or 48 kHz). Decide whether to resample before upload.
- **#5 (background and interruptions).** Decide on `setPrefersNoInterruptionsFromSystemAlerts`, and whether Michele should set "When Last Connected to This iPhone".

## Sources
- https://developer.apple.com/documentation/avfaudio/avaudiosession/categoryoptions-swift.struct/bluetoothhighqualityrecording
- https://developer.apple.com/documentation/avfaudio/avaudiosessionportdescription/bluetoothmicrophoneextension
- https://developer.apple.com/documentation/avfaudio/avaudiosessioncapability
- https://developer.apple.com/documentation/avfaudio/avaudiosession/port
- https://developer.apple.com/documentation/avfoundation/avcapturesession/configuresapplicationaudiosessionforbluetoothhighqualityrecording
- https://developer.apple.com/documentation/avfaudio/avaudiosession/categoryoptions-swift.struct/allowbluetoothhfp
- https://developer.apple.com/documentation/avfaudio/avaudiosession/categoryoptions-swift.struct/allowbluetooth
- https://developer.apple.com/documentation/avfaudio/avaudiosession/setpreferredinput(_:)
- https://developer.apple.com/documentation/avfaudio/avaudiosession/preferredinput
- https://developer.apple.com/documentation/avkit/avinputpickerinteraction
- https://developer.apple.com/documentation/avfaudio/avaudiosession/routechangenotification
- https://developer.apple.com/documentation/avfaudio/avaudiosession/routechangereason
- https://developer.apple.com/documentation/avfaudio/responding-to-audio-route-changes
- https://developer.apple.com/documentation/avfaudio/avaudioengineconfigurationchangenotification
- https://developer.apple.com/documentation/avfaudio/avaudiorecorder
- https://developer.apple.com/documentation/avfaudio/avaudiosession/setprefersnointerruptionsfromsystemalerts(_:)
- https://developer.apple.com/videos/play/wwdc2025/251/
- https://developer.apple.com/accessories/Accessory-Design-Guidelines.pdf
- https://developer.apple.com/library/archive/documentation/Audio/Conceptual/AudioSessionProgrammingGuide/AudioSessionBasics/AudioSessionBasics.html
- https://support.apple.com/en-us/106340 (extract)
- https://support.apple.com/guide/airpods/use-airpods-with-camera-apps-dev8e2a2ba2e/web (extract)
- https://support.apple.com/guide/iphone/iphe3fa5df43/ios (extract)
- https://support.apple.com/en-us/108764 (extract)
- https://support.apple.com/en-us/104988 (extract)
- https://www.apple.com/newsroom/2025/06/airpods-now-more-versatile-with-studio-quality-audio-recording-and-camera-remote/ (extract)
- https://www.apple.com/newsroom/2026/03/apple-introduces-airpods-max-2-powered-by-h2/ (extract)
- https://www.apple.com/newsroom/2021/10/introducing-the-next-generation-of-airpods/ (extract)
- https://github.com/openai/whisper/blob/main/whisper/audio.py
- https://github.com/livekit/client-sdk-react-native/issues/467 (secondary)
