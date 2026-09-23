# Verification — 23 September 2026, version 0.6

## Passed

- Flutter static analysis: no issues.
- 65 Dart tests covering document round trips/conversion, current-song persistence, stale-write rejection, rollback, deletion tombstones and recording detachment, database upgrades including history removal, immutable audio files and retry-safe drafts, DSP, temporal pitch tracking and the prototype edit/task model.
- DSP cases include guitar-range fundamentals from 65–659 Hz at 22.05/44.1/48 kHz with DC offset and a second harmonic stronger than the fundamental. Error remains below five cents in those synthetic cases. Silence, low-level noise and broadband noise reject pitch. FFT peak/amplitude and note/cents conversion are checked.
- 14 Flutter widget tests: the existing seven song/recording/tuner flows plus four phone-sized prototype entry/undo/redo/feedback flows and the archived lab menu/correction/results flow, plus ASCII-tab integration and metronome lifecycle/preferences tests. The tuner test supplies multiple PCM windows to exercise confidence acquisition; closed swipe rows expose no delete background/button.
- Rendered editor/library/performance/tuner and all four prototype previews are in `screenshots/`. Headstock labels, wide scale and active-string prototype layout were inspected at iPhone width. These are test renders, not screenshots from the user's phone.
- Six temporal tracking tests cover jitter suppression, smooth tuning to +200 cents, unrelated transients, quiet harmonic decay, held-reading expiry, rapid new-string/octave acquisition, PCM decay/noise, and target hysteresis (several cases share a test).
- Three prototype model tests verify creation, all ten correction instructions, and undo/redo/position edits against the same reference fixture. No usability scores or winning variant are inferred from tests.
- Formatting and diff whitespace checks pass.

## Final Stage 5 revision verification

Five tab model/store tests cover exact text (spaces, backslashes, CRLF, tabs and Unicode), conversion of multiple grid blocks, preservation of unusual cell content, in-place SQLite migration/save/close/reopen with unchanged identity, arrangement isolation, stale/deleted-parent protection and duplicate-tab rejection.

The phone-sized UI test opens Tab from a song, edits one monospaced field, checks horizontal content width, appends a blank block with simulated keyboard insets, saves and reopens exact content. The inspected preview is `screenshots/tab-ascii.png`. Older grid/prototype previews are historical.

## Stage 6 verification

Three pure tests cover tap-tempo averaging/reset, preference validation and PCM WAV generation at 137 BPM. Audio assertions check whole-bar duration, sample-positioned onsets throughout the loop, accented versus ordinary click energy, silent beats and silent boundaries. One phone-sized widget test covers tempo/accent edits, persistence, start/stop, native-position events, interruption, backgrounding during a pending start, disposal and reopen without autoplay. Audio is replaced by a fake backend in this UI test. The inspected preview is `screenshots/metronome.png`.

## Physical-device status

The user tested the Stage 5 grid and requested this final ASCII simplification. Final ASCII migration/keyboard behavior and Stage 6 native audio playback still need iPhone acceptance. No new native iOS/Android build or physical-device session was performed by this tool. Screenshots are widget renders, not phone captures.

Sample-placement tests do not prove hardware output timing, gapless native loop transitions, Bluetooth latency or audio-session recovery. Use the device checklist, including listening beyond a complete loop. Room-acoustics profiling remains an idea only.

## Reproduce

Using Flutter 3.47.5 / Dart 3.13.4:

```sh
flutter pub get
flutter analyze
dart test test/document_test.dart test/store_test.dart test/audio_files_test.dart test/dsp_test.dart test/pitch_tracker_test.dart test/tab_lab_model_test.dart test/tab_document_test.dart test/metronome_test.dart
flutter test test/widget_test.dart test/tab_lab_widget_test.dart test/tab_screen_test.dart test/metronome_screen_test.dart
flutter run -d <your-iphone-device-id>
```

Install over the existing app. The version 3 database migration deliberately drops saved history while preserving current songs; deletion retains ordered tombstones and shared immutable audio assets. Follow the [iPhone checklist](iphone-checklist.md).
