import 'dart:math' as math;
import 'dsp.dart';

class TrackedPitch {
  const TrackedPitch(this.frequency, {this.held = false, this.newNote = false});
  final double frequency;
  final bool held, newNote;
}

/// Deterministic temporal gate. Time is monotonic, supplied by the caller.
/// A recent estimate is a prior, never a replacement for fresh evidence.
class PitchTracker {
  double? _pitch, _candidate;
  double _level = 0, _noise = 0.001;
  int _votes = 0;
  Duration? _lastGood, _candidateAt;
  final List<double> _recent = [];

  void reset() {
    _pitch = _candidate = null;
    _lastGood = _candidateAt = null;
    _votes = 0;
    _level = 0;
    _noise = 0.001;
    _recent.clear();
  }

  TrackedPitch? update(PitchFrame frame, Duration now) {
    if (_lastGood != null &&
        now - _lastGood! > const Duration(milliseconds: 650)) {
      _pitch = null;
      _recent.clear();
    }
    final hz = frame.frequency;
    final near =
        hz != null && _pitch != null && centsFrom(hz, _pitch!).abs() < 90;
    final threshold = near ? 0.84 : 0.94;
    final gate = math.max(near ? 0.002 : 0.004, _noise * (near ? 1.4 : 2.5));
    if (hz == null ||
        !hz.isFinite ||
        hz <= 0 ||
        frame.confidence < threshold ||
        frame.rms < gate) {
      if (frame.confidence < 0.65) {
        // Bounded adaptation: a loud transient must not deafen the next note.
        _noise = (_noise * 0.95 + math.min(frame.rms, 0.02) * 0.05).clamp(
          0.0005,
          0.006,
        );
      }
      _candidate = null;
      _votes = 0;
      return _pitch == null ? null : TrackedPitch(_pitch!, held: true);
    }
    if (near) {
      _candidate = null;
      _votes = 0;
      _recent.add(hz);
      if (_recent.length > 3) _recent.removeAt(0);
      final sorted = List<double>.of(_recent)..sort();
      final median = sorted[sorted.length ~/ 2];
      // Smooth in log-frequency (cents), preserving continuous tuning movement.
      final delta = centsFrom(median, _pitch!);
      _pitch = _pitch! * math.pow(2, delta * 0.45 / 1200);
      _lastGood = now;
      _level = frame.rms;
      return TrackedPitch(_pitch!);
    }
    if (_candidate == null ||
        centsFrom(hz, _candidate!).abs() > 45 ||
        _candidateAt == null ||
        now - _candidateAt! > const Duration(milliseconds: 250)) {
      _candidate = hz;
      _votes = 1;
    } else {
      _votes++;
    }
    _candidateAt = now;
    final distance = _pitch == null ? 0.0 : centsFrom(hz, _pitch!).abs();
    final harmonic = [
      1200.0,
      1902.0,
      2400.0,
    ].any((c) => (distance - c).abs() < 65);
    final attack = frame.rms > _level * 1.7;
    // Decay harmonics need sustained evidence; a fresh pluck switches quickly.
    final needed = harmonic && !attack ? 5 : 2;
    final decayedJump =
        _pitch != null && frame.rms < _level * (harmonic ? 0.8 : 0.3);
    if (_votes >= needed && !decayedJump) {
      _pitch = hz;
      _level = frame.rms;
      _lastGood = now;
      _candidate = null;
      _votes = 0;
      _recent
        ..clear()
        ..add(hz);
      return TrackedPitch(hz, newNote: true);
    }
    return _pitch == null ? null : TrackedPitch(_pitch!, held: true);
  }
}

int closestTuning(double hz, List<int> tuning, {int? previous}) {
  final nearest = tuning.reduce(
    (a, b) =>
        centsFrom(hz, noteFrequency(a)).abs() <
            centsFrom(hz, noteFrequency(b)).abs()
        ? a
        : b,
  );
  if (previous != null &&
      tuning.contains(previous) &&
      centsFrom(hz, noteFrequency(previous)).abs() <
          centsFrom(hz, noteFrequency(nearest)).abs() + 80) {
    return previous;
  }
  return nearest;
}
