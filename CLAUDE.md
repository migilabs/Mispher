# Mispher

Personal conversation recorder for Michele's Apple devices (Apple Watch Ultra 4, iPhone 14 Pro Max, Mac). Minutes after a Recording ends, a usable Protocol with Action items is ready: findable in Apple Notes and queryable by Claude over MCP. One user, never a product.

Full concept with mockups, cost model and risk list: [Mispher: Konzept mit Mockups](https://claude.ai/artifact/5D9rtWEP95cy7RVZDy5HMi) (German). This file is the living record: when a phase settles a decision or a measurement, write it here. Domain terms are defined in `GLOSSARY.md`.

**Current phase: P0** (preparation). No app code yet. Open decisions for the iPhone MVP live on the wayfinder map [Map: iPhone MVP spec (P0–P2)](https://github.com/migilabs/Mispher/issues/3); read it before planning MVP work.

## Goals

- A Recording starts within 2 s, using only Michele's own Apple devices: the Action Button on the Watch, a Control Center or Lock Screen control on the iPhone (the 14 Pro Max has no Action Button).
- One Recording mixes Swiss German, Standard German and English.
- The Protocol is always Standard German: Summary, Decisions, Action items.
- Search finds conversations two ways: Apple Notes search and Claude via MCP.
- Liquid Glass design matching iOS, watchOS and macOS 26.
- AirPods in: record through the AirPods mic; otherwise through the recording device's mic.

Success criteria, measured over two weeks of real use after P4:

- Stop to finished Protocol on iPhone ≤ 5 min for a 60-min Recording on Wi-Fi.
- Notes search on iPhone and Mac finds a word that occurs only in the Transcript.
- API cost < 10 USD/month at 20 conversation hours, two-track Teams included.
- Watch battery drain per recording hour is measured; further Watch features wait for that number.

## Out of scope

Sales or other users; custom hardware; a Teams bot or Teams' own recording; the other party's voice on phone calls; dictation into other apps; local AI models in the MVP; privacy features (settled with the employer).

## Architecture

No server of our own. Markdown in iCloud Drive is the **source of truth**; Apple Notes and MCP are views of it.

- **Watch**: captures audio only (AirPods via `allowBluetoothHFP`, else the Watch mic) and sends it with WatchConnectivity `transferFile`. When the Audio source changes mid-Recording, start a new Segment.
- **iPhone**: runs the AI chain, stores state in SwiftData, shows a Live Activity, reads EventKit. Records directly as the fallback.
- **AI chain**: OpenAI `gpt-transcribe` (returns no timestamps and no speaker separation) → Claude Haiku 5.5 cleans the Transcript → Claude Sonnet 5.5 writes the Protocol. Calendar participants go in as Keywords.
- **iCloud Drive** `Mispher/`: one `.md` and one `.m4a` per Recording. Audio is kept so Protocols can be regenerated with better models.
- **Mac menu-bar app** (launches at login), same Swift package as iPhone: one-way Notes bridge via AppleScript, local MCP server over stdio with 5 read-only tools, Teams and phone-call capture.
- **Teams on Mac**: two tracks. Mic = `Ich` track; Teams audio via Core Audio Tap = `Andere` track. The Accessibility API reads names and the active speaker from the Teams app. Cut the `Andere` track at each speaker change (merge cuts < 3 s into a neighbour), transcribe each cut, merge by start time. Timing comes from the cut, not from the model.
- **Phone calls**: Michele's side only (mic, no system audio).

## File format

The concept's draft, with German keys. Being redone in English keys (Protocol content stays German) in [What does the Markdown file look like](https://github.com/migilabs/Mispher/issues/14).

`iCloud Drive/Mispher/YYYY-MM-DD <Titel>.md`, YAML front matter plus fixed sections:

```markdown
---
id: 2026-10-23-1030-architektur-workshop
titel: Architektur-Workshop Muster AG
datum: 2026-10-23T10:30:00+02:00
dauer_min: 58
quelle: mac-teams
vorlage: kundentermin
sprachen: [gsw, de, en]
teilnehmer: [Ich, Anna Beispiel, Reto Muster]
modelle:
  transkription: gpt-transcribe
  protokoll: claude-sonnet-5.5
notes:
  id: x-coredata://.../ICNote/p412
  geschrieben: 2026-10-23T11:31:05+02:00
---
# Architektur-Workshop Muster AG
## Zusammenfassung
## Entscheidungen
## Aufgaben
- [ ] Ich: Offerte für den Pilot (bis 2026-10-30)
## Transkript
**Ich** (00:00): Grüezi zusammen. ...
```

`gsw` is the ISO code for Swiss German. `notes.id` lets the Notes bridge update its own note and leave hand-edited notes alone.

## Rules

- **Tests first**: AI-chain tests run against golden files, and every Claude response is validated against a JSON schema.
- Build and test from the terminal with `xcodebuild`. Hardware behaviour (battery, Core Audio Taps, Action Button, AirPods routing) is verified by hand on device; say so in the PR.
- API keys live in the Keychain on iPhone and Mac. Test Recordings live outside the repo.
- Each phase: plan first and get the plan reviewed, then small steps, one commit each.
- Liquid Glass: standard SwiftUI components first. Custom glass (`.glassEffect()`, `GlassEffectContainer`) only on the record button, floating bars and the Live Activity.
- Language: code, docs, issues and the app UI are English. Protocol and Transcript content stays German.
- UI copy: short, plain words instead of error codes. Example: "AirPods disconnected, recording continues on the Watch."
- MCP tools stay read-only, and the client confirms each call: Transcripts carry third parties' words (prompt injection).

## Stack and layout

Swift 6, SwiftUI, Xcode 26; SwiftData; WatchConnectivity; AVAudioSession; Core Audio Taps (macOS 14.2+); Accessibility API; AppleScript; EventKit; ActivityKit; App Intents; WidgetKit; MCP Swift SDK; URLSession.

Planned layout (P0 creates it):

```
MispherKit/       Swift package for iOS, watchOS, macOS
  Core/           models, status, Templates
  AI/             OpenAI and Anthropic clients, the chain
  Storage/        Markdown with YAML, iCloud Drive
  Tests/          golden files
Apps/
  iOS/  watchOS/
  macOS/          NotesBridge/, Capture/, MCPServer/
Scripts/          Phase-1 tests without an app; repo tooling
```

Build and test commands: add them here once P0 has created the Xcode project.

## Phases

Each phase ends on its definition of done (DoD).

- **P0 Preparation**: Developer Program, API accounts with spending limits, this repo. DoD: empty apps run on Watch, iPhone and Mac.
- **P1 Tests without an app**: AI chain on 3 real Recordings (Swiss German, mixed, English); Notes bridge by script; mini Watch app recording via AirPods, also during a phone call. DoD: provider decision recorded here; test note found via search; Audio source comparison Watch / Watch+AirPods / iPhone+AirPods noted.
- **P2 iPhone MVP**: record, chain, list, search, Live Activity, Markdown in iCloud Drive. DoD: 60-min Recording yields a Protocol in ≤ 5 min; Claude Desktop reads the file; chain tests green.
- **P3 Mac Notes bridge**: watch folder, HTML, AppleScript. DoD: note appears ≤ 1 min after the Mac wakes; a hand-edited note is never overwritten (test).
- **P4 Watch app**: Action Button, double tap, Segments, sync. DoD: 60 min transferred; AirPods used automatically and removing them starts a new Segment; battery per hour measured.
- **P5 Teams and calls on Mac**: two tracks, names, start prompt, `Ich`-only mode. DoD: 30-min call with names in the Protocol.
- **P6 Daily use and MCP**: Templates, Markers, Keywords, Reminders, Calendar, 5 tools. DoD: MCP Inspector shows 5 tools; Claude lists the week's open Action items correctly.
- **P7 Extensions**: meeting detection, IMAP fallback, remote MCP, masking. DoD: one test per feature.

## Agent skills

Matt Pocock's skills are vendored in `.claude/skills/`. Before updating or editing one, read `docs/agents/skills.md`.

### Issue tracker

GitHub Issues in `migilabs/Mispher`. See `docs/agents/issue-tracker.md`.

### Triage labels

Default vocabulary: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `GLOSSARY.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.
