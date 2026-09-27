# Rhythm

Open **More → Rhythm**. Add a row, choose Click/Kick/Snare/Hi-hat, and divide its full-cycle block. Tap a block to cycle rest → hit → accent; hold to select without changing its hit. Divide opens a 1–16 Cupertino wheel with preview, Cancel and Divide. Merge collapses the selected block’s sibling group. Undo/Redo retains up to 40 edits during the editor session.

## Model

Each row owns an immutable subdivision tree. The root spans the same normalized cycle for every row. A divided node has 2–16 equally sized children; leaves store only rest/hit/accent. Divide into 1 changes nothing. Dividing keeps the old hit on the first child, with other children resting. Merge replaces the whole parent subtree with one leaf retaining the first leaf’s hit; Undo can restore the complete structure.

A root divided into four, with its third child divided into three, yields lengths 1/4, 1/4, 1/12, 1/12, 1/12, 1/4. Reduced BigInt fractions retain exact positions through nesting. Rows never share a global snap grid. Defensive limits are eight rows, 256 leaves per row and nesting depth eight.

Block widths express duration. Nested divisions focus the selected branch so its children remain reachable; Focus block and Whole cycle navigate this view. The underlying timing never changes with focus. Mathematical values are not exposed in the editor.

## Playback

BPM ranges from 40–240, with tap tempo. Pulses per cycle ranges from 1–16; defaults are 100 BPM and four pulses. Cycle duration is pulses × 60/BPM. Pulse count sets duration, not the subdivision structure or a required time signature.

All rows mix into one deterministic 22,050 Hz mono PCM buffer, rendered in an isolate and looped by one native audio player. Exact fractional positions round once to the nearest sample within the common cycle. The buffer contains whole cycles totaling at least two seconds; sound tails wrap periodically across its boundary. Four small synthesized voices and bounded soft limiting keep simultaneous events manageable. There are no per-row timer clocks or LCM-sized event grids.

The playhead is approximate visual feedback from native playback position. Physical latency and loop continuity still need device testing. Committed edits while playing restart the cycle; wheel previews do not. BPM slider changes commit on release. Stop, screen exit, backgrounding and audio interruptions stop playback without automatic resumption. Generation checks prevent stale preparation from restarting audio after Stop.

## Persistence and backup

One local workspace is stored under the `rhythm` settings key as format-version-1 JSON: BPM, pulse count, stable row UUIDs, sounds and complete subdivision trees. It is separate from Song documents and does not affect Song recency. No SQLite schema change is needed.

Autosaves are serialized. A failed save retains edits and exposes Retry; Back waits for saving and refuses to discard failed edits. Corrupt stored state is not overwritten with defaults. Undo history is in memory only.

Portable backups include and validate the optional Rhythm preference. Earlier backups without it remain supported. Earlier app versions that do not recognize the preference reject those newer backups rather than silently dropping it; the ZIP format remains version 1.

## Acceptance

Automated coverage is documented in [verification](verification.md). Use the [iPhone checklist](iphone-checklist.md) for several-minute simultaneous polyrhythms, loop boundaries, wheel/haptics, nested editing, audio interruptions and persistence. Existing V1 Files/backup acceptance checks remain outstanding. Stop for this validation before adding more features.
