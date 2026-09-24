# Delivery sequence

## Current stage: Stage 7 — musician workflow

Status: **Stage 7 workflow simplification (0.7.1) is implemented and awaiting iPhone testing.** Songs are now the home and organizational object. Stage 5 fixed-width tabs and Stage 6 on-device BPM estimation remain in place. No Stage 8 features are being added until the user tests this revision and decides the next scope.

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

## Stage 5 — refined: fixed-width, overwrite ASCII tabs

- One plain-looking monospaced editor; every string has 40 editable character positions plus protected label/borders. The same width is used across all blocks/devices; font size fits the screen (up to 13 pt). Only vertical scrolling; text scaling for this canvas is fitted rather than allowing rows to wrap.
- Typing/paste overwrites positions. Backspace restores dashes and moves left; forward Delete restores dashes in place. Space over a dash advances without changing it. Selection deletion clears positions without deleting string labels or structure.
- Entry continues through available string positions. Return moves to the next string. An entry that exceeds the remaining document capacity is rejected as a whole with a message; **+ Tab Block** adds capacity without changing existing text. No pitch, technique, rhythm or notation interpretation.
- Native format 3 retains song/arrangement identity, autosave, Save, revision checks and deletion behavior. Legacy format-1 grids and format-2 ASCII tabs migrate on opening. Long six-string rows continue into successive fixed-width blocks; text outside recognizable blocks remains verbatim in expandable **Saved annotations**. No history copies are stored.
- Test the actual iOS keyboard, selection, Unicode/composition, row boundaries and small-screen layout before considering this refinement accepted.

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

After Stage 7 iPhone acceptance, prioritize full-fidelity native backup/restore, agreed interchange scope (ChordPro import/export, Guitar Pro import, MusicXML import/view), and V1 usability/reliability cleanup. Define faithful behavior for free-form tabs before promising interchange equivalence. Include migration/backup round trips, error handling, accessibility and Android/device audio testing.

Remaining original V1 items such as trim/derived-asset waveform, transpose/capo, tags/folders and offline sync are not complete and must be explicitly triaged during Stage 8 planning; this stage marker does not imply they already exist. Sync/server/ML remain deferred. No room-acoustics implementation is included.

## Next acceptance

1. Upgrade over the current app without uninstalling. Check existing chords, tabs, notes and recordings; standalone notes should now appear as Songs, and attached note text should be consolidated without loss.
2. Try all three + New paths, immediately Back, whitespace-only entry, and blank Tab Blocks. None should create an empty Song. Enter real content, save/reopen, and verify direct opening for a single component versus the overview for multiple components.
3. Confirm visiting Songs does not reorder them. Edit title/chords/tab/notes or attach a recording and verify that Song moves to the top.
4. Try Song-side recording attachment, multiple takes, play/seek/back ten seconds, and both timeline handles while paused/playing. Verify repeating bounds, full-range normal playback, and background/interruption behavior.
5. Check More → Metronome and Settings → Dark Mode, including relaunch. Give feedback before Stage 8 planning resumes.

## Later DSP tools — room-acoustics profiling (idea only)

Explore phone-based characterization of the surrounding acoustic environment, potentially by playing a known swept-sine/chirp excitation and recording the response to estimate a room impulse response. A musician-facing view could expose reverberation/decay time, frequency-dependent decay and prominent resonances/room modes, with raw impulse response and spectrum in an expandable technical view.

This is firmly later-roadmap research: no excitation playback, response capture, deconvolution, measurement claims or UI are implemented now. Future feasibility work must distinguish room behavior from the phone speaker/microphone response and assess repeatability before presenting measurements.

## Product boundaries

Guitar-first; six-string configurable tuning. All deterministic DSP stays on-device. Backend deferred until remote access/sync requires it; later neural workloads are async jobs with candidate results and explicit promotion. Audio is only recorded or explicitly imported by the user. No lookup/scraping, staff authoring, ML, source separation, fingering optimization, multi-instrument generalization, analytics, social/sharing, GP export or ChordPro synchronized playback.
