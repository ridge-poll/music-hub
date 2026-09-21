import 'dart:math' as math;
import 'package:test/test.dart';
import 'package:music_hub/dsp.dart';
import 'package:music_hub/pitch_tracker.dart';

void main() {
  late PitchTracker tracker;
  var ms = 0;
  TrackedPitch? feed(
    double? hz, {
    double confidence = 0.99,
    double level = 0.1,
    int step = 50,
  }) {
    ms += step;
    return tracker.update(
      PitchFrame(hz, confidence, level, []),
      Duration(milliseconds: ms),
    );
  }

  setUp(() {
    tracker = PitchTracker();
    ms = 0;
  });
  test(
    'requires agreement to acquire; isolated noise cannot switch a lock',
    () {
      expect(feed(110), isNull);
      expect(feed(110)!.frequency, 110);
      for (final hz in [330.0, 82.0, 220.0, 147.0]) {
        final reading = feed(hz)!;
        expect(reading.frequency, 110);
        expect(reading.held, true);
        feed(110);
      }
    },
  );
  test(
    'log smoothing reduces jitter but tracks deliberate tuning to +200 cents',
    () {
      feed(110);
      feed(110);
      final output = <double>[];
      for (var i = 0; i < 20; i++) {
        output.add(
          centsFrom(
            feed(110.0 * math.pow(2, (i.isEven ? 12 : -12) / 1200))!.frequency,
            110,
          ),
        );
      }
      expect(output.reduce(math.max) - output.reduce(math.min), lessThan(16));
      for (var cents = 0; cents <= 200; cents += 10) {
        feed(110.0 * math.pow(2, cents / 1200));
      }
      TrackedPitch? last;
      for (var i = 0; i < 8; i++) {
        last = feed(110.0 * math.pow(2, 200 / 1200));
      }
      expect(centsFrom(last!.frequency, 110), closeTo(200, 5));
    },
  );
  test(
    'low confidence and quiet harmonics do not hijack decaying note; hold expires',
    () {
      feed(82.407);
      feed(82.407);
      for (var i = 0; i < 6; i++) {
        expect(feed(164.814, level: 0.04)!.frequency, 82.407);
      }
      expect(feed(300, confidence: 0.8, level: 0.02)!.held, true);
      expect(feed(null, confidence: 0, level: 0.001, step: 700), isNull);
    },
  );
  test(
    'new pluck changes strings after two consistent frames, including an octave',
    () {
      feed(82.407);
      feed(82.407);
      expect(feed(110, level: 0.2)!.frequency, 82.407);
      expect(feed(110, level: 0.2)!.frequency, 110);
      expect(feed(220, level: 0.4)!.frequency, 110);
      expect(feed(220, level: 0.4)!.frequency, 220);
    },
  );
  test(
    'sample-level guitar decay plus seeded noise does not switch to another string',
    () {
      final random = math.Random(9);
      for (var frame = 0; frame < 30; frame++) {
        final amplitude = 0.3 * math.exp(-frame / 9);
        final signal = List.generate(4096, (i) {
          final t = (i + frame * 1024) / 22050;
          return amplitude *
                  (math.sin(2 * math.pi * 110 * t) +
                      0.5 * math.sin(2 * math.pi * 220 * t)) +
              (random.nextDouble() - 0.5) * 0.006;
        });
        final detected = analyzePitch(signal, 22050);
        ms += 50;
        final reading = tracker.update(detected, Duration(milliseconds: ms));
        if (frame >= 2 && reading != null) {
          expect(centsFrom(reading.frequency, 110).abs(), lessThan(8));
        }
      }
    },
  );
  test('target hysteresis does not flap at a string boundary', () {
    const tuning = [40, 45, 50, 55, 59, 64];
    final hz = noteFrequency(57) * math.pow(2, 10 / 1200);
    expect(closestTuning(hz, tuning, previous: 55), 55);
    expect(closestTuning(noteFrequency(59), tuning, previous: 55), 59);
  });
}
