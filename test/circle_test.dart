import 'dart:math' as math;
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:music_hub/circle.dart';

void main() {
  test('one turn changes one octave, including negative turns', () {
    expect(const CircleChord(0).register, 'C4');
    expect(const CircleChord(12).register, 'C5');
    expect(const CircleChord(-12).register, 'C3');
    expect(const CircleChord(-1).register, 'F3');
    expect(const CircleChord(0).notes, [60, 64, 67]);
    expect(const CircleChord(0, minor: true).notes, [69, 72, 76]);
    for (var step = circleMinStep; step <= circleMaxStep; step++) {
      for (final minor in [true, false]) {
        final chord = CircleChord(step, minor: minor);
        expect(chord.notes.every((n) => n >= 21 && n <= 108), isTrue);
        if (step + 12 <= circleMaxStep) {
          expect(CircleChord(step + 12, minor: minor).root, chord.root + 12);
        }
      }
    }
  });
  test('drag unwraps both directions and stays bounded at ends', () {
    final drag = CircleDrag(0, 0);
    for (var i = 1; i <= 24; i++) {
      final a = i * math.pi / 6;
      expect(drag.move(math.atan2(math.sin(a), math.cos(a))), i);
    }
    for (var i = 23; i >= -24; i--) {
      final a = i * math.pi / 6;
      expect(drag.move(math.atan2(math.sin(a), math.cos(a))), i);
    }
    expect(drag.move(-math.pi / 6), circleMinStep);
    expect(drag.move(0), circleMinStep + 1);
  });
  test('triads produce deterministic bounded PCM with faded ends', () {
    final wave = renderCircleChord(const CircleChord(0));
    expect(wave, renderCircleChord(const CircleChord(0)));
    expect(wave, isNot(renderCircleChord(const CircleChord(0, minor: true))));
    expect(String.fromCharCodes(wave.take(4)), 'RIFF');
    final data = ByteData.sublistView(wave);
    expect(data.getUint32(24, Endian.little), 22050);
    expect(data.getInt16(44, Endian.little), 0);
    expect(data.getInt16(wave.length - 2, Endian.little).abs(), lessThan(10));
    var peak = 0;
    for (var i = 44; i < wave.length; i += 2) {
      peak = math.max(peak, data.getInt16(i, Endian.little).abs());
    }
    expect(peak, greaterThan(1000));
    expect(peak, lessThan(32767));
  });
}
