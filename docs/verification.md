# Verification — 24 September 2026, version 0.7.1

## Passed

- Flutter static analysis: no issues.
- 72 pure Dart tests covering authored documents, SQLite persistence/upgrades, revisions/stale writes, tombstones, immutable recordings/drafts, tuner DSP/tracking, metronome synthesis, tempo estimation, notes and practice-loop coordinates.
- 25 Flutter-run tests covering existing song/recording/tuner/prototype flows, fixed-position editing and narrow-screen rendering, tab save/reopen, metronome lifecycle, microphone BPM capture/application/cancellation, notes workflow and A/B playback controls.
- Formatting and diff whitespace checks.

## Fixed-width tabs

Formatter tests exercise overwrite, backspace on content and repeated dashes, forward Delete, space advancement, selection deletion with protected labels, Unicode grapheme slots and whole-edit rejection when capacity is exceeded. A render-level check at 320 logical pixels with 2× system text verifies that the entire first string occupies one rendered line and stays within the field width. Font letter spacing is explicit so the field theme cannot invalidate width measurement.

Migration checks retain long row content across successive fixed-width blocks and preserve non-block annotations. Existing grid migration/store tests check arbitrary content (including CRLF, tabs and Unicode), identity/revisions, save/close/reopen, arrangement isolation and stale/deleted-parent protection. The phone-sized integration test types into a fixed block, appends another with keyboard insets, saves and reopens. `screenshots/tab-fixed.png` is the current preview; ASCII/grid/prototype previews are historical.

## BPM listening

Synthetic 12-second rhythmic signals at 60, 83, 100, 120, 137, 180 and 220 BPM are tested at 16/22.05/44.1 kHz with added noise, with estimates within two BPM in those cases. Silence, steady tones, random noise and short clips reject estimates. These fixtures establish deterministic behavior, not accuracy on arbitrary music.

Widget tests feed split PCM chunks through a fake recorder into the actual isolate estimator, verify explicit Use BPM application, and check permission denial, background cancellation, no automatic restart and recorder disposal. The existing metronome lifecycle/preferences and sample-positioned WAV tests still pass. Returning from microphone use reconfigures the native playback session before metronome start.

The estimator uses a smoothed energy-rise onset envelope and normalized autocorrelation. [Librosa’s tempo documentation](https://librosa.org/doc/0.11.0/generated/librosa.feature.tempo.html) provides background on onset-autocorrelation tempo estimation; this app uses its own small Dart implementation, without Librosa, ML or network calls. Half/double ambiguity is exposed to the user rather than silently changing tempo.

## Stage 7 Song-first revision

SQLite checks cover last-edited ordering across chords, tabs, notes, recording attachment and deletion. Read-only visits and identical saves retain timestamps/revisions. A first child document and its new Song commit atomically; duplicate notes and mismatched parents cannot leave partial metadata changes. Upgrade fixtures cover database versions 1, 2 and 3, including standalone notes converted into Songs, all titles/bodies retained when consolidating attached notes, existing recordings preserved, and an inert second reopen. Old fixtures were adjusted to remove the new columns before simulating an older schema.

Phone-sized widget workflows cover untouched and whitespace-only + New visits, default/extra blank tab blocks creating nothing, notes-only and tab-only direct opening, multi-component workspace routing, Song-side recording attachment, and Dark Mode persistence across rebuilding the app. Existing confirmed song/recording deletion, interrupted capture and microphone denial tests still pass. Test IO waits include the route/FAB animation and subsequent SQLite work.

The playback test drags both real timeline handles to a 2–4-second region and verifies native clipping and repeat. Tapping at three seconds produces a one-second seek inside that clip. Dragging both handles back to the ends restores the full source and disables repeat. No second Slider or RangeSlider exists. These tests check control semantics with a fake player; they do not play actual native audio.

Inspected current phone-sized renders: `workflow-library.png`, `workflow-note.png`, `song-workspace.png`, `recording-ab-loop.png`, `settings-dark.png` and `tab-fixed.png`. Other screenshots document earlier stages. These are widget renders, not captures from the user's phone.

## Physical-device status

The user reports Stage 6 metronome is looking good on iPhone. The Song-first Stage 7 revision needs iPhone acceptance before Stage 8. The overwrite editor and microphone BPM estimation also retain their device checklist where not yet accepted. No new native iOS/Android build or device session was performed by this tool. In particular, actual keyboard/composition behavior, music tempo estimation, microphone release/audio-session switching, native A/B boundaries and Bluetooth latency require the [iPhone checklist](iphone-checklist.md).

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
