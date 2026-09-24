import 'dart:math' as math;

class TempoEstimate {
  const TempoEstimate(this.bpm, this.periodicity);
  final int bpm;
  final double periodicity;
}

/// Energy-rise onset envelope followed by normalized autocorrelation. This
/// estimates a repeating pulse, not meter; half/double ambiguity is expected.
TempoEstimate? estimateTempo(List<double> samples, int rate) {
  if (rate < 8000 || samples.length < rate * 6) return null;
  final hop = (rate / 100).round();
  final energy = <double>[];
  double previous = 0, highpass = 0, sum = 0, total = 0;
  for (var i = 0; i < samples.length; i++) {
    final value = samples[i];
    highpass = .97 * (highpass + value - previous);
    previous = value;
    sum += highpass * highpass;
    total += value * value;
    if ((i + 1) % hop == 0) {
      energy.add(math.log(1 + 100 * math.sqrt(sum / hop)));
      sum = 0;
    }
  }
  if (math.sqrt(total / samples.length) < .003) return null;
  final onset = List<double>.filled(energy.length, 0);
  for (var i = 3; i < energy.length; i++) {
    onset[i] = math.max(
      0,
      energy[i] - (energy[i - 1] + energy[i - 2] + energy[i - 3]) / 3,
    );
  }
  final maximum = onset.reduce(math.max);
  if (maximum < .05) return null;
  var peaks = 0, last = -100;
  for (var i = 1; i < onset.length - 1; i++) {
    if (onset[i] > maximum * .25 &&
        onset[i] >= onset[i - 1] &&
        onset[i] > onset[i + 1] &&
        i - last > 15) {
      peaks++;
      last = i;
    }
  }
  if (peaks < 4) return null;
  // Smooth across adjacent onset frames before fractional-lag matching so
  // integer sample-grid coincidences cannot beat the actual pulse period.
  final smooth = List<double>.generate(onset.length, (i) {
    var value = 0.0;
    for (var k = -2; k <= 2; k++) {
      final j = i + k;
      if (j >= 0 && j < onset.length) value += onset[j] * (3 - k.abs());
    }
    return value / 9;
  });
  final mean = smooth.reduce((a, b) => a + b) / smooth.length;
  final centered = smooth.map((v) => v - mean).toList();
  double correlate(double lag) {
    double cross = 0, left = 0, right = 0;
    for (var i = lag.ceil(); i < centered.length; i++) {
      final position = i - lag, j = position.floor(), fraction = position - j;
      final a = centered[i],
          b =
              centered[j] * (1 - fraction) +
              centered[math.min(j + 1, centered.length - 1)] * fraction;
      cross += a * b;
      left += a * a;
      right += b * b;
    }
    return left * right > 1e-12 ? cross / math.sqrt(left * right) : 0;
  }

  var best = 0.0, confidence = 0.0, bpm = 0;
  for (var candidate = 40; candidate <= 240; candidate++) {
    final correlation = correlate(60 * rate / (hop * candidate));
    // A weak short-lag preference resolves near-equal repetition multiples.
    final score = correlation * (.90 + .10 * candidate / 240);
    if (score > best) {
      best = score;
      confidence = correlation;
      bpm = candidate;
    }
  }
  if (confidence < .38) return null;
  return TempoEstimate(bpm, confidence);
}
