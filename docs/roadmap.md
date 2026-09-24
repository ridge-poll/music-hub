# Delivery sequence

## Current stage: Stage 7 — musician workflow

Status: Stage 6 metronome is user-validated on iPhone. Stage 5 fixed-width overwrite refinement, Stage 6 microphone BPM estimation, and Stage 7 workflow features are implemented; 93 automated checks and static analysis pass. Their physical-device acceptance is next. Stage 8 remains import/export and V1 cleanup/stabilization.

## Stage 1 — complete: chords → local save → reopen → performance

- One continuous plain-text editor, paste/select/undo/redo, optional `{Chord}` styling, preserved spaces and section labels.
- Local SQLite autosave, explicit Save, legacy document conversion and one-tap performance mode with font sizing, scrolling and keep-awake.
- Saved-version/history UI and storage removed at the user's request in 0.3. Migration drops old versions and reclaims database space; current songs remain. Unsaved stale edits are rejected in place rather than overwriting current content.
- Confirmed deletion from swipe-revealed trash buttons and detail screens. Ordered tombstones prevent resurrection. Deleting a song leaves its recordings unattached; deleting a recording hides it without breaking shared immutable audio assets.

## Stage 2 — complete and iPhone-validated: record → save → playback

One-tap recording, live input level, pause/resume/stop, durable unfinished-take drafts, immutable content-addressed audio, playback/seek/whole-take repeat and song attachment rows. The user reports the phone workflow works well. Unfinished audio drafts remain as protection for interrupted captures; these are not saved song versions.

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

## Stage 7 — current: capture → develop → practice

- Song workspace links chords/lyrics, Tab, Notes and Recordings. Chord/tab/note content saves independently.
- **Quick idea** in the main toolbar opens a plain note immediately, without creating a song. The existing one-tap Record action captures unattached audio. **Notes** navigation collects saved notes/ideas; they can later be attached to or detached from songs.
- Free-form note title/body, local autosave, explicit Save, save-before-leaving, stale-write rejection and confirmed swipe/detail deletion. Attachments use separate ordered rows. Deleting a song leaves notes and recordings available as unattached ideas.
- Recording playback adds **Jot a note**, **Open song** and **Work on tab** (song actions appear when attached). Opening another workspace pauses playback.
- **A/B practice loop**: range handles or Set A/Set B at the playhead, explicit Loop A–B and Clear A/B. Minimum region 200 ms. Native clipping plus native repeat, without modifying the immutable original. Seek/time labels stay in original recording coordinates. Range selection is session-local; it does not create a derived audio asset.
- Whole-recording repeat remains available outside A/B mode. Backgrounding pauses playback. Compact playback artwork leaves room for practice controls.

## Stage 8 — next: import/export and V1 cleanup/stabilization

After Stage 7 iPhone acceptance, prioritize full-fidelity native backup/restore, agreed interchange scope (ChordPro import/export, Guitar Pro import, MusicXML import/view), and V1 usability/reliability cleanup. Define faithful behavior for free-form tabs before promising interchange equivalence. Include migration/backup round trips, error handling, accessibility and Android/device audio testing.

Remaining original V1 items such as trim/derived-asset waveform, transpose/capo, tags/folders and offline sync are not complete and must be explicitly triaged during Stage 8 planning; this stage marker does not imply they already exist. Sync/server/ML remain deferred. No room-acoustics implementation is included.

## Next acceptance

1. Upgrade and verify existing tabs and annotations, overwrite/backspace/space/Delete behavior, no wrapping, added blocks and local reopen on iPhone.
2. Try BPM listening with clear beats, ordinary songs, silence and noisy/ambiguous passages; check explicit application and microphone release.
3. Capture an unattached note/audio idea, attach it to a song, work between song surfaces, and practice a short A/B loop. Check loop bounds, repeated audio, navigation, backgrounding and deletion.
4. Proceed to Stage 8 after feedback on these workflows.

## Later DSP tools — room-acoustics profiling (idea only)

Explore phone-based characterization of the surrounding acoustic environment, potentially by playing a known swept-sine/chirp excitation and recording the response to estimate a room impulse response. A musician-facing view could expose reverberation/decay time, frequency-dependent decay and prominent resonances/room modes, with raw impulse response and spectrum in an expandable technical view.

This is firmly later-roadmap research: no excitation playback, response capture, deconvolution, measurement claims or UI are implemented now. Future feasibility work must distinguish room behavior from the phone speaker/microphone response and assess repeatability before presenting measurements.

## Product boundaries

Guitar-first; six-string configurable tuning. All deterministic DSP stays on-device. Backend deferred until remote access/sync requires it; later neural workloads are async jobs with candidate results and explicit promotion. Audio is only recorded or explicitly imported by the user. No lookup/scraping, staff authoring, ML, source separation, fingering optimization, multi-instrument generalization, analytics, social/sharing, GP export or ChordPro synchronized playback.
