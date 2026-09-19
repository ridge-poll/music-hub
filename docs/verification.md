# Verification — 19 September 2026

## Passed

- Dart static analysis: no issues.
- Five tests against the production document/store code:
  - Lyric edits shift/clamp chord anchors correctly.
  - Native serialization retains identities, Unicode text and chord anchors; exports the supported ChordPro subset.
  - Save to an actual SQLite file, close, reopen and edit; verify identity and increasing logical revisions.
  - Two edits from the same base preserve the stale edit as a recoverable conflict without replacing the current document.
  - A database constraint failure rolls back the entire creation transaction and does not advance the caller's revision.
- Flutter compiled the test harness/app code during widget-test attempts.
- iOS and Android host projects generated with Flutter 3.47.5 / Dart 3.13.4.

## Pending

- The Flutter widget flow is implemented in `test/widget_test.dart`, but a completed passing run was not obtained in this restricted tool environment. The native test process did not connect to its local test harness. This is not counted as a passing test or as visual QA.
- No iPhone installation, simulator build, screen-awake verification, or native plugin integration test: full Xcode is not installed on this Mac. The Apple command-line tools are present.
- No Android device/build validation: Android SDK is not installed.
- No user testing, audio validation or tab-entry prototype testing has been performed.

Run the following from a normal development terminal after setting up Flutter:

```sh
flutter pub get
flutter analyze
dart test test/document_test.dart test/store_test.dart
flutter test test/widget_test.dart
```

Then follow the iPhone checklist. Widget tests use SQLite FFI and a mocked wake-lock channel; even a passing widget test cannot certify native screen-awake behavior or phone keyboard interaction.

## Tool environment notes

The SDK was downloaded into the task's `work/` directory, outside the repository. Restricted CPU detection incorrectly selected Intel tooling on this Apple Silicon Mac. Native ARM64 Dart and tester artifacts from the same engine revision were used locally to continue validation. Local SDK workarounds are not included in this repository and are not app requirements. Dependencies are locked in `pubspec.lock`.
