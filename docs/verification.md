# Verification — 21 September 2026, version 0.4

## Passed

- Flutter static analysis: no issues.
- 57 Dart tests covering document round trips/conversion, current-song persistence, stale-write rejection, rollback, deletion tombstones and recording detachment, database upgrades including history removal, immutable audio files and retry-safe drafts, DSP, temporal pitch tracking and the prototype edit/task model.
- DSP cases include guitar-range fundamentals from 65–659 Hz at 22.05/44.1/48 kHz with DC offset and a second harmonic stronger than the fundamental. Error remains below five cents in those synthetic cases. Silence, low-level noise and broadband noise reject pitch. FFT peak/amplitude and note/cents conversion are checked.
- 12 Flutter widget tests: the existing seven song/recording/tuner flows plus four phone-sized prototype entry/undo/redo/feedback flows and the lab menu/correction/results flow. The tuner test supplies multiple PCM windows to exercise confidence acquisition; closed swipe rows expose no delete background/button.
- Rendered editor/library/performance/tuner and all four prototype previews are in `screenshots/`. Headstock labels, wide scale and active-string prototype layout were inspected at iPhone width. These are test renders, not screenshots from the user's phone.
- Six temporal tracking tests cover jitter suppression, smooth tuning to +200 cents, unrelated transients, quiet harmonic decay, held-reading expiry, rapid new-string/octave acquisition, PCM decay/noise, and target hysteresis (several cases share a test).
- Three prototype model tests verify creation, all ten correction instructions, and undo/redo/position edits against the same reference fixture. No usability scores or winning variant are inferred from tests.
- Formatting and diff whitespace checks pass.

## Physical-device status

Stages 2 and 3 are reported working on the user's iPhone. The new tracking thresholds, wide scale, headstock and clipping refinements still need device comparison. Stage 4 is ready for actual creation/correction trials; no human comparison results exist yet. Stage 5's persistent editor is not implemented or selected.

Microphone sources are mocked in widget tests. Synthetic tones and scripted tracking sequences cannot certify noisy-room behavior or commercial-tuner parity. The on-device comparison guide is [tab-lab.md](tab-lab.md), and tracker behavior/limitations are in [tuner-tracking.md](tuner-tracking.md). No new native iOS/Android build or device session was performed by this tool.

## Reproduce

Using Flutter 3.47.5 / Dart 3.13.4:

```sh
flutter pub get
flutter analyze
dart test test/document_test.dart test/store_test.dart test/audio_files_test.dart test/dsp_test.dart test/pitch_tracker_test.dart test/tab_lab_model_test.dart
flutter test test/widget_test.dart test/tab_lab_widget_test.dart
flutter run -d <your-iphone-device-id>
```

Install over the existing app. The version 3 database migration deliberately drops saved history while preserving current songs; deletion retains ordered tombstones and shared immutable audio assets. Follow the [iPhone checklist](iphone-checklist.md).
