# Music Hub roadmap

## Current focus: Circle of Fifths playback repair + simpler layout (1.2.1) — awaiting iPhone testing

**Implemented; stop here for testing.** On 14 November the user validated the startup-theme and Performance Mode touch/auto-scroll fixes on iPhone. Circle playback failed in 1.2.0; the failure is reproduced and repaired in 1.2.1. Outstanding Files/backup checks remain separate.

- **Fixed screen:** the wheel is centered in the available screen, with octave down/up, Play and Stop along the bottom. No vertical scrolling, chord-name dropdown or explanatory panels. Layout adapts to small phones and landscape.
- **Playback repair:** the isolate renderer now receives only chord data, rather than accidentally capturing the audio controller and its unsendable futures. A transport regression reproduces the previous failure and verifies actual isolate rendering, WAV loading, cached replay and Stop during preparation.
- **More → Circle of Fifths:** playable major/relative-minor rings, key signatures, tonic/neighbor harmonic highlighting and Roman numerals. Center shows the selected chord and root register (such as C4). Tap plays a short synthesized triad; drag scrubs across chords.
- **One octave per revolution**, explicitly chosen by the user. Clockwise turns raise the register and counterclockwise turns lower it. Independent turn tracking crosses the seam continuously, with root octaves 2–6 and bounded endpoints. Taps choose a chord in the current octave; octave buttons also support direct adjustment. This is fifths-order pitch classes within a register, not a seven-semitone ascent at each step.
- Audio is generated locally, with a short envelope, cached temporary WAVs and latest-selection coalescing. Stop, backgrounding, interruptions and exit cancel playback. No new dependency, network source or library schema.
- Startup reads the stored theme before rendering the library and disables theme interpolation. Dark is the default when no preference exists; native launch and loading backgrounds are dark. A saved Light preference still opens the library in Light mode (the native launch placeholder is intentionally dark).
- Performance Mode auto-scroll pauses while a finger is touching the sheet, lets manual scrolling take over, and resumes from that position on release/cancel. Wrapping, 6–28 font range and default 12 remain unchanged.

**Validation:** all **140 tests pass** (95 pure Dart + 45 Flutter), and Flutter analyzer reports no issues. Previously blocked UI tests now run. The old theme workflow test was updated to exercise both Light and Dark from the new dark default. Phone-sized widget previews and fixed-layout checks cover portrait and landscape. See [verification](verification.md). Still test audible chord playback, scrubbing latency, Stop and the centered layout on the iPhone.

Existing device validation: tuner, conventional metronome, recording/playback, A/B playback, import, tab editor and Performance Mode wrapping. Outstanding Stage 8 acceptance remains text/audio export, backup creation/restore, iCloud Files behavior and longer recordings. See [iPhone checklist](iphone-checklist.md).

## Rhythm — recursive subdivision tool implemented

- **More → Rhythm** opens one locally saved pattern, separate from the conventional metronome. Bottom navigation stays Songs | Recordings | Tuner | More. No Song arrangement timeline or multi-pattern library is added.
- Every row begins as one full-cycle block. Its immutable tree stores equal child divisions (2–16 children); **Divide into 1 is a no-op**. Leaf state is rest/hit/accent. Exact rational start/duration comes from the parent chain, never a global snap grid or an LCM-sized array.
- Tap cycles · rest → ○ hit → ● accent. Hold selects without changing the hit. Selected controls offer Divide and sibling-group Merge; Undo/Redo covers structural edits, hits and row removal within this editor session.
- Divide uses a Cupertino number wheel with every integer 1–16, native iOS selection feedback, preview and Cancel/Divide. Preview changes neither storage nor playback until committed.
- Dividing retains the first hit and leaves new siblings off. Merge replaces the parent’s entire sibling/subtree group with one block retaining its first leaf’s hit. Undo restores the previous structure. Nested divisions open a labeled Focused block view; Whole cycle returns to the overview. Focus block makes narrow branches editable without a giant global grid.
- Each row chooses Click, Kick, Snare or Hi-hat. Sounds are small deterministic synthesized voices, not imported samples or drum kits.
- BPM 40–240, tap tempo, Play/Stop and 1–16 **pulses per cycle**. Cycle duration is pulse count × 60/BPM; subdivision is independent of pulse count and time signature. Four pulses is only a convenient default, not a 4/4 model constraint.
- Every row is mixed into a single mono PCM loop in an isolate. Exact fractional onsets are rounded once to the nearest sample in the common cycle; native looping uses one clock for simultaneous polyrhythms. UI timers do not trigger sounds. Committed edits during playback restart at the beginning; preview does not restart playback.
- Saved state includes tempo, pulse count, row IDs/sounds and the complete subdivision trees. Serialized autosaves preserve ordering; failed writes keep edits visible and Back retries rather than discarding them. Corrupt saved state is not silently replaced with defaults. Backup/restore includes the Rhythm workspace and validates it before commit.
- Defensive bounds: eight rows, 256 leaf blocks per row, nesting depth eight. These bound rendering/storage work; they do not quantize positions onto a shared grid. In-memory Undo/Redo is capped at 40 edits and is not saved-version history.
- Performance Mode remains **6–28, default 12, wrapping and vertical scrolling only**. Automatic BPM detection remains hidden. No tuner DSP or metronome representation changes.

