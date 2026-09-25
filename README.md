# Music Hub

A local-first music workspace for iOS and Android, with iPhone as the lead test device. Version 1.0.0 centers the app on Songs: a musician’s notepad with local recording, tuner and metronome tools.

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

Optional `{Am}` notation gets a simple highlight while editing and a rounded label in performance mode. It remains literal text in storage. `[Intro]` is just text. Import supports a small ChordPro subset; export uses ordinary UTF-8 text. Unknown imported directives remain literal text.

Songs autosave locally and have an explicit Save action. Performance Mode wraps to the screen with vertical scrolling only, font sizes 8–32 (default 18), screen-awake and automatic/manual scrolling. Older line-based songs are converted on read with lyrics/chords retained. Saved-version history has been removed: the database upgrade deletes historical copies while retaining current songs and normal autosave.

## Tabs

Open a song and tap **Tab**, or start with **+ New → Tab**. Six continuous strings wrap into 40-position visual blocks fitted to the phone. Typing overwrites dashes and automatically continues on the same string below. Only the first block has opening bars; only the final block has closing bars. Scrolling is vertical only.

Backspace restores dashes and moves left; space over an empty position advances. Backspacing in a fully empty final block collapses it, but content on any string protects the block. The first block is never removed. **+ Tab Block** remains available. Long plain text and simple complete six-row ASCII paste wrap without musical interpretation.

Tabs retain local autosave and Song ownership. Existing blocks join into continuations without losing text; older annotations remain under Saved annotations. Export produces readable ASCII text. Backup under More creates a complete-library ZIP through Files; see [backup format and restore semantics](docs/backup-format.md).

## Songs and creation

**Songs** is home. Compact cards sort by actual edits, not visits. Each Song can have chords/lyrics, an ASCII tab, one notes document and multiple recordings, in any combination. A single populated component opens directly; otherwise the Song workspace offers its documents and recordings. Use the folder button to reach the workspace from a direct editor.

**+ New** starts Chords/Lyrics, Tab or Notes. An untouched editor or blank tab template saves nothing. Meaningful text or title edits create the Song locally. Existing standalone notes become Songs on upgrade; multiple attached notes combine into the Song’s single notes document with their text retained.

Navigation is **Songs | Recordings | Tuner | More**. More contains Metronome, Back Up Music Hub, Restore Music Hub and Settings, including a persistent Dark Mode switch.

## Metronome

Open **More → Metronome** for 40–240 BPM, tap tempo, time signature and per-beat accents/muting. Settings persist. BPM counts the displayed note unit; changes restart the bar. Audio uses sample-positioned native playback and stops on background/exit/interruption.

Automatic microphone BPM estimation is hidden from V1 following unreliable physical-device results. Experimental source/tests remain for later work; the normal metronome is iPhone-validated.

## Recordings

- Open **Recordings → Record** to start an independent take; microphone permission is requested when needed.
- Live input level, elapsed time, pause/resume, stop, name and save locally.
- Playback has play/pause, seek and back ten seconds.
- One timeline includes the playhead and two thin edge handles. Drag a handle inward to repeat that region automatically. Return both handles to the ends for normal playback. Original audio stays untouched.
- From a Song’s Recordings screen, record a new take or tap **+** to add an unattached recording. A Song can contain multiple recordings. The player also offers attachment changes.
- Interrupted saves remain visible as recoverable drafts. Published audio is immutable and addressed by its SHA-256 hash. Attachments are separate ordered rows.

Capture uses mono AAC in an M4A container, requesting 44.1 kHz and 128 kbps through the native recorder. The operating system may negotiate the actual input format. Audio interruptions pause recording for manual resume. Backgrounding stops/finalizes the current take and keeps it as a draft; background capture is intentionally not enabled. A force-killed or otherwise incomplete encoded file may not be playable; recovery never silently deletes it.

There is no backend or account requirement. Data stays in this app installation. Device sync is deferred; versioned library backup/restore and individual text/audio export are available. Wait for **Saved on this device** before force-quitting the editor; an OS kill during the 800 ms autosave delay can lose the latest unsaved keystrokes.

## Delete and tune

Swipe left on a saved song or recording to reveal its trash button, or use Delete Song / Delete Recording at the bottom of its detail screen. Both ask for confirmation. Deleting a song keeps its recordings as unattached ideas. Deletion uses ordered tombstones; immutable audio blobs are retained, including those shared by other recordings. There is no individual undelete UI or audio garbage collector; full-library restore uses a saved backup.

Tap **Tuner** in primary navigation. It listens locally, shows a string target and cents, and supports automatic or manual string selection. Settings offer Standard, Drop D and custom six-string tuning saved locally. Expand Audio details for frequency, periodicity confidence, input level and a live FFT spectrum. Reference pitch is A4 = 440 Hz. No tuner audio is saved or uploaded. The tuner pauses on background/interruption; restart explicitly.

The tuner is iPhone-validated for V1; high-string acquisition refinement is deferred. See [roadmap](docs/roadmap.md) for current completion and later work. The DSP uses the existing [record PCM stream API](https://pub.dev/packages/record), with analysis in a Dart isolate.

## Export, import and backup

Song workspace → **Export Song** saves individual chords/lyrics, tabs, notes or attached audio. Recording playback also has an Export action. **+ New → Import text / ChordPro** accepts UTF-8 text and straightforward ChordPro. Recordings and Song recordings offer **Import audio**, with native readability validation before saving. Tab copy/paste remains the simple interchange path; no Guitar Pro or MusicXML support is added.

More → **Back Up Music Hub** saves one dated ZIP using the normal Files save interface. **Restore Music Hub** validates the selected ZIP before confirming replacement of the active library. Restore is not a merge; back up first if you want to preserve the current library. Save/discard unfinished recording drafts before either operation. The archive holds readable text/audio plus versioned JSON, never a raw database as the primary format. [Format and limits](docs/backup-format.md).

## Update the running iPhone app

Stage 8 adds native Files dialog plugins. **Stop the previous run and do a full rebuild; hot reload alone is insufficient.** Your existing signing settings have been preserved.

From this repository in your normal development terminal:

```sh
flutter pub get
flutter run -d <your-iphone-device-id>
```

Use `flutter devices` to obtain the device ID. Do not uninstall the app to update it: install the new build over the existing app to retain the local library. Xcode 27 and Flutter are already installed on the lead development Mac. For another machine, follow [Flutter's iOS setup guide](https://docs.flutter.dev/platform-integration/ios/setup).

The user has validated tuner, normal metronome, recording/playback and A/B interaction on iPhone. Stage 8 Files flows and Performance Mode refinements need the focused [phone acceptance session](docs/iphone-checklist.md). V1 feature development stops here.

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
- `lib/tab_document.dart`, `lib/fixed_tab.dart` and `lib/tab_screen.dart`: continuous six-string overwrite text, migration and autosave.
- `lib/backup_service.dart`, `lib/library_bundle.dart`, `lib/store_portability.dart`: readable ZIP snapshots, validation and atomic metadata restore.
- `lib/portability_screen.dart` and `lib/text_portability.dart`: native Files dialogs and conservative import/export.
- `docs/screenshots/`: rendered widget previews, not physical-device captures.

## GitHub

This folder is an independent Git repository on `main`. Create an empty GitHub repository and use your own remote URL:

```sh
git remote add origin https://github.com/YOUR_ACCOUNT/music-hub.git
git push -u origin main
```

No remote repository is created or published automatically. See [the roadmap](docs/roadmap.md) and [stack decision](docs/stack-decision.md) for scope and architecture.
