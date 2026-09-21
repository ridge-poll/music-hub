# Delivery sequence

## Current stage: Stage 4 — tab-entry interaction prototypes

Status: Stage 4 prototypes implemented and automated checks passed; ready for iPhone comparison. Stage 3 is working on the user's iPhone; the 21 September stability, scale and headstock refinements still need hands-on comparison. Stage 4 compares interactions; Stage 5 will build the persistent editor only after the findings are reviewed.

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

## Stage 4 — current: throwaway tab-entry prototypes

Implemented in the on-device **Tab lab**: A fretboard, B1 fret-first keypad, B2 active-string keypad, C swipe/thumbwheel. Every variant has the same original reference riff and the same ten-error correction exercise, common edit/undo/redo controls, practice mode, timed trials and feedback. Results are temporary and can be copied as JSON. They never write production musical documents. See [trial instructions and metric definitions](tab-lab.md).

No human comparison results exist yet. Automated tests verify interactions, not speed, frustration, eye movement or a winning design.

## Next

1. Compare the refined tuner and swipe visuals on iPhone.
2. Run Stage 4 creation and correction trials on iPhone; rotate order, try one-handed use, and copy results before leaving the lab.
3. **Stage 5:** use those findings to choose the interaction and build the real persistent tab editor. This remains unimplemented and unselected.
4. Later V1 work: metronome, A/B loops, derived-asset trim/waveform, simple notes and file interchange. Metronome is no longer Stage 4.

Full ChordPro/file interchange, transpose/capo, tags/folders, sync/backup and the remaining V1 scope are not complete. Keep the requested plain-text interaction simple.

## Tab interaction gate

Build separate disposable prototypes without production data behind them:
A fretboard tap; B1 fret-first; B2 persistent active string; C swipe/thumbwheel.
Do not choose a production variant from this document. Test each in counterbalanced order with the same tasks after a short familiarization period.

1. Creation: enter the same known riff from scratch.
2. Correction: fix ten predefined mistakes covering insert, delete, move, re-fret and notes-to-chord conversion.

Record elapsed time, total taps, errors, undo count, frustration (1–7), observed keypad/tab gaze switches, one-handed completion and comments. Record correction independently and weight it as strongly as creation. Eye movements require observation/user reporting, not invented automatic telemetry. Prefer B-family for the real implementation only after examining test results. No test participants or findings exist yet.

## Product boundaries

Guitar-first; six-string configurable tuning. All deterministic DSP stays on-device. Backend deferred until remote access/sync requires it; later neural workloads are async jobs with candidate results and explicit promotion. Audio is only recorded or explicitly imported by the user. No lookup/scraping, staff authoring, ML, source separation, fingering optimization, multi-instrument generalization, analytics, social/sharing, GP export or ChordPro synchronized playback.
