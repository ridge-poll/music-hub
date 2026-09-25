# Delivery sequence

## Current stage: Stage 7 — musician workflow

Status: **Stage 7 workflow simplification with continuous-tab refinement (0.7.2) is implemented and awaiting iPhone testing.** Songs are now the home and organizational object. Stage 5 fixed-width tabs and Stage 6 on-device BPM estimation remain in place. No Stage 8 features are being added until the user tests this revision and decides the next scope.

## Stage 1 — complete: chords → local save → reopen → performance

- One continuous plain-text editor, paste/select/undo/redo, optional `{Chord}` styling, preserved spaces and section labels.
- Local SQLite autosave, explicit Save, legacy document conversion and one-tap performance mode with font sizing, scrolling and keep-awake.
- Saved-version/history UI and storage removed at the user's request in 0.3. Migration drops old versions and reclaims database space; current songs remain. Unsaved stale edits are rejected in place rather than overwriting current content.
- Confirmed deletion from swipe-revealed trash buttons and detail screens. Ordered tombstones prevent resurrection. Deleting a song leaves its recordings unattached; deleting a recording hides it without breaking shared immutable audio assets.

## Stage 2 — complete and iPhone-validated: record → save → playback

One-tap recording, live input level, pause/resume/stop, durable unfinished-take drafts, immutable content-addressed audio, playback/seek and song attachment rows. The user reports the phone workflow works well. Unfinished audio drafts remain as protection for interrupted captures; these are not saved song versions.

## Stage 3 — iPhone-tested; tuner refinements implemented

- One-tap Tuner from primary navigation; microphone use only while the tuner is active.
- PCM16 microphone stream, local isolate-based YIN pitch detection and Hann-windowed FFT.
- Visible ±200-cent scale. Six pitch-name-only circular controls in two headstock columns; numeric string/octave labels remain elsewhere.
- Temporal confidence/level gating, short evidence confirmation, median/log smoothing, target hysteresis, and stronger requirements for decay/harmonic jumps. A held estimate is labeled and expires after 650 ms without fresh reliable pitch.
- Standard/Drop D presets and persistent custom six-string tuning; A4 = 440 Hz.
- Expandable frequency, periodicity confidence, input level and live spectrum. Harmonic guides are labeled multiples of the fundamental, not independently identified partials.
- Silence/noise gating; background/interruption stops listening, with explicit restart.
- Synthetic-tone, decaying/noisy-signal, lock/switch behavior, FFT and UI checks. Refined tracking still needs real-guitar comparison; no claim of parity with commercial tuners.
- Swipe backgrounds now appear only while revealed and share the card clipping boundary; recording spacing is outside that boundary.

## Stage 4 — complete: interaction study and user decision

The fretboard, fret-first keypad, active-string keypad and thumbwheel prototypes were tested by the user on iPhone. Their qualitative finding was that specialized input added unnecessary complexity. The initial choice was ordinary editable text cells; the final Stage 5 revision simplifies this further to one plain-text ASCII document. No quantitative scores or ranking are inferred. Tab lab has been removed from app navigation; its source and [study guide](tab-lab.md) remain historical prototypes, separate from production storage.

## Stage 5 — refined: continuous six-string tab, fixed-width overwrite

- One continuous six-string document displayed in 40-position chunks. The first block shows string labels/opening bars; subsequent blocks are unlabeled continuations. Only the final block has closing bars. Monospaced, fitted to the screen, vertical scrolling only.
- Typing overwrites slots. At a string’s end, another six-row continuation is created automatically and the caret continues on **that same string**, with closing bars moved to the new final block. No beats, rhythm or musical interpretation.
- Backspace restores dashes and moves left along the same string, including across visual boundaries. Forward Delete restores a dash in place. Space over a dash advances without changing it. Selection deletion preserves the structure.
- Backspacing in a completely empty trailing block collapses it, placing the caret at the prior block’s end and restoring its closing bars. A block containing anything on any of its six strings is retained. The first block always exists. + Tab Block remains as an optional manual action.
- Long plain text wraps along its current string. Simple complete six-row labeled ASCII paste is supported, retaining characters and padding short rows with dashes. Copying the app’s rendered continuation text also works. No general-purpose tab/notation parser is added.
- Native format 4 preserves song/arrangement ownership, autosave, revisions and annotations. Existing format-3 fixed blocks join into continuous strings without losing slots; earlier grid/ASCII migrations still preserve annotations. Format conversion does not update Song lastEdited. Empty/default continuations still do not create a new Song.
- Actual iPhone keyboard, caret scrolling, paste and collapse behavior require acceptance; widget tests cover the editing rules and narrow-screen rendering.

## Stage 6 — iPhone-validated metronome; BPM listening added

- BPM 40–240, tap tempo, 1–12 beats per bar, denominator 2/4/8 and normal/accented/silent beats. Local settings persist.
- Sample-positioned native audio loop; changes restart on beat one. BPM counts the displayed note unit. Foreground-only playback stops on exit/background/interruption and requires explicit restart.
- **Listen for BPM** stops metronome playback, captures 12 seconds of microphone PCM, then analyzes entirely on-device in an isolate. It uses energy-rise onsets and normalized autocorrelation, not ML or network services.
- Offers a candidate tempo and valid half/double choices. Nothing changes until **Use … BPM** is tapped; applying does not start playback. Weak/nonperiodic input shows no estimate. Audio is temporary in memory and is not saved.
- Capture stops on cancellation, exit, background or interruption. A capture timeout prevents indefinite listening. This is a simple pulse estimator: mixed music, syncopation and changing tempo can yield ambiguous/wrong estimates. Real music/device validation remains pending.

