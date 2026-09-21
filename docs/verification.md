# Verification — 21 September 2026, version 0.5

## Passed

- Flutter static analysis: no issues.
- 60 Dart tests covering document round trips/conversion, current-song persistence, stale-write rejection, rollback, deletion tombstones and recording detachment, database upgrades including history removal, immutable audio files and retry-safe drafts, DSP, temporal pitch tracking and the prototype edit/task model.
- DSP cases include guitar-range fundamentals from 65–659 Hz at 22.05/44.1/48 kHz with DC offset and a second harmonic stronger than the fundamental. Error remains below five cents in those synthetic cases. Silence, low-level noise and broadband noise reject pitch. FFT peak/amplitude and note/cents conversion are checked.
- 13 Flutter widget tests: the existing seven song/recording/tuner flows plus four phone-sized prototype entry/undo/redo/feedback flows and the archived lab menu/correction/results flow, plus the persistent tab grid integration test. The tuner test supplies multiple PCM windows to exercise confidence acquisition; closed swipe rows expose no delete background/button.
- Rendered editor/library/performance/tuner and all four prototype previews are in `screenshots/`. Headstock labels, wide scale and active-string prototype layout were inspected at iPhone width. These are test renders, not screenshots from the user's phone.
- Six temporal tracking tests cover jitter suppression, smooth tuning to +200 cents, unrelated transients, quiet harmonic decay, held-reading expiry, rapid new-string/octave acquisition, PCM decay/noise, and target hysteresis (several cases share a test).
- Three prototype model tests verify creation, all ten correction instructions, and undo/redo/position edits against the same reference fixture. No usability scores or winning variant are inferred from tests.
- Formatting and diff whitespace checks pass.

## Stage 5 verification

Three new model/store tests verify exact arbitrary cell text (including whitespace, backslashes, multiline and Unicode), stable column IDs across appended blocks, actual SQLite save/close/reopen, arrangement isolation, independent song revisions, duplicate-tab rejection, stale saves and deleted-song protection.

The new phone-sized UI test opens Tab from a song, edits cells, transfers keyboard focus through arrows and keyboard Next, adds a block with simulated keyboard insets, saves, navigates back and reopens exact content. The grid preview is in `screenshots/tab-grid.png`; fixed string labels and the horizontally scrolling grid are visually checked. These are widget renders, not phone captures.

## Physical-device status

The user completed Stage 4 iPhone comparison and chose free-form text cells over specialized fret/string controls. Stage 5 now implements that direction and needs its own iPhone acceptance session. The older prototype tests remain regression checks for archived code; Tab lab is removed from navigation. No new native iOS/Android build or device session was performed by this tool.

Microphone sources are mocked in widget tests; native keyboard behavior and real-room pitch tracking still require physical-device checks. Room-acoustics profiling is a later idea only, with no implementation or measurement claims.

## Reproduce

Using Flutter 3.47.5 / Dart 3.13.4:

```sh
flutter pub get
flutter analyze
dart test test/document_test.dart test/store_test.dart test/audio_files_test.dart test/dsp_test.dart test/pitch_tracker_test.dart test/tab_lab_model_test.dart test/tab_document_test.dart
flutter test test/widget_test.dart test/tab_lab_widget_test.dart test/tab_screen_test.dart
flutter run -d <your-iphone-device-id>
```

Install over the existing app. The version 3 database migration deliberately drops saved history while preserving current songs; deletion retains ordered tombstones and shared immutable audio assets. Follow the [iPhone checklist](iphone-checklist.md).
