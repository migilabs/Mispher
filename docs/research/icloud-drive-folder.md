# How does an iOS app write to a user-visible iCloud Drive folder that Claude Desktop on the Mac can read?
Ticket: https://github.com/migilabs/Mispher/issues/8 · Researched 2026-10-24

> developer.apple.com, Apple's documentation archive and the xnu sources were read directly. support.apple.com and eclecticlight.co were blocked, so claims from them come from search extracts, marked "(extract)". Forum replies are marked as Apple staff or secondary. No Reddit sources were used.

## Answer

- **How it works.** Turn on the iCloud capability with **iCloud Documents** and the container `iCloud.<bundle id>`. Write into `<container>/Documents/`, using the URL from `url(forUbiquityContainerIdentifier:)`. To publish the folder, add `NSUbiquitousContainers` to Info.plist with `NSUbiquitousContainerIsDocumentScopePublic = true` and `NSUbiquitousContainerName = Mispher`. Bump `CFBundleVersion` whenever that metadata changes. The folder only appears once it holds a file. Do all file access through `NSFileCoordinator`. **Confidence: high.**
- **It needs the paid Apple Developer Program.** The free tier has no iCloud capabilities. A folder the user picks in the document picker needs no iCloud entitlement. **High for the paid requirement; medium that the picker route works without paying.**
- **On the Mac,** Finder shows the folder as "Mispher" under iCloud Drive. On disk it is at `~/Library/Mobile Documents/iCloud~<container id, dots as ~>/Documents`. That path comes from developer reports, not from Apple's docs. Non-sandboxed processes can read it by path. Claude Desktop reads it once the path is an allowed directory of its Filesystem MCP server. Whether macOS 26 shows a privacy prompt first is not documented. **Medium.**
- **Apple guarantees no sync speed.** Its docs say only "quickly" and "as soon as possible". They give no numbers and say nothing on how Low Power Mode or cellular affect iCloud Drive. **High that no guarantee exists. Actual latency is unknown and needs a device test.**
- **Conflicts.** iCloud makes the most recent version current and keeps the others as `NSFileVersion` conflict versions. Those stay in iCloud storage until the app resolves them. **High.**
- **Files not yet downloaded.** iOS downloads files from other devices only when asked: `startDownloadingUbiquitousItem(at:)` or a coordinated read. Any device can evict files to "dataless" placeholders, and reading one triggers a blocking download. On the Mac, Optimize Mac Storage can evict files. "Keep Downloaded" pins a folder. **Medium-high.**

## Findings

