# Verification — 25 September 2026, V1 (1.0.0+10)

## Results

- **Flutter analyzer: no issues.**
- **83 pure Dart tests passed** against authored models, actual SQLite databases/files, DSP and playback-coordinate logic.
- **34 Flutter tests passed** covering UI workflows, fixed-width tab editing, mocked microphone/player lifecycle and the new file-operation UI. **117 tests total.**
- Performance Mode additionally rendered at iPhone size with real fonts for visual inspection; this is a widget preview, not an iPhone capture.
- Formatting and `git diff --check` passed.
- `flutter pub get` completed with the versioned lockfile. No tuner DSP parameters changed.

## Stage 8 checks

Real ZIP/SQLite round trips retain exact chords/tab/notes/annotations, stable Song/document/Recording/asset IDs, titles, dates, logical edit order, preferences, multiple recordings attached to a Song and independent recordings. Tests restore into both the same and a separate library, repeat restore without duplicates, and verify subsequent edits advance recency. Human-readable archive payloads are inspected directly; there is no database file in the ZIP.

Corruption tests cover unsafe/duplicate paths, symlinks, extra files, missing audio, altered content, unsupported format versions, duplicate identities, missing Song relationships, invalid dates/preferences and invalid document references. Preparation leaves the live library unchanged. Changed staged audio is rejected at commit. A forced SQLite trigger failure rolls back replacement and removes newly installed audio. An empty/deleted library round-trips without resurrecting deleted content. Unfinished drafts block backup/restore explicitly.

Text tests cover exact plain-text preservation, empty imports, simple ChordPro metadata/chords/chorus conversion and retention of unknown directives. Audio-file tests cover byte/extension preservation, deduplication and rejection of empty input. Native codec decoding and Files dialogs are outside these pure tests.

UI tests verify file-save cancellation is not reported as success, successful text export contains the exact text, failed export shows an error, restore displays its contents and requires confirmation, cancel preserves the current library, and confirmed restore replaces it. OS dialogs are injected fakes; filesystem and database operations are real. Performance Mode tests verify 8–32 bounds, long-line wrapping and only vertical Scrollables. Normal metronome tests assert Listen for BPM is absent.

A 500-Song fixture validates list ordering and snapshot completeness while repeated reads leave createdAt/lastEdited/edit order unchanged. Component summaries now use maps/sets instead of per-Song full-list scans. This is not a maximum-size device benchmark; backup size bounds are documented separately.

## Existing behavior retained

- SQLite upgrade fixtures from versions 1, 2, 3 and 4 to version 5 preserve content. Existing Song creation dates that were never stored remain unknown; newly created Songs receive dates. Old saved-history tables remain removed.
- Actual edits reorder Songs; read-only visits, identical saves and tab migration do not. First document plus Song commit atomically. Untouched/whitespace/default-tab creation leaves nothing persisted.
- Single populated components route directly; multiple components route to the workspace. Independent recordings and multiple Song recordings remain supported. Dark Mode, confirmed swipe/detail deletion, stale-save rejection and offline local persistence remain tested.
- Tab format 4 retains all prior grid/ASCII/fixed-block migrations. Tests cover overwrite, Unicode slots, all-six-string continuation, end bars, whole-empty-block collapse, protected nonempty strings, simple ASCII paste, annotations, undo/redo and narrow-screen rendering (including 320 logical pixels with 2× system text).
- Recording draft safety, retry after failed save, immutable audio, permission denial, background capture finalization and player/tuner/metronome disposal/interruption are covered using local files and mocked platform endpoints. A/B tests verify native clip/repeat commands and coordinate mapping without actually playing audio.
- Synthetic tuner/FFT/tracking and metronome timing tests still pass. Experimental BPM tests remain, but physical feedback established that arbitrary-music estimation is unreliable; the feature is hidden rather than claimed validated.

## Physical-device status and build limitation

The user explicitly validated **tuner, normal metronome, recording/playback and A/B region interaction on iPhone**. Upper-string tuner acquisition is a later refinement, especially B/high E. DSP was left unchanged in this pass.

An unsigned native iOS build was attempted with `flutter build ios --debug --no-codesign --no-pub`. Initial Swift cache writes were blocked; after granting the necessary cache paths, Xcode dependency resolution failed with **`sandbox-exec: sandbox_apply: Operation not permitted`**. Therefore this environment did **not** complete a native iOS build or certify the newly added file-dialog plugins. CoreSimulator service access was also unavailable. No Android device build/test is claimed.

Remaining acceptance: full rebuild/install over the existing iPhone app, Performance Mode sizes/wrapping, Files export/import (local and iCloud), actual audio codecs, backup/restore of the real library including longer recordings and interruption/space/cancellation behavior. Use the focused [iPhone checklist](iphone-checklist.md). No new feature stage begins automatically.

## Reproduce

SDK used: Flutter 3.47.5 / Dart 3.13.4.

```sh
flutter pub get
flutter analyze
# Models, DSP, real SQLite and files:
dart test test/document_test.dart test/store_test.dart test/audio_files_test.dart test/dsp_test.dart test/pitch_tracker_test.dart test/tab_lab_model_test.dart test/tab_document_test.dart test/metronome_test.dart test/tempo_estimator_test.dart test/notes_store_test.dart test/practice_loop_test.dart test/song_store_test.dart test/portability_test.dart
# Flutter UI and mocked native lifecycle:
flutter test test/widget_test.dart test/tab_lab_widget_test.dart test/tab_screen_test.dart test/metronome_screen_test.dart test/fixed_tab_test.dart test/workflow_test.dart test/bpm_listen_test.dart test/portability_screen_test.dart
flutter run -d <your-iphone-device-id>
```

SQLite schema: **5**. Tab document format: **4**. Portable ZIP format: **1**. No backend, sync, new DSP tuning, full notation importer or additional feature stage was introduced.
