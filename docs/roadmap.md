# Delivery sequence

## Current stage: Stage 6 — metronome

Status: final Stage 5 ASCII-text revision implemented; Stage 6 metronome implemented; automated model, storage and UI checks passed. Next acceptance is on the actual iPhone.

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

## Stage 5 — final revision: persistent ASCII tabs

- Open **Tab** from a song. One monospaced plain-text editor replaces the grid. New tabs start with the requested six-string blank ASCII block, high e to low E.
- Exact text/spacing, normal keyboard, selection and copy/paste; horizontal scrolling instead of automatic line wrapping. No parsing, validation, rhythm or specialized input controls.
- **+ Tab Block** appends another blank six-string block. Existing text is not replaced or trimmed.
- Existing format-1 grids convert to format-2 text on opening and autosave using the same document/arrangement identity and normal revision checks. Single-line cells become padded ASCII rows. Cells containing tabs or line breaks receive a labeled reference and a verbatim text entry below the blocks, preserving their complete contents. No history system or hidden grid copies are added.
- Song/arrangement ownership, local autosave, Save, save-before-navigation, stale-write protection and deletion behavior remain.
- Stable grid-column IDs are retired by this explicit text-only revision. Future audio alignment needs separate annotations; text is not interpreted as musical positions.
- Swipe-delete red reveal continuity from Stage 5 remains.

## Stage 6 — current: metronome

- One-tap Metronome from primary navigation. BPM 40–240, tap tempo, 1–12 beats per bar and denominator 2/4/8.
- Each beat cycles normal → accented → silent. Default 4/4 accents the first beat. BPM counts the displayed note unit; changing the denominator does not silently rescale tempo.
- Sample-positioned PCM clicks generated entirely on-device, played as a native looping WAV using the existing audio stack. UI refreshes do not schedule clicks. A whole-bar loop lasts approximately one minute; device acceptance must check the loop boundary.
- Start/Stop, highlighted beats and local preference persistence. Tempo/signature/accent changes restart on the first beat; no subdivisions, swing or tempo automation.
- Foreground-only playback. Backgrounding, interruption, output disconnection and leaving stop playback; restart is explicit. No microphone access or new dependencies.

## Next

1. Validate final ASCII tabs on iPhone: upgrade an existing grid, inspect all content, edit/paste, add a block, save/reopen and check horizontal scrolling.
2. Validate the metronome on speaker/headphones at slow and fast tempos, through a full loop, with signature/accent changes and interruptions. Verify switching between tuner, recorder, playback and metronome.
3. After Stage 6 acceptance, choose the next remaining V1 slice: A/B loops, derived-asset trim/waveform, simple notes or file interchange.

Full ChordPro/file interchange, transpose/capo, tags/folders, sync/backup and the remaining V1 scope are not complete.

## Later DSP tools — room-acoustics profiling (idea only)

Explore phone-based characterization of the surrounding acoustic environment, potentially by playing a known swept-sine/chirp excitation and recording the response to estimate a room impulse response. A musician-facing view could expose reverberation/decay time, frequency-dependent decay and prominent resonances/room modes, with raw impulse response and spectrum in an expandable technical view.

This is firmly later-roadmap research: no excitation playback, response capture, deconvolution, measurement claims or UI are implemented now. Future feasibility work must distinguish room behavior from the phone speaker/microphone response and assess repeatability before presenting measurements.

## Product boundaries

Guitar-first; six-string configurable tuning. All deterministic DSP stays on-device. Backend deferred until remote access/sync requires it; later neural workloads are async jobs with candidate results and explicit promotion. Audio is only recorded or explicitly imported by the user. No lookup/scraping, staff authoring, ML, source separation, fingering optimization, multi-instrument generalization, analytics, social/sharing, GP export or ChordPro synchronized playback.
