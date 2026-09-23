# Music Hub

A local-first music workspace for iOS and Android, with iPhone as the lead test device. Version 0.6 finalizes plain-text ASCII tabs and adds the Stage 6 metronome.

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

Open a song and tap **Tab**. Edit one monospaced ASCII document with the normal keyboard. New tabs start with a blank six-string block. Spaces, punctuation, annotations and arbitrary text stay as typed; long lines scroll horizontally without wrapping. **+ Tab Block** appends another blank block.

Tabs autosave locally under the song’s hidden arrangement, independently of chords/lyrics. Older grids migrate on opening: ordinary cells become aligned ASCII rows; multiline/tab-containing cells are retained verbatim below the block with labeled references. No history storage is added. See [the roadmap](docs/roadmap.md).

## Metronome

Tap **Metronome** in primary navigation. Set 40–240 BPM, tap tempo, choose a time signature, and tap individual beats to cycle normal/accented/silent. Start and Stop control local audio; settings persist. BPM counts the displayed note unit. Changing settings during playback restarts the bar.

Clicks are generated at precise sample positions in a native looping audio track, without network or microphone access. Leaving, backgrounding or audio interruption stops playback; restart manually. Native timing, loop transitions and route changes still require iPhone acceptance.

## Recordings

- Tap **Record** from the main screen to start a take; microphone permission is requested only there.
- Live input level, elapsed time, pause/resume, stop and name the take.
- Save locally, then listen with play/pause, seek, replay ten seconds and whole-recording repeat.
- Keep an unattached idea, or attach it to a song from the player. Songs have their own Recordings screen.
- Interrupted saves remain visible as recoverable drafts. Published audio is immutable and addressed by its SHA-256 hash. Attachments are separate ordered rows.

Capture uses mono AAC in an M4A container, requesting 44.1 kHz and 128 kbps through the native recorder. The operating system may negotiate the actual input format. Audio interruptions pause recording for manual resume. Backgrounding stops/finalizes the current take and keeps it as a draft; background capture is intentionally not enabled. A force-killed or otherwise incomplete encoded file may not be playable; recovery never silently deletes it.

There is no backend or account requirement. Data stays in this app installation. Device sync and full-fidelity backup/export are not yet implemented. Wait for **Saved on this device** before force-quitting the editor; an OS kill during the 800 ms autosave delay can lose the latest unsaved keystrokes.

## Delete and tune

Swipe left on a saved song or recording to reveal its trash button, or use Delete Song / Delete Recording at the bottom of its detail screen. Both ask for confirmation. Deleting a song keeps its recordings as unattached ideas. Deletion uses ordered tombstones; immutable audio blobs are retained, including those shared by other recordings. There is no restore UI or audio garbage collector yet.

Tap **Tuner** in primary navigation. It listens locally, shows a string target and cents, and supports automatic or manual string selection. Settings offer Standard, Drop D and custom six-string tuning saved locally. Expand Audio details for frequency, periodicity confidence, input level and a live FFT spectrum. Reference pitch is A4 = 440 Hz. No tuner audio is saved or uploaded. The tuner pauses on background/interruption; restart explicitly.

Stage 3 phone acceptance is pending; see [roadmap](docs/roadmap.md) for current stage and next work. Pitch tests use synthetic tones; real guitars, rooms and microphone routes still need validation. The DSP uses the existing [record PCM stream API](https://pub.dev/packages/record), with analysis in a Dart isolate.

## Update the running iPhone app

The tuner uses the native microphone plugin installed in Stage 2. **Stop the previous run and do a full rebuild; hot reload alone is insufficient.** Your existing signing settings have been preserved.

From this repository in your normal development terminal:

```sh
flutter pub get
flutter run -d <your-iphone-device-id>
```

Use `flutter devices` to obtain the device ID. Do not uninstall the app to update it: install the new build over the existing app to retain the local library. Xcode 27 and Flutter are already installed on the lead development Mac. For another machine, follow [Flutter's iOS setup guide](https://docs.flutter.dev/platform-integration/ios/setup).

Stage 2 has been tested successfully by the user on iPhone. Stage 3 is checked in automated tests here and still requires the new tuner portion of the [phone acceptance session](docs/iphone-checklist.md).

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
