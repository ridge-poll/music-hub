import 'dart:math' as math;
import 'package:test/test.dart';
import 'package:music_hub/dsp.dart';

void main() {
  for (final rate in [22050, 44100, 48000]) {
    for (final frequency in [
      65.406,
      73.416,
      82.407,
      110.0,
      146.832,
      195.998,
      246.942,
      329.628,
      440.0,
      659.255,
    ]) {
      test('YIN $frequency Hz at $rate Hz, guitar harmonics and DC offset', () {
        final samples = List.generate(4096, (i) {
          final phase = 2 * math.pi * frequency * i / rate;
          return 0.1 +
              0.25 * math.sin(phase) +
              0.35 * math.sin(2 * phase) +
              0.15 * math.sin(3 * phase);
        });
        final frame = analyzePitch(samples, rate);
        expect(frame.frequency, isNotNull);
        expect(centsFrom(frame.frequency!, frequency).abs(), lessThan(5));
        expect(frame.confidence, greaterThan(0.85));
      });
    }
  }
  test('silence, DC and low-level noise have no pitch', () {
    final random = math.Random(42);
    for (final samples in [
      List<double>.filled(4096, 0),
      List<double>.filled(4096, 0.3),
      List.generate(4096, (_) => (random.nextDouble() - 0.5) * 0.002),
    ]) {
      expect(analyzePitch(samples, 22050).frequency, isNull);
    }
  });
  test('broadband noise does not become a confident note', () {
    final random = math.Random(19);
    expect(
      analyzePitch(
        List.generate(4096, (_) => random.nextDouble() - 0.5),
        22050,
      ).frequency,
      isNull,
    );
  });
  test('FFT peak matches input and note/cents conversion', () {
    const rate = 22050, n = 4096, bin = 82;
    final spectrum = fftMagnitudes(
      List.generate(n, (i) => 0.5 * math.sin(2 * math.pi * bin * i / n)),
    );
    final maximum = spectrum.reduce(math.max);
    expect(spectrum.indexOf(maximum), bin);
    expect(maximum, closeTo(0.5, 0.001));
    expect(bin * rate / n, closeTo(441.43, 0.1));
    expect(noteFrequency(69), 440);
    expect(noteName(40), 'E2');
    expect(centsFrom(440.0 * math.pow(2, 25 / 1200), 440), closeTo(25, 0.001));
  });
}
