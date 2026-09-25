# Music Hub

A local-first music workspace for iOS and Android, with iPhone as the lead test device. Version 0.7.2 centers the app on Songs: a musician’s notepad with local recording, tuner and metronome tools.

## Song sheets

Write or paste the whole sheet into one editor. Spaces, blank lines, section labels and ordinary chord names are kept exactly as typed. Long lines scroll horizontally so manually aligned chords stay aligned. Normal text selection, copy/paste and undo/redo work without line cards or chord-entry dialogs.

```text
[Intro]
C       Em      Am
Your lyrics go here

[Chorus]
{F}       {C}       {G}
More lyrics here
```

Optional `{Am}` notation gets a simple highlight while editing and a rounded label in performance mode. It remains literal text in storage. `[Intro]` is just text. This is not a ChordPro parser; the earlier limited ChordPro export button has been removed in favor of ordinary text copy/paste.

Songs autosave locally and have an explicit Save action. Performance mode offers larger type, font sizing, screen-awake and automatic/manual scrolling. Older line-based songs are converted on read with lyrics/chords retained. Saved-version history has been removed: the database upgrade deletes historical copies while retaining current songs and normal autosave.

## Tabs

Open a song and tap **Tab**, or start with **+ New → Tab**. Six continuous strings wrap into 40-position visual blocks fitted to the phone. Typing overwrites dashes and automatically continues on the same string below. Only the first block has opening bars; only the final block has closing bars. Scrolling is vertical only.

Backspace restores dashes and moves left; space over an empty position advances. Backspacing in a fully empty final block collapses it, but content on any string protects the block. The first block is never removed. **+ Tab Block** remains available. Long plain text and simple complete six-row ASCII paste wrap without musical interpretation.

Tabs retain local autosave and Song ownership. Existing blocks join into continuations without losing text; older annotations remain under Saved annotations. [The roadmap](docs/roadmap.md) records later **Export** (individual readable content) versus **Backup** (one restorable complete-library ZIP under More, using iOS Files). Neither Stage 8 feature is implemented yet.

## Songs and creation

**Songs** is home. Compact cards sort by actual edits, not visits. Each Song can have chords/lyrics, an ASCII tab, one notes document and multiple recordings, in any combination. A single populated component opens directly; otherwise the Song workspace offers its documents and recordings. Use the folder button to reach the workspace from a direct editor.

**+ New** starts Chords/Lyrics, Tab or Notes. An untouched editor or blank tab template saves nothing. Meaningful text or title edits create the Song locally. Existing standalone notes become Songs on upgrade; multiple attached notes combine into the Song’s single notes document with their text retained.

Navigation is **Songs | Recordings | Tuner | More**. More contains Metronome and Settings, including a persistent Dark Mode switch.

## Metronome and BPM listening

Open **More → Metronome** for 40–240 BPM, tap tempo, time signature and per-beat accents/muting. Settings persist. BPM counts the displayed note unit; changes restart the bar. Audio uses sample-positioned native playback and stops on background/exit/interruption.

**Listen for BPM** pauses the clicks and listens for 12 seconds. On-device analysis offers an estimated pulse, including half/double alternatives; **Use … BPM** explicitly applies your choice. Silence/weak rhythm may give no result, and complex music may be ambiguous. No microphone audio is saved or uploaded. Actual music and microphone behavior still need iPhone acceptance.

## Recordings

- Open **Recordings → Record** to start an independent take; microphone permission is requested when needed.
- Live input level, elapsed time, pause/resume, stop, name and save locally.
- Playback has play/pause, seek and back ten seconds.
- One timeline includes the playhead and two thin edge handles. Drag a handle inward to repeat that region automatically. Return both handles to the ends for normal playback. Original audio stays untouched.
- From a Song’s Recordings screen, record a new take or tap **+** to add an unattached recording. A Song can contain multiple recordings. The player also offers attachment changes.
- Interrupted saves remain visible as recoverable drafts. Published audio is immutable and addressed by its SHA-256 hash. Attachments are separate ordered rows.

