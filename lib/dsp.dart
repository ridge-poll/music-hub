import 'dart:math' as math;
import 'dart:typed_data';

class PitchFrame {
  const PitchFrame(this.frequency, this.confidence, this.rms, this.spectrum);
  final double? frequency;
  final double confidence, rms;
  final List<double> spectrum;
}

// Fixed-window YIN difference function + parabolic lag interpolation.
// Work is dispatched to an isolate by the tuner; no network or audio files.
PitchFrame analyzePitch(List<double> samples, int sampleRate) {
  final n = samples.length;
  final mean = samples.reduce((a, b) => a + b) / n;
  final x = Float64List.fromList(samples.map((v) => v - mean).toList());
  final rms = math.sqrt(x.fold<double>(0, (sum, v) => sum + v * v) / n);
  final spectrum = fftMagnitudes(x);
  if (rms < 0.004) return PitchFrame(null, 0, rms, spectrum);
  final maxLag = math.min(n ~/ 2, sampleRate ~/ 55);
  final minLag = sampleRate ~/ 1200;
  final difference = Float64List(maxLag + 1);
  double sum = 0;
  for (var lag = 1; lag <= maxLag; lag++) {
    double value = 0;
    for (var i = 0; i < n - maxLag; i++) {
      final d = x[i] - x[i + lag];
      value += d * d;
    }
    sum += value;
    difference[lag] = sum == 0 ? 1 : value * lag / sum;
  }
  for (var lag = minLag; lag < maxLag - 1; lag++) {
    if (difference[lag] < 0.15) {
      while (lag + 1 < maxLag && difference[lag + 1] < difference[lag]) {
        lag++;
      }
      final a = difference[lag - 1],
          b = difference[lag],
          c = difference[math.min(lag + 1, maxLag)];
      final denominator = a - 2 * b + c;
      final refined =
          lag + (denominator.abs() < 1e-12 ? 0 : 0.5 * (a - c) / denominator);
      return PitchFrame(
        sampleRate / refined,
        (1 - b).clamp(0, 1),
        rms,
        spectrum,
      );
    }
  }
  return PitchFrame(null, 0, rms, spectrum);
}

// Radix-2 FFT, Hann window. Output is linear magnitude per positive bin.
List<double> fftMagnitudes(List<double> samples) {
  final n = samples.length;
  if (n < 2 || (n & (n - 1)) != 0) {
    throw ArgumentError('FFT requires power-of-two samples');
  }
  final re = Float64List(n), im = Float64List(n);
  for (var i = 0; i < n; i++) {
    re[i] = samples[i] * (0.5 - 0.5 * math.cos(2 * math.pi * i / (n - 1)));
  }
  for (int i = 1, j = 0; i < n; i++) {
    var bit = n >> 1;
    while ((j & bit) != 0) {
      j ^= bit;
      bit >>= 1;
    }
    j ^= bit;
    if (i < j) {
      final t = re[i];
      re[i] = re[j];
      re[j] = t;
    }
  }
  for (var len = 2; len <= n; len <<= 1) {
    final angle = -2 * math.pi / len;
    for (var i = 0; i < n; i += len) {
      for (var j = 0; j < len ~/ 2; j++) {
        final cos = math.cos(angle * j), sin = math.sin(angle * j);
        final k = i + j + len ~/ 2;
        final r = re[k] * cos - im[k] * sin, m = re[k] * sin + im[k] * cos;
        re[k] = re[i + j] - r;
        im[k] = im[i + j] - m;
        re[i + j] += r;
        im[i + j] += m;
      }
    }
  }
  return List.generate(
    n ~/ 2,
    (i) => math.sqrt(re[i] * re[i] + im[i] * im[i]) * 4 / n,
  );
}

double noteFrequency(int midi) => 440.0 * math.pow(2, (midi - 69) / 12);
double centsFrom(double hz, double target) =>
    1200 * math.log(hz / target) / math.ln2;
String noteName(int midi) =>
    '${['C', 'C♯', 'D', 'D♯', 'E', 'F', 'F♯', 'G', 'G♯', 'A', 'A♯', 'B'][midi % 12]}${midi ~/ 12 - 1}';
