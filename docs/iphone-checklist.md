# First iPhone acceptance session

Run a debug or release build on the phone; disconnect it and enable airplane mode.

1. Open to the song library, tap New song, enter title and lyric text.
2. Place the lyric cursor at a word and tap + Chord. Enter Am, then add C/G elsewhere. Confirm labels align above their lyric fragments.
3. Edit text before and under anchors; edit/remove a chord by tapping it.
4. Wait for “Saved on this device”. Leave, reopen and verify title, lyrics and chords.
5. Force-quit only after Saved, relaunch offline and verify again. Separately test backgrounding immediately after an edit. An OS force-kill inside the 800 ms debounce window can lose that unsaved edit; explicit Save is the checkpoint.
6. Enter performance mode with the top-right play icon. Adjust text, manually scroll, auto-scroll, change speed, pause and return to top. Confirm screen-awake beyond the device's normal auto-lock interval.
7. Rotate and test with large accessibility text, keyboard open, long lines, emoji and non-Latin lyrics. Check reachability and wrapping.
8. Edit/save a song, open History and recover an older version. Both the current and recovered song must remain.
9. Copy ChordPro and inspect it in a text editor. This initial exporter supports the entered bracket-chord/lyric subset; arbitrary directive roundtrips and full file interchange are still pending.

No microphone request should appear in this slice. Native screen-awake behavior, signing, keyboard feel and runtime integration must be verified on-device; widget tests cannot certify those.