Capture uses mono AAC in an M4A container, requesting 44.1 kHz and 128 kbps through the native recorder. The operating system may negotiate the actual input format. Audio interruptions pause recording for manual resume. Backgrounding stops/finalizes the current take and keeps it as a draft; background capture is intentionally not enabled. A force-killed or otherwise incomplete encoded file may not be playable; recovery never silently deletes it.

There is no backend or account requirement. Data stays in this app installation. Device sync and full-fidelity backup/export are not yet implemented. Wait for **Saved on this device** before force-quitting the editor; an OS kill during the 800 ms autosave delay can lose the latest unsaved keystrokes.

## Delete and tune

Swipe left on a saved song or recording to reveal its trash button, or use Delete Song / Delete Recording at the bottom of its detail screen. Both ask for confirmation. Deleting a song keeps its recordings as unattached ideas. Deletion uses ordered tombstones; immutable audio blobs are retained, including those shared by other recordings. There is no restore UI or audio garbage collector yet.

Tap **Tuner** in primary navigation. It listens locally, shows a string target and cents, and supports automatic or manual string selection. Settings offer Standard, Drop D and custom six-string tuning saved locally. Expand Audio details for frequency, periodicity confidence, input level and a live FFT spectrum. Reference pitch is A4 = 440 Hz. No tuner audio is saved or uploaded. The tuner pauses on background/interruption; restart explicitly.

Stage 7 workflow acceptance is pending; see [roadmap](docs/roadmap.md) for current stage and next work. Pitch tests use synthetic tones; real guitars, rooms and microphone routes still need validation. The DSP uses the existing [record PCM stream API](https://pub.dev/packages/record), with analysis in a Dart isolate.

## Update the running iPhone app

The tuner uses the native microphone plugin installed in Stage 2. **Stop the previous run and do a full rebuild; hot reload alone is insufficient.** Your existing signing settings have been preserved.

From this repository in your normal development terminal:

```sh
flutter pub get
flutter run -d <your-iphone-device-id>
```

Use `flutter devices` to obtain the device ID. Do not uninstall the app to update it: install the new build over the existing app to retain the local library. Xcode 27 and Flutter are already installed on the lead development Mac. For another machine, follow [Flutter's iOS setup guide](https://docs.flutter.dev/platform-integration/ios/setup).

Earlier stages have been tested by the user on iPhone. This Song-first revision needs the current [phone acceptance session](docs/iphone-checklist.md) before Stage 8 planning resumes.

## Checks

```sh
flutter analyze
# Model and real SQLite/file persistence:
dart test test/document_test.dart test/store_test.dart test/audio_files_test.dart test/dsp_test.dart test/pitch_tracker_test.dart test/tab_document_test.dart
# Phone-sized editing flow and mocked microphone lifecycle:
flutter test test/widget_test.dart test/tab_screen_test.dart
```

See [verification](docs/verification.md) for results and their limits. The installed SDK is Flutter 3.47.5 / Dart 3.13.4. Keep `pubspec.lock` under version control.

## Code map

- `lib/document.dart`: exact plain-text document format and legacy conversion.
- `lib/sheet_view.dart`: plain-text editing, optional chord styling and performance rendering.
- `lib/store.dart`: SQLite migrations, revisions, deletion tombstones and recording relationships.
- `lib/audio_files.dart`: durable drafts, verified content-addressed files and retry-safe publishing.
- `lib/audio_screen.dart`: recording, recovery, playback and attachments.
- `lib/main.dart`: library, song editor and performance navigation.
- `lib/tab_document.dart` and `lib/tab_screen.dart`: stable ordered positions, exact text cells, keyboard navigation and autosave.
- `docs/screenshots/`: rendered widget previews, not physical-device captures.

## GitHub

This folder is an independent Git repository on `main`. Create an empty GitHub repository and use your own remote URL:

```sh
git remote add origin https://github.com/YOUR_ACCOUNT/music-hub.git
git push -u origin main
```

No remote repository is created or published automatically. See [the roadmap](docs/roadmap.md) and [stack decision](docs/stack-decision.md) for scope and architecture.
