# Music Hub

A local-first music workspace for iOS and Android, with iPhone as the lead test device. Version 0.2 adds a plain-text song editor and the first record → save → listen workflow.

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

Songs autosave locally and have an explicit Save action. Performance mode offers larger type, font sizing, screen-awake and automatic/manual scrolling. Saved versions can be recovered into separate songs. Older line-based songs are converted on read with all lyrics/chords retained; their historical payloads remain untouched.

## Recordings

- Tap **Record** from the main screen to start a take; microphone permission is requested only there.
- Live input level, elapsed time, pause/resume, stop and name the take.
- Save locally, then listen with play/pause, seek, replay ten seconds and whole-recording repeat.
- Keep an unattached idea, or attach it to a song from the player. Songs have their own Recordings screen.
- Interrupted saves remain visible as recoverable drafts. Published audio is immutable and addressed by its SHA-256 hash. Attachments are separate ordered rows.

Capture uses mono AAC in an M4A container, requesting 44.1 kHz and 128 kbps through the native recorder. The operating system may negotiate the actual input format. Audio interruptions pause recording for manual resume. Backgrounding stops/finalizes the current take and keeps it as a draft; background capture is intentionally not enabled. A force-killed or otherwise incomplete encoded file may not be playable; recovery never silently deletes it.

There is no backend or account requirement. Data stays in this app installation. Device sync and full-fidelity backup/export are not yet implemented. Wait for **Saved on this device** before force-quitting the editor; an OS kill during the 800 ms autosave delay can lose the latest unsaved keystrokes.

## Update the running iPhone app

This release adds native plugins and microphone permission configuration. **Stop the previous run and do a full rebuild; hot reload alone is insufficient.** Your existing signing settings have been preserved.

From this repository in your normal development terminal:

```sh
flutter pub get
flutter run -d <your-iphone-device-id>
```

Use `flutter devices` to obtain the device ID. Do not uninstall the app to update it: install the new build over the existing app to retain the local library. Xcode 27 and Flutter are already installed on the lead development Mac. For another machine, follow [Flutter's iOS setup guide](https://docs.flutter.dev/platform-integration/ios/setup).

The automated UI and persistence checks run here, but a native iOS rebuild was blocked by the tool environment's nested sandbox restriction during Swift package resolution. Actual capture, route changes and interruptions still require the [phone acceptance session](docs/iphone-checklist.md).

## Checks

```sh
flutter analyze
# Model and real SQLite/file persistence:
dart test test/document_test.dart test/store_test.dart test/audio_files_test.dart
# Phone-sized editing flow and mocked microphone lifecycle:
flutter test test/widget_test.dart
```

See [verification](docs/verification.md) for results and their limits. The installed SDK is Flutter 3.47.5 / Dart 3.13.4. Keep `pubspec.lock` under version control.

## Code map

- `lib/document.dart`: exact plain-text document format and legacy conversion.
- `lib/sheet_view.dart`: plain-text editing, optional chord styling and performance rendering.
- `lib/store.dart`: SQLite migrations, revisions, history and recording relationships.
- `lib/audio_files.dart`: durable drafts, verified content-addressed files and retry-safe publishing.
- `lib/audio_screen.dart`: recording, recovery, playback and attachments.
- `lib/main.dart`: library, song editor and performance navigation.
- `docs/screenshots/`: rendered widget previews, not physical-device captures.

## GitHub

This folder is an independent Git repository on `main`. Create an empty GitHub repository and use your own remote URL:

```sh
git remote add origin https://github.com/YOUR_ACCOUNT/music-hub.git
git push -u origin main
```

No remote repository is created or published automatically. See [the roadmap](docs/roadmap.md) and [stack decision](docs/stack-decision.md) for scope and architecture.
