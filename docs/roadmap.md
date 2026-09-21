# Delivery sequence

## Slice 1: chords → local save → reopen → performance

- Direct library opening; create without organizing first.
- Hidden default arrangement, clean authored native chord sheet, SQLite transactions.
- One continuous plain-text editor, native selection/copy/paste and undo/redo (updated per user feedback).
- Optional `{Chord}` styling; spaces and section labels remain literal text. Legacy songs and history stay readable.
- Debounced autosave, explicit Save and save-before-navigation, visible failure state.
- Recover saved versions as separate songs.
- Performance screen in one tap; font size, manual scrolling, auto-scroll speed, keep-awake.
- Native plain text replaces the limited ChordPro copy action; full format/file interchange remains deferred.

Remaining V1 chord work: file interchange with loss reporting, transpose and capo if useful, and real-device Unicode/IME/large-text polish. Keep the requested plain-text interaction simple; do not reintroduce structured line editing. Tags/folders, standalone notes, tuner, metronome and other V1 features remain future slices. The first slice is not all of V1.

## Slice 2: record → save → playback

Implemented in 0.2: one-tap recording from the library, input metering, pause/resume/stop, durable drafts, immutable content-addressed audio, local playback/seek/repeat, and separate song attachment rows. Native interruption policy is pause/manual resume; backgrounding finalizes to a draft. Validate these behaviors on the iPhone before expanding.

Next: native audio acceptance, A/B region loops, then derived-asset trim and useful waveform rendering. No source separation or ML.

## Tab interaction gate

Build separate disposable prototypes without production data behind them:
A fretboard tap; B1 fret-first; B2 persistent active string; C swipe/thumbwheel.
Do not choose a production variant from this document. Test each in counterbalanced order with the same tasks after a short familiarization period.

1. Creation: enter the same known riff from scratch.
2. Correction: fix ten predefined mistakes covering insert, delete, move, re-fret and notes-to-chord conversion.

Record elapsed time, total taps, errors, undo count, frustration (1–7), observed keypad/tab gaze switches, one-handed completion and comments. Record correction independently and weight it as strongly as creation. Eye movements require observation/user reporting, not invented automatic telemetry. Prefer B-family for the real implementation only after examining test results. No test participants or findings exist yet.

## Product boundaries

Guitar-first; six-string configurable tuning. All deterministic DSP stays on-device. Backend deferred until remote access/sync requires it; later neural workloads are async jobs with candidate results and explicit promotion. Audio is only recorded or explicitly imported by the user. No lookup/scraping, staff authoring, ML, source separation, fingering optimization, multi-instrument generalization, analytics, social/sharing, GP export or ChordPro synchronized playback.