## Stage 7 — current: Song-first musician’s notepad

Completed in this revision:

- **Songs is home.** Compact horizontal cards show title and populated components, sorted by most recent actual edit. Song metadata stores `lastEdited`; the persisted logical edit counter provides stable ordering without trusting wall-clock time. Opening a Song, viewing documents, saving identical content or converting a stored tab format does not mark it edited.
- A Song has one chords/lyrics document, one ASCII tab, one notes document and zero or more recordings. Any subset is valid. A single populated component opens directly; multiple components open a minimal workspace. The folder button in a direct editor opens the workspace to add other components. Performance mode remains one tap from a populated chord sheet or workspace.
- **+ New → Chords/Lyrics / Tab / Notes.** Editors begin in memory. No Song is saved for an untouched visit, whitespace-only new text, or default blank tab blocks. A meaningful document or title edit creates the Song and its first document atomically. Autosave and explicit Save remain.
- Existing standalone notes migrate to notes-only Songs, keeping their titles and exact bodies. Multiple notes already attached to a Song are combined into its one notes document with every old title/body retained. Migration does not invent edit timestamps. Song deletion now deletes its notes along with chords/tabs; recordings remain independently available. Confirmed swipe/detail deletion remains.
- Bottom navigation: **Songs | Recordings | Tuner | More**. More contains Metronome and Settings. Dark Mode is saved locally. Notes is no longer a separate destination. Promotional/dashboard prompts and recording-to-note/tab shortcuts are removed.
- Independent recording remains under Recordings. From a Song’s Recordings screen, record a new take or use **+** to add an existing unattached recording. A Song supports multiple takes. Playback retains play/pause, seek, back ten seconds, attachment and confirmed deletion.
- One playback timeline shows played/unplayed portions, the playhead and two thin region boundaries. Full-width boundaries mean normal playback. Dragging either boundary inward immediately selects a repeating practice region; returning both to the edges restores normal playback. Native clip/repeat, minimum 200 ms, session-local bounds and immutable original audio remain. There are no Set A/Set B, Apply Loop, Clear Loop or separate whole-take-repeat controls.
- Interrupted audio capture still keeps an unfinished take for recovery. No document history has returned.

Pending: actual iPhone acceptance of the revised home/creation workflow, note migration, Dark Mode, and boundary-handle interaction/native looping. Automated checks are recorded in [verification](verification.md).

## Stage 8 — deferred until iPhone feedback: import/export and V1 cleanup/stabilization

After Stage 7 iPhone acceptance, plan two distinct features:

- **Backup** lives under **More**. It creates a **single restorable ZIP** of the complete library through the normal iOS **Files** interface. The restore path must preserve all Song documents, metadata, recording relationships and audio assets. This is full-library preservation/restoration, not individual content export.
- **Export** gets individual human-readable Song/audio content out of Music Hub. Keep its purpose and interface distinct from Backup. Agree on faithful interchange for free-form tabs before promising equivalence; original priorities include ChordPro import/export, Guitar Pro import and MusicXML import/view.

Neither feature is implemented in 0.7.2. Include backup/restore round trips, error handling, accessibility and Android/device audio testing in Stage 8 cleanup/stabilization planning.

Remaining original V1 items such as trim/derived-asset waveform, transpose/capo, tags/folders and offline sync are not complete and must be explicitly triaged during Stage 8 planning; this stage marker does not imply they already exist. Sync/server/ML remain deferred. No room-acoustics implementation is included.

## Next acceptance

1. Upgrade over the current app without uninstalling. Check existing chords, tabs, notes and recordings; standalone notes should now appear as Songs, and attached note text should be consolidated without loss.
2. Try all three + New paths, immediately Back, whitespace-only entry, and blank Tab Blocks. None should create an empty Song. Enter real content, save/reopen, and verify direct opening for a single component versus the overview for multiple components.
3. Confirm visiting Songs does not reorder them. Edit title/chords/tab/notes or attach a recording and verify that Song moves to the top.
4. Try Song-side recording attachment, multiple takes, play/seek/back ten seconds, and both timeline handles while paused/playing. Verify repeating bounds, full-range normal playback, and background/interruption behavior.
5. Test continuous tab growth on each string, whole-block collapse, simple ASCII paste and save/reopen on iPhone.
6. Check More → Metronome and Settings → Dark Mode, including relaunch. Give feedback before Stage 8 planning resumes.

## Later DSP tools — room-acoustics profiling (idea only)

Explore phone-based characterization of the surrounding acoustic environment, potentially by playing a known swept-sine/chirp excitation and recording the response to estimate a room impulse response. A musician-facing view could expose reverberation/decay time, frequency-dependent decay and prominent resonances/room modes, with raw impulse response and spectrum in an expandable technical view.

This is firmly later-roadmap research: no excitation playback, response capture, deconvolution, measurement claims or UI are implemented now. Future feasibility work must distinguish room behavior from the phone speaker/microphone response and assess repeatability before presenting measurements.

## Product boundaries

Guitar-first; six-string configurable tuning. All deterministic DSP stays on-device. Backend deferred until remote access/sync requires it; later neural workloads are async jobs with candidate results and explicit promotion. Audio is only recorded or explicitly imported by the user. No lookup/scraping, staff authoring, ML, source separation, fingering optimization, multi-instrument generalization, analytics, social/sharing, GP export or ChordPro synchronized playback.
