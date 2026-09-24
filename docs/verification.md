# Verification — 24 September 2026, version 0.7

## Passed

- Flutter static analysis: no issues.
- 69 pure Dart tests covering authored documents, SQLite persistence/upgrades, revisions/stale writes, tombstones, immutable recordings/drafts, tuner DSP/tracking, metronome synthesis, tempo estimation, notes and practice-loop coordinates.
- 24 Flutter-run tests covering existing song/recording/tuner/prototype flows, fixed-position editing and narrow-screen rendering, tab save/reopen, metronome lifecycle, microphone BPM capture/application/cancellation, notes workflow and A/B playback controls.
- Formatting and diff whitespace checks.

## Fixed-width tabs

Formatter tests exercise overwrite, backspace on content and repeated dashes, forward Delete, space advancement, selection deletion with protected labels, Unicode grapheme slots and whole-edit rejection when capacity is exceeded. A render-level check at 320 logical pixels with 2× system text verifies that the entire first string occupies one rendered line and stays within the field width. Font letter spacing is explicit so the field theme cannot invalidate width measurement.

Migration checks retain long row content across successive fixed-width blocks and preserve non-block annotations. Existing grid migration/store tests check arbitrary content (including CRLF, tabs and Unicode), identity/revisions, save/close/reopen, arrangement isolation and stale/deleted-parent protection. The phone-sized integration test types into a fixed block, appends another with keyboard insets, saves and reopens. `screenshots/tab-fixed.png` is the current preview; ASCII/grid/prototype previews are historical.

## BPM listening

Synthetic 12-second rhythmic signals at 60, 83, 100, 120, 137, 180 and 220 BPM are tested at 16/22.05/44.1 kHz with added noise, with estimates within two BPM in those cases. Silence, steady tones, random noise and short clips reject estimates. These fixtures establish deterministic behavior, not accuracy on arbitrary music.

Widget tests feed split PCM chunks through a fake recorder into the actual isolate estimator, verify explicit Use BPM application, and check permission denial, background cancellation, no automatic restart and recorder disposal. The existing metronome lifecycle/preferences and sample-positioned WAV tests still pass. Returning from microphone use reconfigures the native playback session before metronome start.

The estimator uses a smoothed energy-rise onset envelope and normalized autocorrelation. [Librosa’s tempo documentation](https://librosa.org/doc/0.11.0/generated/librosa.feature.tempo.html) provides background on onset-autocorrelation tempo estimation; this app uses its own small Dart implementation, without Librosa, ML or network calls. Half/double ambiguity is exposed to the user rather than silently changing tempo.

## Stage 7 workflow

A real SQLite test saves a standalone note, attaches it, edits it independently, rejects a stale save, reopens the database, detaches it through song deletion and checks confirmed note tombstones. The widget workflow captures an idea without a song, attaches it, reopens it through the song's Notes, and tests cancel/confirm deletion.

Practice-loop tests validate region bounds/minimum length and original-versus-clip time conversion. A fake native player verifies that A/B applies clipping plus repeat, an absolute 3-second seek becomes 1 second inside a 2–4-second clip, and clearing A/B restores the original source/repeat mode. These tests check control semantics; they do not play actual native audio.

Inspected phone-sized previews: `workflow-library.png`, `workflow-note.png`, `recording-ab-loop.png`, `metronome.png` and `tab-fixed.png`. Screenshots are widget renders, not captures from the user's phone.

## Physical-device status

The user reports Stage 6 metronome is looking good on iPhone. The new overwrite editor, microphone BPM estimation and Stage 7 workflows still need iPhone acceptance. No new native iOS/Android build or device session was performed by this tool. In particular, actual keyboard/composition behavior, music tempo estimation, microphone release/audio-session switching, native A/B boundaries and Bluetooth latency require the [iPhone checklist](iphone-checklist.md).

## Reproduce

Using Flutter 3.47.5 / Dart 3.13.4:

```sh
flutter pub get
flutter analyze
dart test test/document_test.dart test/store_test.dart test/audio_files_test.dart test/dsp_test.dart test/pitch_tracker_test.dart test/tab_lab_model_test.dart test/tab_document_test.dart test/metronome_test.dart test/tempo_estimator_test.dart test/notes_store_test.dart test/practice_loop_test.dart
flutter test test/widget_test.dart test/tab_lab_widget_test.dart test/tab_screen_test.dart test/metronome_screen_test.dart test/fixed_tab_test.dart test/workflow_test.dart test/bpm_listen_test.dart
flutter run -d <your-iphone-device-id>
```

Install over the current app to exercise migration. Tab native format advances to 3; the SQLite schema remains version 3 and uses its existing note/attachment tables. No history storage, audio rewriting, server, import/export or room profiling is introduced.
