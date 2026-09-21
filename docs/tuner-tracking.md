# Tuner tracking in 0.4

The existing per-window YIN estimate remains the detector. This release adds a deterministic temporal tracker in `lib/pitch_tracker.dart`; no neural processing or network is involved. YIN's baseline is described in [de Cheveigné and Kawahara's paper](https://pubmed.ncbi.nlm.nih.gov/12002874/). The temporal rules below are app-specific engineering choices, not claims made by that paper.

- Mono PCM windows remain 4096 samples. Retaining 3072 samples between analyses gives a nominal 1024-sample hop (about 46 ms at 22.05 kHz). Analysis stays in an isolate; if it is busy, the buffer keeps the newest window rather than accumulating a processing backlog.
- New pitches need two nearby, high-confidence estimates. Acquisition uses periodicity confidence ≥0.94 plus a signal-level gate. Continuation within 90 cents accepts confidence ≥0.84 and a lower level threshold.
- Median-of-three filtering followed by log-frequency smoothing damps jitter without quantizing to semitones. A gradually tuned string can move across the full visible range.
- An adaptive bounded noise-floor estimate is updated only from low-confidence frames. It raises the level gate in noise without letting one loud transient suppress subsequent notes indefinitely.
- A candidate must remain within 45 cents across consecutive accepted frames. A gap over 250 ms restarts its evidence count.
- Approximate octave/third-harmonic jumps require five confirmations unless there is a clear amplitude rise. Quiet jumps relative to the recent note do not immediately steal the lock.
- Rejected frames briefly retain the last pitch with a visible **Holding last pitch…** message. With a continuing microphone stream, it clears after 650 ms without accepted evidence. A background/interruption stops and clears tracking.
- Automatic target selection has an 80-cent hysteresis margin. Manual string selection fixes the target. These are target choices; the measured pitch is not snapped to the target.

The visible scale spans ±200 cents. Numeric cents remain unbounded; the marker clamps at the scale ends. The two headstock columns are D/A/low-E on the left, G/B/high-E on the right in standard tuning. Custom note names use the same physical string locations. Only the circular labels omit octave/string numbers.

Tests cover jitter, gradual tuning, transient unrelated pitches, decaying harmonics, explicit octave changes, timeout, target-boundary hysteresis, and PCM synthetic guitar decay with seeded noise. These do not establish parity with GuitarTuna or certify every real guitar, room or input route. Next tuning decisions should follow actual iPhone comparisons, particularly soft new plucks after a loud prior string.