**Next:** test simultaneous 3:4, 5:7 and 7:11 on iPhone, loop timing over several minutes, wheel/haptics, nested focus/merge, rapid edits/stop, interruptions and saved-state recovery. See [Rhythm details](rhythm.md), [verification](verification.md) and the [iPhone checklist](iphone-checklist.md). Stop after this implementation; no MIDI, piano roll, samples, effects, mixing console, recording into Rhythm or further integrations.

## Stage 1 — complete: chords → local save → reopen → performance

- One plain-text sheet with copy/paste, undo/redo, exact saved whitespace, optional `{Chord}` highlighting and normal local autosave.
- Performance Mode now **reflows at screen edges, scrolls vertically only, and offers sizes 6–28 (default 12)**. The authored text is unchanged; the ordinary editing view can still scroll sideways for manual alignment. Auto-scroll and screen-awake remain.
- Saved-version history and recovery UI/storage were removed at the user’s request. Stale unsaved edits are rejected in place, not used to overwrite newer content. No document history has returned.
- Swipe/detail deletion asks for confirmation and uses ordered tombstones. Song deletion deletes its documents and detaches recordings. Audio remains immutable.

## Stage 2 — complete and iPhone-validated: record → save → playback

Low-friction capture, pause/resume/stop, local save, playback/seek/back ten seconds and Song attachments. Interrupted captures retain durable unfinished-take drafts; those are not saved document versions. Saved audio is content-addressed and never edited in place.

## Stage 3 — complete and iPhone-validated: tuner

- On-device YIN pitch detection and FFT, ±200-cent display, headstock arrangement of six pitch-name circles, persistent configurable tuning and expandable technical measurements.
- Confidence/level gating, temporal smoothing, note tracking and harmonic-jump resistance remain as tested. **No DSP parameters changed in Stage 8.**
- The user reports occasional difficulty acquiring the upper three strings unless played loudly. This is a later investigation, particularly B/high E; see deferred work below.

## Stage 4 — complete: throwaway tab interaction study

The user tested fretboard, fret-first keypad, active-string keypad and thumbwheel variants on iPhone and chose a much simpler text direction. No quantitative results are inferred. Tab Lab is absent from V1 navigation; its historical prototypes and [study guide](tab-lab.md) remain separate from production storage.

## Stage 5 — complete: continuous six-string overwrite tab

- Six continuous strings, presented in 40-position screen-width blocks. Only the first block has labels/opening bars; only the final block has closing bars. Monospaced, vertical scrolling only.
- Typing replaces slots and continues on the same string in a new block. Backspace restores dashes and moves left; forward Delete restores a dash; space over a dash advances. No musical parsing, beat assignment or notation validation.
- Backspacing into a completely empty trailing six-string block collapses it. Content on any string protects the block; the first block always remains. Optional + Tab Block remains.
- Simple labeled six-row ASCII paste and copied continuation text wrap without format-specific infrastructure. No Ultimate Guitar-specific parser.
- Native tab format 4 preserves IDs, Song/arrangement ownership, exact content and annotations. Previous grid, ASCII and fixed-block migrations retain content without changing Song recency. Blank/default continuations do not create a new Song.

## Stage 6 — complete and iPhone-validated: metronome

- BPM 40–240, tap tempo, time signature, accents/muting and saved preferences.
- Native sample-positioned playback; stops on exit/background/interruption and requires explicit restart.
- **Automatic microphone BPM detection is hidden from all V1 navigation.** Physical testing found it unreliable. Experimental implementation/tests remain for later work; Stage 8 does not attempt to fix it.

## Stage 7 — complete: Song-first workflow