### 1. Writing from iOS
- **The container URL.** `url(forUbiquityContainerIdentifier:)` "extends your app's sandbox to include that container". It returns `nil` if iCloud is unavailable. Apple says: "Do not call this method from your app's main thread" ([doc](https://developer.apple.com/documentation/foundation/filemanager/url(forubiquitycontaineridentifier:))). For a quick availability check, use `ubiquityIdentityToken` ([doc](https://developer.apple.com/documentation/foundation/filemanager/ubiquityidentitytoken)).
- **Entitlements.** iCloud Documents adds three entitlements. A container can be shared "between multiple apps belonging to the same developer", including the later Mac app ([Configuring iCloud services](https://developer.apple.com/documentation/xcode/configuring-icloud-services)).
- **`Documents`** is the container's "public face". Anything outside it is private app data ([iCloud Fundamentals](https://developer.apple.com/library/archive/documentation/General/Conceptual/iCloudDesignGuide/Chapters/iCloudFundametals.html)).
- **Publishing keys.**
  - `NSUbiquitousContainerIsDocumentScopePublic` defaults to NO. `NSUbiquitousContainerName` defaults to the bundle name ([Info.plist keys](https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Articles/CocoaKeys.html)).
  - `NSUbiquitousContainerSupportedFolderLevels` (`None`/`One`/`Any`) also limits which subfolders Finder lets users create.
- **When the metadata takes effect.** It is read once and updated only "when a newer build of your app is detected". An unused container doesn't appear: "copy at least one file" ([QA1893](https://developer.apple.com/library/archive/qa/qa1893/_index.html)). Apple's current [sample code](https://developer.apple.com/documentation/uikit/synchronizing-documents-in-the-icloud-environment) and an Apple DTS engineer in October 2024 ([forum, Apple staff](https://developer.apple.com/forums/thread/765461)) both stress the bundle-version bump.
- **File coordination.** "iCloud apps are required to use file coordination" ([Designing for Documents in iCloud](https://developer.apple.com/library/archive/documentation/General/Conceptual/iCloudDesignGuide/Chapters/DesigningForDocumentsIniCloud.html)).
  - On iOS, a granted coordinated read or write starts a background task automatically. A request still waiting when the app is suspended is cancelled ([NSFileCoordinator](https://developer.apple.com/documentation/foundation/nsfilecoordinator)).
  - Remove file presenters when the app goes to the background, or other processes can deadlock ([NSFilePresenter](https://developer.apple.com/documentation/foundation/nsfilepresenter)).
- **Getting files in.** "All documents must be created on a local disk initially and moved to a user's iCloud account later", using `setUbiquitous(_:itemAt:destinationURL:)`, which blocks ([File System Programming Guide](https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/FileSystemProgrammingGuide/iCloud/iCloud.html), [doc](https://developer.apple.com/documentation/foundation/filemanager/setubiquitous(_:itemat:destinationurl:))).
- **Filenames.** Use "the alphanumeric character set as much as possible and avoid special punctuation". Never change letter case, and treat names as case-insensitive (same guides).
- **Alternative: a folder the user picks.** `UIDocumentPickerViewController(forOpeningContentTypes: [.folder])` returns a security-scoped URL with recursive access, including to files added later. The app stores it as a bookmark and wraps each access in `startAccessingSecurityScopedResource()` plus file coordination. The user can revoke access in Settings ([Providing access to directories](https://developer.apple.com/documentation/uikit/providing-access-to-directories)).

### 2. Paid program
Apple's capability table marks "iCloud: iCloud documents", CloudKit and key-value storage for ADP and ADEP only. The free "Apple Developer" column is empty ([iOS](https://developer.apple.com/help/account/reference/supported-capabilities-ios)). On macOS, iCloud is available to ADP and Developer ID ([macOS](https://developer.apple.com/help/account/reference/supported-capabilities-macos)). The document picker is not a listed capability.

### 3. On the Mac
- **No Mac app needed.** A published container is visible in Finder when the Mac uses the same Apple Account ([QA1893](https://developer.apple.com/library/archive/qa/qa1893/_index.html)).
- **The on-disk path** `~/Library/Mobile Documents/iCloud~com~…~App/Documents` is known only from developer posts ([forum, secondary](https://developer.apple.com/forums/thread/676948)).
- **Claude Desktop's Filesystem server** "may touch only its allowed directories", which are passed as arguments in `claude_desktop_config.json` ([README](https://github.com/modelcontextprotocol/servers/blob/main/src/filesystem/README.md)).
- **Privacy prompts.** A May 2026 report describes iCloud prompts (`kTCCServiceUbiquity`) on macOS Tahoe, but not for reading by path ([forum, secondary](https://developer.apple.com/forums/thread/827374)).

### 4. Latency
- **Order of transfer.** Metadata goes first and "propagates … quickly". Data follows, and later changes upload as deltas. A Mac is a "greedy peer" that downloads automatically. iOS pulls changes "at appropriate times" ([Designing for Documents](https://developer.apple.com/library/archive/documentation/General/Conceptual/iCloudDesignGuide/Chapters/DesigningForDocumentsIniCloud.html)).
- **Who uploads.** A system daemon, "as soon as possible" ([guide](https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/FileSystemProgrammingGuide/iCloud/iCloud.html)).
- **Low Power Mode.** Apple's article names only "iCloud Photos" as paused, and Background App Refresh as off ([Apple Support](https://support.apple.com/en-us/101604), extract).
- **Cellular.** A cellular switch for iCloud Drive appears only in secondary sources ([iMore, secondary](https://www.imore.com/how-enable-or-disable-icloud-drive-syncing-over-cellular)).
- **File size.** A 60-min `.m4a` at 64 kbps is about 29 MB; the `.md` is a few KB.
- **Stalls happen.** A user reported stalled iCloud Drive uploads on macOS 26.4.1. Apple only acknowledged the report ([forum](https://developer.apple.com/forums/thread/822534)).

### 5. Conflicts and not-downloaded files
- **How iCloud picks a winner.** It makes "the most recently modified file the current file". Other versions stay as conflict versions until the app uses `unresolvedConflictVersionsOfItem(at:)`, merges or picks one, and sets `isResolved = true` ([guide](https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/FileSystemProgrammingGuide/iCloud/iCloud.html), [NSFileVersion](https://developer.apple.com/documentation/foundation/nsfileversion)).
- **Avoidable conflicts.** Saving non-content state such as timestamps "invite[s] trivial and unhelpful conflict scenarios" ([Designing for Documents](https://developer.apple.com/library/archive/documentation/General/Conceptual/iCloudDesignGuide/Chapters/DesigningForDocumentsIniCloud.html)).
- **Downloads on iOS.** Nothing downloads automatically. A coordinated read "blocks until the file finishes downloading". Track progress with `ubiquitousItemDownloadingStatus` and find files with `NSMetadataQuery` (same guide; [doc](https://developer.apple.com/documentation/foundation/filemanager/startdownloadingubiquitousitem(at:))). The system may evict unused files, but their metadata stays local ([iCloud Fundamentals](https://developer.apple.com/library/archive/documentation/General/Conceptual/iCloudDesignGuide/Chapters/iCloudFundametals.html)).
- **Dataless files.** "Accessing a dataless file causes the system to materialize the file". That can hang or fail with `ETIMEDOUT`. Code can detect `SF_DATALESS`, or opt out of materialization and get `EDEADLK` instead ([TN3150](https://developer.apple.com/documentation/technotes/tn3150-getting-ready-for-data-less-files)). The kernel man page gives the *system* default as `…_FILES_OFF` ([getiopolicy_np(3)](https://github.com/apple-oss-distributions/xnu/blob/main/bsd/man/man3/getiopolicy_np.3)). What a normally launched app inherits is undocumented.
- **On the Mac.** With Optimize Mac Storage on, older files move to iCloud when space runs low. **Keep Downloaded** keeps an item local ([Apple Support](https://support.apple.com/guide/mac-help/store-files-in-icloud-drive-mchle5a61431/mac), extract). Since macOS 14, iCloud Drive runs on FileProvider and evicts files to dataless placeholders ([Eclectic Light, secondary](https://eclecticlight.co/2023/11/21/icloud-drive-in-sonoma-fileprovider-and-eviction/), extract).

## Gaps

1. **Latency (device test).** Time-stamp files on the iPhone and log their arrival on the Mac. Vary Wi-Fi/cellular, Low Power Mode, foreground/background, 3 KB/~30 MB. This also shows the undocumented Low Power Mode and cellular effects.
2. **Claude Desktop on macOS 26 (device test).**
   - Is it sandboxed? Check with `codesign -d --entitlements - /Applications/Claude.app`.
   - Does reading `~/Library/Mobile Documents/…` trigger a privacy prompt?
   - Does reading a file after "Remove Download" download it, or fail with `EDEADLK`?
3. **Optimize Mac Storage.** With it on, do new files arrive on macOS 26 fully downloaded or dataless?
4. **The picker route (unverified).** Do background writes work? How long does a bookmark last? What signing limits apply without the paid program?
5. **iOS 26 changes.** None found. The guides date from 2015 to 2018; the newest primary source is the iOS 14+ sample code.

## Implications for Mispher

These decisions are named here, not made:

- **Container or picked folder.** The container needs the Developer Program (planned for P0). A picked folder adds bookmark and revocation failures.
- **What the iPhone keeps locally.** Apple advises against mirroring the container in local storage, and iOS can evict files.
  - Does the `.m4a` live only in iCloud Drive?
  - Is it recorded locally and moved at Stop, or only after the Protocol is written?
  - Does SwiftData hold only references to the files?
- **File naming.** The draft `YYYY-MM-DD <Titel>.md` has spaces and umlauts, against Apple's advice. Use a slug or the display title?
- **Folder structure.** Pick a `NSUbiquitousContainerSupportedFolderLevels` value: a flat folder, or one level such as year folders.
- **Writers of the `.md`.** If the Notes bridge writes `notes.id` back while the iPhone can regenerate the Protocol, conflicts must be handled. Or Mac state lives outside the file.
- **Partial arrival.** The `.md` and `.m4a` sync separately and may be dataless when read. The audio reference, the P3 watcher and the MCP server must cope.
- **Mac setup.**
  - Turn off Optimize Mac Storage, or set Keep Downloaded on the folder.
  - Should the Mac app share the container or read it by path?
  - P3's "≤ 1 min after the Mac wakes" assumes a latency nobody has measured.
- **Quota.** Audio counts against Michele's iCloud storage.

## Sources

- https://developer.apple.com/documentation/foundation/filemanager/url(forubiquitycontaineridentifier:)
- https://developer.apple.com/documentation/foundation/filemanager/ubiquityidentitytoken
- https://developer.apple.com/documentation/xcode/configuring-icloud-services
- https://developer.apple.com/documentation/uikit/synchronizing-documents-in-the-icloud-environment
- https://developer.apple.com/library/archive/documentation/General/Conceptual/iCloudDesignGuide/Chapters/iCloudFundametals.html
- https://developer.apple.com/library/archive/documentation/General/Conceptual/iCloudDesignGuide/Chapters/DesigningForDocumentsIniCloud.html
- https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/FileSystemProgrammingGuide/iCloud/iCloud.html
- https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Articles/CocoaKeys.html
- https://developer.apple.com/library/archive/qa/qa1893/_index.html
- https://developer.apple.com/documentation/foundation/nsfilecoordinator
- https://developer.apple.com/documentation/foundation/nsfilepresenter
- https://developer.apple.com/documentation/foundation/filemanager/setubiquitous(_:itemat:destinationurl:)
- https://developer.apple.com/documentation/foundation/nsfileversion
- https://developer.apple.com/documentation/foundation/filemanager/startdownloadingubiquitousitem(at:)
- https://developer.apple.com/documentation/technotes/tn3150-getting-ready-for-data-less-files
- https://github.com/apple-oss-distributions/xnu/blob/main/bsd/man/man3/getiopolicy_np.3
- https://developer.apple.com/documentation/uikit/providing-access-to-directories
- https://developer.apple.com/help/account/reference/supported-capabilities-ios
- https://developer.apple.com/help/account/reference/supported-capabilities-macos
- https://developer.apple.com/forums/thread/765461 (Apple DTS)
- https://developer.apple.com/forums/thread/676948 (secondary)
- https://developer.apple.com/forums/thread/827374 (secondary)
- https://developer.apple.com/forums/thread/822534 (user report; Apple DTS acknowledged only)
- https://github.com/modelcontextprotocol/servers/blob/main/src/filesystem/README.md
- https://support.apple.com/en-us/101604 (extract)
- https://support.apple.com/guide/mac-help/store-files-in-icloud-drive-mchle5a61431/mac (extract)
- https://eclecticlight.co/2023/11/21/icloud-drive-in-sonoma-fileprovider-and-eviction/ (secondary, extract)
- https://www.imore.com/how-enable-or-disable-icloud-drive-syncing-over-cellular (secondary)
