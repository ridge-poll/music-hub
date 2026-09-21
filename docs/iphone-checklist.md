# Version 0.2 iPhone acceptance session

Rebuild with `flutter pub get` then `flutter run -d <device-id>`. Install over the existing app. Native plugin additions cannot be tested with hot reload alone.

## Sheet editing

1. Open a song saved in 0.1. Verify all lyrics and chords survived; older chords become `{Chord}` markers at their original lyric anchors. Verify the history action is absent after upgrading to 0.3.
2. Paste a complete multiline sheet, including `[Intro]`, aligned spaces, blank lines, `{Am}`, ordinary `C/G`, emoji and unfinished braces. Edit anywhere, select across lines, copy/paste and undo/redo.
3. Save, leave, reopen, then relaunch in airplane mode. Confirm the full text is unchanged. Long lines should scroll sideways without rewriting spaces.
4. Enter performance mode. Confirm the sheet is visible, `{Am}` has a rounded label and ordinary text stays plain. Check larger/smaller text, horizontal scrolling of wide lines, manual/automatic vertical scrolling and screen-awake.
5. Test keyboard reachability, rotation and larger accessibility text.

## Recording and playback

1. Fresh permission state: opening the library must not request microphone access. Tap Record; deny permission and verify a clear explanation/retry path and no empty recording. Enable microphone access in Settings and retry.
2. Capture 20–30 seconds of guitar. Verify the input meter reacts to actual sound. Pause/resume, stop, name and save. The app should show Recordings after saving from the main screen.
3. Play, pause, seek, replay ten seconds and repeat the whole take. At the end, one tap on Play should restart it. Listen for correct speed and useful capture quality.
4. Attach the take to an existing song. Verify it appears in that song's Recordings screen. Reattach it elsewhere and then detach it; it should remain one recording with unchanged audio.
5. Start another recording and background/lock the phone. It should stop and remain as a draft. Return, save it, then relaunch offline and verify playback.
6. Interrupt a capture with Siri/a phone call, then explicitly resume or stop. Test speaker, wired and Bluetooth routes; disconnect headphones during playback and capture. These native behaviors are not certified by mocked tests.
7. Keep a draft for later, reopen it from the recovery card, and save. Separately discard a disposable draft after the confirmation prompt.
8. Test a several-minute capture and low-storage/error behavior. A failed save must retain recoverable captured bytes; a force-killed M4A may be incomplete and should not be represented as a valid playable recording.

Trim, A/B region loops, waveform display, external audio import and background capture are not part of this update. Whole-recording repeat is available. Do not uninstall the app as a recovery step: its library is currently device-local.

## Stage 3 acceptance — 0.3

Stage 2: user-confirmed working on iPhone on 20 September 2026.

- Upgrade over the installed app: current songs/recordings remain; saved history button is gone.
- Swipe left on a song and a recording. Trash appears on the right. Cancel preserves the item; confirm removes it. Repeat using each detail screen's bottom Delete action.
- Delete a song with recordings: recordings remain in the main list as unattached ideas.
- Tap Tuner from the main navigation: note/cents responds to single guitar strings; compare all six strings against a trusted tuner. Silence should clear the note instead of freezing the last reading.
- Select a string manually; test sharp/flat/in-tune indications. Try Drop D and a custom tuning; close/reopen to verify persistence.
- Expand Audio details: frequency, confidence and spectrum reflect microphone input. Harmonic guides are calculated multiples, not measured harmonic detections.
- Deny microphone access, retry after allowing it. Background, return, restart; interrupt with a call or another audio app. Confirm the microphone indicator stops on exit.
- Switch tuner → recorder → playback → tuner; verify there is no microphone/audio-session contention. Test Bluetooth route changes separately.
- Check low-string stability, noisy rooms and latency. Do not infer real-instrument accuracy from synthetic-tone tests alone.


## Stage 3 refinements + Stage 4 — 0.4

- Confirm the tuner scale shows −200 to +200 cents. Manually select a string and detune across that range; readouts beyond it remain numeric while the marker reaches the edge.
- Check the headstock: top D/G, middle A/B, bottom low E/high E for standard tuning. Circles show names only; tuning settings still show string numbers/octaves.
- Pluck and let each string decay in quiet and ordinary background noise. Brief noise/harmonics should not steal the lock. “Holding last pitch” should clear after loss of a reliable signal. Then deliberately play another string, both loudly and softly, checking acquisition delay.
- Compare against a trusted tuner. Temporal thresholds are initial tested defaults, not proof of real-room or commercial-tuner performance.
- Inspect saved song and recording cards at rest: no red corners/gaps. Swipe open, cancel/confirm deletion, then verify closed clipping again.
- Open Tab lab. Practice all four variants, then run both creation and correction for each; follow [the comparison guide](tab-lab.md).
- Check Move, delete, insertion, re-fretting, chord stacking, undo/redo, background pause and the final feedback form. Copy the session results before leaving. No prototype content should appear in saved songs.
