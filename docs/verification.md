# Verification — 20 September 2026

## Passed

- Flutter static analysis: no issues.
- 13 model, SQLite and audio-file tests: exact text round trips; legacy sheet conversion; chord-marker recognition; unsupported format rejection; save/reopen and ordered revisions; recoverable conflicting edits; transaction rollback; immutable audio persistence; content deduplication; retry-safe saving after SQL failure; tombstoned recording attachments; database migration; invalid-file rejection without draft loss.
- Four Flutter widget tests: whole-sheet paste/save/reopen/performance at phone size; microphone denial without empty recordings; background capture finalization with a recoverable draft; editable highlighting and IME composition without text changes.
- Rendered editor, library and performance previews are in `screenshots/`. These are widget renders, not physical-device captures. Editor icons, text spacing and controls were visually inspected. The performance footer was corrected so it no longer consumes the content area.
- Formatting and `git diff --check` pass.

## Device validation still required

The user confirmed the previous version opens on the iPhone. This version introduces native recording/playback plugins and requires a full rebuild. Xcode is installed, but this tool environment blocked Swift package resolution with `sandbox-exec: sandbox_apply: Operation not permitted`; the native iOS build did not complete here.

Microphone capture, actual AAC decoding/playback, Bluetooth/routes, calls/interruptions, screen-awake and real keyboard behavior need the [iPhone checklist](iphone-checklist.md). The recording lifecycle test uses a mocked native recorder; it verifies app behavior and draft files, not audio quality or operating-system integration. Android device/build validation is also pending. No tab-entry usability study has been performed.

## Reproduce

Using Flutter 3.47.5 / Dart 3.13.4:

```sh
flutter pub get
flutter analyze
dart test test/document_test.dart test/store_test.dart test/audio_files_test.dart
flutter test test/widget_test.dart
flutter run -d <your-iphone-device-id>
```

Install over the existing app to preserve its local data. Dependencies are pinned in `pubspec.lock`.
