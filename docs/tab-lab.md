> Current Stage 5 refinement: the production editor is fixed-width ASCII with overwrite behavior. This study remains historical.

# Stage 4: archived iPhone tab-entry comparison

Stage 4 is complete. The user tested the variants and selected a simpler free-form text grid for Stage 5. Tab lab is no longer in app navigation. The instructions below document the historical prototypes, not the current editor.

Open **Tab lab** from primary navigation. These are four disposable prototypes, not four persistent editors. The lab never writes a Song, Arrangement or TabDocument. Trial results remain in memory only while the lab is open: use **Copy session results** and paste them into a note before leaving.

## Run a comparison

1. Spend a minute in Practice for each variant. Practice results are labeled separately.
2. Rotate the trial order between sessions to reduce learning/order effects. The menu supports starting with A, B1, B2 or C; it does not force a winner or sequence.
3. For each variant, run **Create riff** and **Fix 10 errors** separately. Read the reference before starting the timer.
4. Try one-handed use deliberately. On Finish, rate frustration, looking between tab/controls, one-handed usability, and optionally report mistakes and comments. Unanswered ratings remain unset.
5. Copy the results before closing the lab. Compare creation and correction independently; neither time alone nor the combined average should decide the winner.

The same original 12-position riff is used in every trial. Positions indicate order, not rhythm. S1 is high E; S6 is low E. The last position is a three-note chord. Correction starts with ten listed tasks: re-fretting, moving between strings, deleting an extra note, inserting a missing note, and converting the final single note into a chord. The reference and instructions can be expanded during a trial.

## Four variants

- **A — Fretboard:** tap a string/fret intersection; horizontally scroll for frets beyond the initial viewport.
- **B1 — Fret first:** choose a fret, then tap a destination string. Each placement consumes the chosen fret; choose again for the next note.
- **B2 — Active string:** select a string once; keypad taps continue placing on it until you choose another string.
- **C — Thumbwheel:** select a string, swipe the fret wheel, and tap Place. This intentionally tests the extra confirmation step against keypad entry.

All use frets 0–12 for this comparison. All have the same tab selection, position navigation, auto-advance toggle, note/position deletion, insertion, Move, undo and redo. Creation begins with one empty position and auto-advance on. Correction begins with auto-advance off. Turn it off to stack a chord. Move selects the source note, then an empty destination cell; it does not overwrite another note.

## What gets measured

- Active elapsed time, excluding explicit pauses, background interruptions and the final feedback form. Trial time includes reference viewing and checks.
- Pointer taps and swipes in the trial body (including editor controls and reference viewing). Start, app-bar Finish and feedback controls are excluded. A pointer moving over 12 logical pixels counts as a swipe, not a tap. These are interaction counts, not inferred musical intent.
- Undo presses, reference checks, and interruptions.
- Remaining note differences against the reference. This is **not** an estimate of how many mistakes were made: a moved note can contribute two differences, and an error already corrected is absent. Optional self-reported mistake count captures a different observation.
- Frustration (1–7), self-reported gaze-switch frequency, one-handed usability and comments. No eye tracking or fabricated telemetry.

A trial may be finished incomplete and remains labeled with its differences. Inspect comments alongside metrics. Results are copied as JSON; no account, backend, analytics or production tab schema is involved.

## Stage 5 gate

No production interaction is selected. After actual iPhone trials, choose a variant (or a justified combination) from the creation **and** correction findings. Then design the persistent tab document and real editor. Metronome work is deferred from Stage 4 under the updated sequence.
