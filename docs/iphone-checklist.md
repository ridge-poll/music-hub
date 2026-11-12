# Circle of Fifths + startup/scroll acceptance — 1.2.0+12

Install a full rebuild over the existing app to refresh the native launch screen; retain the library.

- More → Circle of Fifths: tap major and relative-minor chords; check the center chord/root octave and sound. Scrub slowly and quickly through the top seam in both directions. A full clockwise turn raises one octave; reverse lowers it. Check all five root octaves, bounded endpoints, sound latency, rapid direction changes and unwanted clicks/dropouts.
- Check Stop, leaving the tool, locking/backgrounding, an audio interruption, headphones and speaker. Sound must not restart unexpectedly. Compare minor/major and the harmonic-cluster labels on the actual screen.
- Save Dark Mode, fully close/reopen: no white flash. Save Light Mode and reopen: the library must start light, following a dark launch placeholder. Recheck after an ordinary app update without uninstalling.
- Performance Mode: start auto-scroll on a long sheet, hold a finger still, drag both up and down, hold again, then release. Auto-scroll must pause throughout contact and resume at the new position. Check multiple touches, pointer cancellation, Pause and end-of-sheet behavior. Confirm vertical-only wrapping remains.
- Run the full Flutter tests on the development Mac; this environment could run the 95 pure Dart tests and analyzer but not Flutter’s cache-writing test runner.

The earlier acceptance list follows; do not interpret historical automated results as physical signoff for this update.

---

# Rhythm (1.1.0) + remaining V1 iPhone acceptance

The user has already validated tuner, normal metronome, recording/playback and A/B region interaction. Do not retune DSP during this pass. Automatic microphone BPM detection is intentionally absent. Import, the tab editor and Performance Mode wrapping/size controls were also physically validated on `ab19cbd` (26 September). Existing V1 behavior remains frozen; the requested Rhythm tool is the only new feature. Remaining handoff checks are text/audio export, backup creation, restore, iCloud Files behavior and longer-recording backups/restores.

Rebuild with `flutter pub get` and `flutter run -d <device-id>`; native file-dialog plugins require a full rebuild, not hot reload. Install over the existing app without uninstalling. The automated environment could not finish the native build because Xcode's nested sandbox was blocked.

## Rhythm — new physical validation

1. More → Rhythm. Tap the initial block on, Divide into 4, then turn on all four children. Add a row, choose a different sound, divide into 3 and enable all three. Play: both first hits should coincide at every cycle boundary. Repeat with 5:7 and 7:11.
2. Listen for several minutes at slow, medium and fast BPM. Check no drift between rows, no unintended pause at the native loop boundary, and audible distinctions between rest/hit/accent and the four sounds. Compare cycle duration against the chosen BPM/pulses. Check speaker/headphones; Bluetooth adds latency and is not certified by tests.
3. Spin the Divide wheel across all 1–16 values. Check finger targeting, subtle iOS haptics/ticks, preview and cancellation. Cancel must leave the saved pattern and current playback unchanged. Divide into 1 should change nothing.
4. Divide the third of four blocks into three. Check Focused block/Whole cycle, tap versus hold, repeated nested divisions, sibling Merge and Undo/Redo. Whole-cycle widths should show two quarters, three twelfths and a final quarter. Merge keeps the first hit; Undo restores the complete group.
5. Try 16 blocks on the narrow phone screen, landscape, larger text and Dark Mode. Check Focus block makes small branches usable. Verify no math or shared 77-step grid is exposed.
6. Change BPM/pulses/sound/hits during playback: a committed edit intentionally restarts from the beginning. Dragging the BPM slider previews its number and applies on release. Rapidly edit, Stop while preparing, leave/reopen, background/lock, interrupt with a call/Siri and disconnect headphones. Audio must stop on exit/background/interruption and require explicit Play to resume. Switch Rhythm → tuner → recorder → metronome to check session recovery.
7. Create a nested multi-row pattern, leave immediately, relaunch offline and confirm all state. Remove a row and Undo. Save errors must retain edits with Retry save. Back should not silently discard a failed save.
8. Include a Rhythm pattern when testing backup/restore below; compare sounds, hits, tree structure, tempo and pulse count afterward. Undo history and selection/focus are session-only.

Stop here after testing; send feedback before further additions.

## New UI and portability

1. Open a long chords/lyrics sheet in Performance Mode. At small (6), default (12) and large (28) sizes, lines must reflow without horizontal scrolling. Check portrait/landscape, blank lines, `{Chord}` labels, auto-scroll, screen-awake and larger accessibility text. Saved/editor text should be unchanged.
2. More → Metronome: BPM, tap tempo, time signature, accents/muting and saved preferences remain; Listen for BPM is absent. More should also show Rhythm, Back Up Music Hub, Restore Music Hub and Settings. Dark Mode persists after relaunch.
3. Song → folder/workspace → Export Song: export chords, tabs, notes and an attached recording to On My iPhone and iCloud Drive. Open the text in another app, confirming spaces, Unicode, tab alignment and saved annotations. Play the exported audio. Independent recordings export from their playback screen.
4. Cancel a Files save and ensure it reports cancellation, not success. Check an unavailable iCloud destination or storage error leaves local content intact.
5. **Import physically validated; optional regression only.** + New → Import text / ChordPro: choose a UTF-8 `.txt` and simple `.cho`/`.chopro` file. Check title/artist, basic chords and unknown directives retained as text. Empty/cancelled/unsupported files should create nothing. Existing tab paste is sufficient; no special website parser is expected.
6. **Import physically validated; iCloud behavior remains pending.** Import normal audio from Recordings and from a Song. Check common M4A/MP3/WAV files, iCloud download, cancellation and an unreadable file. Imported audio should play/seek/loop, survive relaunch and export unchanged. Song-side import should attach directly.

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