- Home is the compact Songs list. Logical edit order implements stable most-recently-edited sorting; `lastEdited` records the edit date. Viewing, unchanged saves and tab-format migration do not change recency.
- Each Song supports one chords/lyrics document, one tab, one notes document and any number of recordings. Any subset is valid. One populated component opens directly; multiple components open the workspace. The folder action returns direct editors to the workspace.
- + New → Chords/Lyrics / Tab / Notes is lazy. Untouched editors, whitespace-only new text and default blank tabs save nothing. The first meaningful edit creates the Song and its document atomically.
- Existing standalone notes became notes-only Songs; multiple attached notes were consolidated with text/titles retained. There is no separate top-level Notes destination.
- Bottom navigation remains **Songs | Recordings | Tuner | More**. More contains Metronome, Rhythm, Back Up Music Hub, Restore Music Hub and Settings. Dark Mode persists.
- Independent recordings remain supported. Recording or adding/importing a recording from the Song side attaches it naturally; multiple takes can belong to one Song.
- One timeline shows playback progress and two region handles. Full range plays normally; moving a boundary inward loops the selected practice region. The user has validated recording/playback/A-B interaction on iPhone.

## Stage 8 — implemented: portability + stabilization

### Export and conservative import

- Song workspace → Export Song: chords/lyrics and notes as UTF-8 plain text, tabs as ASCII text with any retained annotations. Attached audio can also be exported there. Recording playback has its own Export action.
- Audio exports retain their normal file extension and bytes. Native save dialogs allow choosing the destination in Files.
- + New → Import text / ChordPro accepts UTF-8 `.txt`, `.cho`, `.chopro`, `.pro`, `.chordpro`. A deliberately small ChordPro subset recognizes title/artist, simple inline chords and chorus delimiters; unknown directives remain literal text. Empty text imports create nothing.
- Import audio is available in Recordings and a Song’s Recordings screen. The native player checks readability/duration before an immutable copy is saved locally. Actual codec support depends on the device.
- Tab interoperability stays with existing copy/paste. **No Guitar Pro, MusicXML, Ultimate Guitar parser, or large format framework in V1.**

### Complete-library backup / restore

- More → **Back Up Music Hub** creates one `MusicHub-Backup-YYYY-MM-DD.zip` through the native Files save dialog.
- Transparent version-1 manifest, readable Song text and ordinary audio, stable Song/document/Recording IDs, created dates, lastEdited, logical edit order, tuning metadata, preferences and recording relationships. SQLite is not the backup format.
- Restore stages and validates version, paths, checksums, sizes, identities and relationships before showing replacement confirmation. All audio is installed before a single transaction replaces active library metadata. Failure before commit leaves the existing library intact.
- Restore is replacement, not merge. Back up the current library first if it should be retained. Cancel leaves it unchanged. Draft takes must be saved/discarded before backup or restore so they cannot be silently omitted.
- Backups include the complete **active saved** library, not deleted tombstones or unreferenced audio. Old audio is retained locally rather than destructively garbage-collected during restore. Details and limits: [backup format](backup-format.md).

### Hardening

- Database version 5 adds Song creation dates. Legacy dates that were never recorded remain unknown (`""`), rather than fabricated. Existing content, IDs and recency survive migration.
- Song-list component summaries use maps/sets rather than repeatedly scanning all documents for each Song. A 500-Song fixture checks ordering, snapshots and read-only metadata stability.
- Tested archive round trips into the same and a separate library, repeated restore, corruption/missing audio/broken links/unsupported versions, cancellation, forced transaction rollback, text fidelity, import failure handling and prior migrations/continuations.
- Existing autosave, stale writes, lazy creation, deletion, offline file persistence and mocked audio lifecycle tests remain in the validation suite. Native Files and upgrade validation still require the iPhone pass; no Android hardware validation is claimed.

## Explicitly deferred beyond this V1

- **Tuner high-string acquisition/sensitivity:** inspect input level, confidence, fundamental/harmonic behavior, frequency-dependent thresholds and FFT/pitch estimation using real B/high-E recordings before adjusting parameters.
- **Automatic BPM detection:** improve acquisition and reliability against actual music; keep it hidden until it earns a useful result.
- **Room acoustics experiments:** potentially play a swept sine/chirp, record the response and estimate impulse response, reverberation/decay time, frequency-dependent decay and prominent resonances/modes. Expose raw impulse response/spectrum in a technical view only if measurements are defensible. Distinguish room behavior from phone speaker/microphone response and establish repeatability first.
- Deeper DSP tools, transcription and expensive audio analysis. Later neural work uses asynchronous jobs and separate candidates with explicit promotion to authored content.
- Nonessential items from the original outline—trim/derived-audio editing, waveform tools, transpose/capo UI, tags/folders, sync/backend, broader interchange—are deferred, not implied complete by the V1 label.

No additional integrations, social features, speculative abstractions or new feature stage are started in this pass. Audio is only recorded or explicitly imported by the user; no lookup or scraping.
