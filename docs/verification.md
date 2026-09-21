# Verification — 20 September 2026, version 0.3

## Passed

- Flutter static analysis: no issues.
- 48 Dart tests covering document round trips/conversion, current-song persistence, stale-write rejection, rollback, deletion tombstones and recording detachment, database upgrades including history removal, immutable audio files and retry-safe drafts, and DSP.
- DSP cases include guitar-range fundamentals from 65–659 Hz at 22.05/44.1/48 kHz with DC offset and a second harmonic stronger than the fundamental. Error remains below five cents in those synthetic cases. Silence, low-level noise and broadband noise reject pitch. FFT peak/amplitude and note/cents conversion are checked.
- Seven Flutter widget tests cover paste/save/reopen/performance, permission denial, unfinished recording preservation on backgrounding, swipe/confirmation and detail song deletion, recording swipe deletion, real PCM chunk decoding through the tuner isolate to the note display and microphone teardown, and IME-safe highlighting.
- Editor, library, performance and tuner previews are widget renders in `screenshots/`, not physical-device captures.
- Formatting and diff whitespace checks pass.

## Physical-device status

Stage 2 recording/save/playback is confirmed working by the user on their actual iPhone. Stage 3 introduces a separate PCM/DSP path and still needs iPhone acceptance: compare real strings with a trusted tuner, test custom tuning, permissions, route changes, background/interruption and tuner/recording handoff. Native microphones are mocked in automated widget tests. Synthetic accuracy does not certify noisy-room or real-instrument behavior.

No Stage 3 native build or phone session was performed by this tool. The prior native build attempt was blocked by nested sandbox restrictions during Swift package resolution; the user subsequently built and validated Stage 2 themselves. No Android validation or tab-entry usability study has been performed.

## Reproduce

Using Flutter 3.47.5 / Dart 3.13.4:

```sh
flutter pub get
flutter analyze
dart test test/document_test.dart test/store_test.dart test/audio_files_test.dart test/dsp_test.dart
flutter test test/widget_test.dart
flutter run -d <your-iphone-device-id>
```

Install over the existing app. The version 3 database migration deliberately drops saved history while preserving current songs; deletion retains ordered tombstones and shared immutable audio assets. Follow the [iPhone checklist](iphone-checklist.md).
