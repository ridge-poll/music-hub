# Delivery sequence

## Current stage: Stage 3 — tuner and basic on-device DSP

Status: implemented; automated verification complete; awaiting iPhone acceptance. Stage 2 is validated on the user's actual iPhone (20 September 2026). Stage 3 needs its own hands-on acceptance session; Stage 2 validation does not certify the new PCM stream/DSP path.

## Stage 1 — complete: chords → local save → reopen → performance

- One continuous plain-text editor, paste/select/undo/redo, optional `{Chord}` styling, preserved spaces and section labels.
- Local SQLite autosave, explicit Save, legacy document conversion and one-tap performance mode with font sizing, scrolling and keep-awake.
- Saved-version/history UI and storage removed at the user's request in 0.3. Migration drops old versions and reclaims database space; current songs remain. Unsaved stale edits are rejected in place rather than overwriting current content.
- Confirmed deletion from swipe-revealed trash buttons and detail screens. Ordered tombstones prevent resurrection. Deleting a song leaves its recordings unattached; deleting a recording hides it without breaking shared immutable audio assets.

## Stage 2 — complete and iPhone-validated: record → save → playback

One-tap recording, live input level, pause/resume/stop, durable unfinished-take drafts, immutable content-addressed audio, playback/seek/whole-take repeat and song attachment rows. The user reports the phone workflow works well. Unfinished audio drafts remain as protection for interrupted captures; these are not saved song versions.

## Stage 3 — current: tuner and basic DSP

- One-tap Tuner from primary navigation; microphone use only while the tuner is active.
- PCM16 microphone stream, local isolate-based YIN pitch detection and Hann-windowed FFT.
- Minimal note/cents indicator; automatic closest-string target or explicit string selection.
- Standard/Drop D presets and persistent custom six-string tuning; A4 = 440 Hz.
- Expandable frequency, periodicity confidence, input level and live spectrum. Harmonic guides are labeled multiples of the fundamental, not independently identified partials.
- Silence/noise gating; background/interruption stops listening, with explicit restart.
- Automated synthetic-tone accuracy, FFT, storage migration/deletion and UI tests. Physical iPhone tuner accuracy, route changes and interruption checks remain next.

## Next

1. Validate Stage 3 on iPhone against a trusted tuner, across standard/Drop D/custom tuning and quiet/noisy input; check tuner ↔ recording handoff, permissions and interruptions.
2. Stage 4: basic metronome (BPM, tap tempo, time signature, accents), after tuner acceptance.
3. Follow-up recording utility: A/B region loops, derived-asset trim and waveform. Simple notes and file interchange remain later V1 work.
4. Run the required throwaway tab-entry/correction study before any production tab editor.

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
