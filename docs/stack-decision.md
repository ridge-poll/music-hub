# Stack decision — 19 September 2026

Choose Flutter / Dart for the shared iOS + Android app, SQLite through sqflite for local persistence, and platform-specific Swift/Kotlin modules where the audio workload requires them. iPhone is the lead test device. This is a mobile app, not a website wrapper.

## Comparison against actual constraints

| Requirement | Flutter | React Native + Expo development builds | Separate Swift/Kotlin apps |
|---|---|---|---|
| Local-first relational persistence | SQLite plugin; explicit migrations | expo-sqlite; explicit migrations | Native SQLite wrappers |
| Recording/playback | Plugins or native audio modules | Expo Audio or native modules | Direct platform APIs |
| Low-latency DSP | Native callback/worker or FFI; isolates for suitable non-real-time work | Native callback/worker or JSI module | Direct native implementation |
| Tab gestures, waveform, spectrum | CustomPainter and gesture system in shared UI | Custom rendering library plus gesture tooling | Two implementations |
| Native escape hatch | Swift/Kotlin platform channels; FFI | Local Expo modules/custom native projects | Already native |
| First slice cost | One codebase, a modest Dart learning cost | One codebase, familiar to web developers | Twice the UI work |

Flutter wins here because the future work combines a substantial custom canvas interaction surface and ordinary mobile screens, without an existing React investment. This is a judgment about this project's fit, not a claim that Flutter audio is intrinsically faster. Neither framework makes Dart/JavaScript UI execution a safe real-time audio callback.

## Audio validation gate (slice 2)

Evaluate maintained recording/playback plugins against real-device needs before adopting one. Validate microphone permissions, interruption/recovery (calls/Siri), route changes, wired/Bluetooth headphones, sample rates, foreground/background policy, long recordings, disk-full failures, capture finalization and relaunch. Need raw PCM access for future YIN/FFT: if a recorder only exposes encoded files or coarse metering, use a Swift AVAudioEngine / Android AudioRecord module instead. Send reduced display data to Flutter; never stream expensive per-sample UI messages. Keep capture callbacks allocation-light and off the UI thread. Do not implement DSP, ML or a generalized audio framework in slice 1.

For trim, retain original audio and create a new content-addressed asset with source and derivation parameters. Initial playback-speed changes can be non-destructive playback settings; exported transformed audio must become a new asset. Recording permissions should first be requested by a recording action, not app startup.

## Persistence and sync boundary

SQLite is authoritative in slice 1. No account, server or network is required at runtime. Each installation creates a local owner UUID and device UUID. Pairing devices to one owner/account remains future sync work; two installations do not automatically share ownership.

All persisted entity rows have UUID, owner, logical revision, device ID and tombstone columns. A transactional local Lamport counter orders this device's writes independently of wall clocks. Future sync must advance the counter on receipt, compare `(counter, device_id)`, retain base version ancestry to detect concurrency and persist losing copies. The local counter alone is not cross-device causality detection. No sync compatibility claim is made until that integration is tested. Prefer a suitable framework's native mechanism at that point and migrate the local metadata as needed.

Atomic transactions create Song, hidden default Arrangement, join row, ChordSheet and history. Current content and version history cannot diverge from a partial save. A stale base revision preserves the attempted edit in History and leaves the current document intact. Recovery creates a separate song. No delete UI yet; future deletion must write ordered tombstones, never hard-delete synced rows.

Chord sheet data is versioned native JSON. Version 0.2 replaces lyric lines/anchors with one exact plain-text string at the user’s request. Format-1 content is converted on read; history payloads are not rewritten. Optional `{Chord}` markers affect presentation only; this is not a ChordPro parser. No universal musical-event abstraction. Tab storage is reserved only: before implementation, define its independent ordered position structure, with optional duration, based on the prototype results. Sections are range annotations, not content containers. Candidates and analysis runs are separate unused tables and cannot enter the authored UI automatically.

## Sources

- [Flutter platform-specific code](https://docs.flutter.dev/platform-integration/platform-channels)
- [Flutter CustomPaint](https://api.flutter.dev/flutter/widgets/CustomPaint-class.html)
- [Flutter SQLite recipe](https://docs.flutter.dev/cookbook/persistence/sqlite)
- [Flutter isolates](https://docs.flutter.dev/perf/isolates)
- [Expo development builds and native modules](https://docs.expo.dev/workflow/overview/)
- [Flutter iOS setup](https://docs.flutter.dev/platform-integration/ios/setup)

## Slice 2 implementation update — 20 September 2026

Use `record` 7.1.1 for native capture, `just_audio` 0.10.6 for local playback, and `audio_session` for playback session configuration. Capture supports future raw-PCM access through the recorder API, but this release uses AAC files and native amplitude readings only. No FFT, waveform synthesis or ML has been added. See [record's platform matrix and streaming API](https://pub.dev/packages/record), [just_audio's local playback API](https://pub.dev/packages/just_audio) and [audio_session](https://pub.dev/packages/audio_session). Physical audio quality, latency and route handling remain an iPhone acceptance gate.

Database version 2 adds recording duration and display-only creation time. Revision ordering still uses the logical counter. Audio drafts live under Documents/audio/drafts; verified, immutable assets live under Documents/audio/objects/<sha256>.m4a. The database stores relative paths, so an app-container path change does not break links. A database failure leaves the draft and its bytes intact. After a successful commit, cleanup is best-effort and retries use the stable recording UUID. Existing identical blobs are verified before use.
