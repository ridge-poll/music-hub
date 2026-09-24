import 'dart:math' as math;
import 'package:test/test.dart';
import 'package:music_hub/tempo_estimator.dart';

List<double> rhythmicAudio(double bpm, int rate, {double noise = 0}) {
  final random = math.Random(42);
  return List.generate(rate * 12, (i) {
    final time = i / rate, phase = time % (60 / bpm);
    return .5 * math.exp(-phase * 65) * math.sin(2 * math.pi * 170 * time) +
        noise * (random.nextDouble() * 2 - 1);
  });
}

void main() {
  test('finds periodic attacks at varied tempos and sample rates', () {
    for (final bpm in [60, 83, 100, 120, 137, 180, 220]) {
      for (final rate in [16000, 22050, 44100]) {
        final result = estimateTempo(
          rhythmicAudio(bpm.toDouble(), rate, noise: .006),
          rate,
        );
        expect(result, isNotNull, reason: '$bpm at $rate');
        expect(result!.bpm, closeTo(bpm, 2), reason: '$bpm at $rate');
      }
    }
  });
  test(
    'silence, constant tone, random noise and short clips reject estimates',
    () {
      const rate = 22050;
      expect(estimateTempo(List.filled(rate * 12, 0), rate), isNull);
      expect(
        estimateTempo(
          List.generate(
            rate * 12,
            (i) => .3 * math.sin(2 * math.pi * 440 * i / rate),
          ),
          rate,
        ),
        isNull,
      );
      final random = math.Random(7);
      expect(
        estimateTempo(
          List.generate(rate * 12, (_) => random.nextDouble() * .2 - .1),
          rate,
        ),
        isNull,
      );
      expect(
        estimateTempo(rhythmicAudio(120, rate).take(rate * 3).toList(), rate),
        isNull,
      );
    },
  );
}
