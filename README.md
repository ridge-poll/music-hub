# Music Hub

A guitar-first, offline personal music workspace for iOS and Android. Initial hands-on testing targets iPhone.

This repository implements the first vertical slice: **write chords/lyrics → save locally → reopen → performance mode**. It is not the complete V1 feature set.

## What works in this slice

- Create songs and search by title/artist.
- Edit lyric lines visually; place chords at the text cursor, then tap their labels to edit/remove.
- SQLite persistence with debounced autosave, explicit Save, save-before-navigation and visible failure states.
- Hidden default arrangement, client UUIDs, owner/device identity and transactional logical revisions.
- Saved-version history and recovery into a separate song; stale edits are preserved.
- One-tap performance mode with larger adjustable type, manual/automatic scrolling and screen-awake support.
- Copy the supported chord/lyric subset as ChordPro to the clipboard.

No account, backend or network connection is needed to use these features. Data is local to this app installation. Device sync and native full-fidelity backup/export are not implemented. Removing the app can remove its local library. Wait for **Saved on this device** before force-quitting; an OS kill during the short autosave debounce can lose unsaved keystrokes.

## Stack

Flutter/Dart + SQLite (`sqflite`), with Swift and Kotlin native hosts. See [the stack decision](docs/stack-decision.md) for the comparison, audio integration boundary and sync limitations. The next slice validates real recording/playback on iPhone before adding more editor functionality.

## Run on iPhone

1. Install Flutter 3.47.5 (the SDK used here) or a compatible newer stable SDK, and full Xcode; command-line tools alone are insufficient. Use [Flutter's iOS setup guide](https://docs.flutter.dev/platform-integration/ios/setup) for Xcode selection, licenses, platform support and any required CocoaPods setup.
2. Run `flutter doctor -v` and resolve the iOS toolchain checks.
3. From this repository run:

   ```sh
   flutter pub get
   flutter analyze
   dart test test/document_test.dart test/store_test.dart
   flutter test test/widget_test.dart
   ```

4. Connect/unlock your iPhone, trust this Mac and enable Developer Mode when prompted. Run `flutter devices`.
5. Open the iOS project/workspace in Xcode. Select Runner → Signing & Capabilities → your Apple development team. Change `dev.personal.musicHub` to your own unique bundle identifier if needed. Keep automatic signing enabled for development.
6. Run `flutter run -d <your-iphone-device-id>` from this folder. For a self-contained release build on the device, use `flutter run --release -d <your-iphone-device-id>` after signing is configured.
7. Use [the hands-on acceptance checklist](docs/iphone-checklist.md), including offline relaunch and screen-awake checks.

Flutter SDK/packages are development dependencies; users do not need them on the phone. The SDK used during development lives outside this repository in the task's ignored scratch area. Install your own SDK for ongoing work.

Android uses the same Dart code: install the Android SDK/toolchain, resolve `flutter doctor` and run `flutter run -d <android-device-id>`. Native device builds are not yet certified on either platform.

## Repository layout

- `lib/document.dart`: authored document format and chord anchors.
- `lib/store.dart`: SQLite schema, atomic saves, persisted counter and history.
- `lib/main.dart`: library, visual editor and performance screen.
- `test/`: document, persistence/conflict and full widget-flow checks.
- `ios/`, `android/`: native hosts.
- `docs/`: decisions, sequence, test checklist and verification record.

See [verification status](docs/verification.md) for exactly what has been checked. Keep `pubspec.lock` under version control. Do not commit device signing credentials, generated builds or your local database.

## GitHub

The folder is an independent Git repository on `main`. To publish it, create an empty GitHub repository, then run these commands from this folder with your own URL:

```sh
git remote add origin https://github.com/YOUR_ACCOUNT/music-hub.git
git push -u origin main
```

No GitHub remote or public repository is created automatically.

## What's next

See [the delivery sequence](docs/roadmap.md). Recording is slice 2. Tab creation/correction prototypes precede the real tab editor. Full ChordPro file interchange, transpose, capo, section labels and the rest of V1 are still pending. Candidate/analysis tables are inert schema allowances, not ML features. No staff authoring, scraping, cloud ML, social features or practice analytics are included.
