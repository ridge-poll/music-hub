# V1 / Stage 8 iPhone acceptance

The user has already validated tuner, normal metronome, recording/playback and A/B region interaction. Do not retune DSP during this pass. Automatic microphone BPM detection is intentionally absent. This checklist focuses on the new finishing changes.

Rebuild with `flutter pub get` and `flutter run -d <device-id>`; native file-dialog plugins require a full rebuild, not hot reload. Install over the existing app without uninstalling. The automated environment could not finish the native build because Xcode's nested sandbox was blocked.

## New UI and portability

1. Open a long chords/lyrics sheet in Performance Mode. At small (8), default (18) and large (32) sizes, lines must reflow without horizontal scrolling. Check portrait/landscape, blank lines, `{Chord}` labels, auto-scroll, screen-awake and larger accessibility text. Saved/editor text should be unchanged.
2. More → Metronome: BPM, tap tempo, time signature, accents/muting and saved preferences remain; Listen for BPM is absent. More should also show Back Up Music Hub, Restore Music Hub and Settings. Dark Mode persists after relaunch.
3. Song → folder/workspace → Export Song: export chords, tabs, notes and an attached recording to On My iPhone and iCloud Drive. Open the text in another app, confirming spaces, Unicode, tab alignment and saved annotations. Play the exported audio. Independent recordings export from their playback screen.
4. Cancel a Files save and ensure it reports cancellation, not success. Check an unavailable iCloud destination or storage error leaves local content intact.
5. + New → Import text / ChordPro: choose a UTF-8 `.txt` and simple `.cho`/`.chopro` file. Check title/artist, basic chords and unknown directives retained as text. Empty/cancelled/unsupported files should create nothing. Existing tab paste is sufficient; no special website parser is expected.
6. Import normal audio from Recordings and from a Song. Check common M4A/MP3/WAV files, iCloud download, cancellation and an unreadable file. Imported audio should play/seek/loop, survive relaunch and export unchanged. Song-side import should attach directly.

## Backup and restore — use a disposable test library or back up first

1. Save any unfinished takes. More → Back Up Music Hub; choose a Files location. Expect one dated ZIP. Keep a copy of this backup before testing replacement.
2. Inspect the ZIP in Files/on a computer: readable JSON/text, ordinary audio, stable IDs and the correct number of Songs/recordings. Try a library with several long recordings to check space, responsiveness and completion.
3. Add a disposable Song after the backup. Restore the ZIP: inspect the counts/date and cancel. The disposable Song and current library must remain unchanged.
4. Restore again and confirm Replace library. The disposable Song should disappear; all backed-up text, titles, dates, tuning/metronome/Dark Mode preferences and recordings should return. Check multiple recordings on one Song plus an independent recording. Relaunch offline and play the restored audio.
5. Restore the same ZIP again: no duplicates. Open Songs without changing them: order and lastEdited stay unchanged. Edit one: it moves to the top. Check tabs with continuations and retained annotations.
6. Try an invalid ZIP or a copy with a missing/changed payload. It must fail before confirmation/commit and preserve the live library. Interrupted file selection and cancellation must not modify it. Do not delete the only good backup.

## Short regression pass

- + New → each editor → immediate Back; whitespace-only text and default blank tabs should create nothing. Real edits should autosave and reopen offline.
- One populated component opens directly; multiple components open the Song workspace. Songs remain primary, recordings may remain independent.
- Swipe/detail deletion: Cancel keeps content; confirmed Song deletion removes documents and detaches recordings. Multiple recordings still attach from the Song side.
- Tab overwrite, automatic continuation on each string, full-empty-block collapse, simple ASCII paste and undo/redo retain their previous behavior.
- Briefly switch tuner → metronome → recorder → playback. Background/interruption should release capture/playback as before. Speaker/headphone/Bluetooth and Android hardware behavior are not certified by mocked tests.

No further feature stage begins after this acceptance pass. Later high-string sensitivity, BPM detection and room-acoustics ideas stay on the roadmap.
