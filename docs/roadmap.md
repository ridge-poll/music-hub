# Delivery sequence

## Current stage: Stage 5 — persistent free-form tab grid

Status: Stage 5 implemented; automated checks passed; ready for iPhone acceptance. Following hands-on Stage 4 testing, the user chose a much simpler spreadsheet-style text grid instead of specialized fret/string entry. This is the accepted interaction direction; no additional prototype-selection gate remains.

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

The fretboard, fret-first keypad, active-string keypad and thumbwheel prototypes were tested by the user on iPhone. Their qualitative finding was that specialized input added unnecessary complexity. The chosen direction is ordinary editable text cells. No quantitative scores or ranking are inferred. Tab lab has been removed from app navigation; its source and [study guide](tab-lab.md) remain historical prototypes, separate from production storage.

## Stage 5 — current: persistent free-form tab editor

- Open **Tab** from a song. The tab belongs to that song's hidden arrangement, stored independently of the chord/lyric sheet.
- Start with one block of six string rows and 12 columns. Each cell is an ordinary free-form text field: no fret, technique or notation validation, and no interpretation. Preserve text exactly, including spaces, punctuation, Unicode and pasted line breaks.
- Normal keyboard entry, direct cell taps, next/previous and up/down controls, keyboard Next, and horizontal scrolling. Moving cells transfers focus without intentionally dismissing the keyboard; Done dismisses it.
- Add another six-row/12-column block as the tab grows. Blocks are consecutive display chunks of one tab, not musical sections.
- Columns have stable client UUIDs and explicit array order across all blocks. No beats, durations or rhythmic meaning are assigned. Future timing/audio associations can reference a column without reinterpreting current text.
- Local debounced autosave, explicit Save, save-before-navigation, monotonic document revisions and stale/deleted-parent protection. No saved-version history is reintroduced.
- Swipe-delete refinement: the red region extends behind the moving rounded card so the revealed area stays continuously red.

## Next

1. Validate Stage 5 on iPhone: arbitrary text, keyboard-preserving navigation, additional blocks, local save/reopen and song isolation. Check swipe reveal continuity.
2. Refine the grid only from actual usage; do not reintroduce specialized fret/keypad entry or musical parsing without a new decision.
3. Remaining V1 work: metronome, A/B loops, derived-asset trim/waveform, simple notes and file interchange. Priorities beyond Stage 5 remain to be chosen.

Full ChordPro/file interchange, transpose/capo, tags/folders, sync/backup and the remaining V1 scope are not complete.

## Later DSP tools — room-acoustics profiling (idea only)

Explore phone-based characterization of the surrounding acoustic environment, potentially by playing a known swept-sine/chirp excitation and recording the response to estimate a room impulse response. A musician-facing view could expose reverberation/decay time, frequency-dependent decay and prominent resonances/room modes, with raw impulse response and spectrum in an expandable technical view.

This is firmly later-roadmap research: no excitation playback, response capture, deconvolution, measurement claims or UI are implemented now. Future feasibility work must distinguish room behavior from the phone speaker/microphone response and assess repeatability before presenting measurements.

## Product boundaries

Guitar-first; six-string configurable tuning. All deterministic DSP stays on-device. Backend deferred until remote access/sync requires it; later neural workloads are async jobs with candidate results and explicit promotion. Audio is only recorded or explicitly imported by the user. No lookup/scraping, staff authoring, ML, source separation, fingering optimization, multi-instrument generalization, analytics, social/sharing, GP export or ChordPro synchronized playback.
