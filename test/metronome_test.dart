import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:music_hub/metronome.dart';

void main() {
  test('tap tempo averages recent intervals and resets after a pause', () {
    final taps = TapTempo();
    expect(taps.tap(0), isNull);
    expect(taps.tap(500), 120);
    expect(taps.tap(1010), 119);
    expect(taps.tap(1500), 120);
    expect(taps.tap(6000), isNull);
    expect(taps.tap(7000), 60);
  });
  test('preferences round trip and reject invalid saved data', () {
    final settings = MetronomeSettings(
      bpm: 137,
      beats: 7,
      unit: 8,
      accents: [2, 1, 0, 1, 2, 1, 0],
    );
    expect(
      MetronomeSettings.fromJson(settings.toJson()).toJson(),
      settings.toJson(),
    );
    expect(
      () => MetronomeSettings.fromJson({...settings.toJson(), 'bpm': 0}),
      throwsFormatException,
    );
  });
  test(
    'WAV uses sample-positioned clicks, silent beats and whole-bar loop',
    () {
      final settings = MetronomeSettings(
        bpm: 137,
        beats: 3,
        accents: [2, 1, 0],
      );
      final bytes = renderMetronome(settings);
      final data = ByteData.sublistView(bytes);
      expect(String.fromCharCodes(bytes.take(4)), 'RIFF');
      expect(data.getUint32(24, Endian.little), metronomeSampleRate);
      final interval = metronomeSampleRate * 60 / settings.bpm;
      final frames = (loopBeats(settings) * interval).round();
      expect(bytes.length, 44 + frames * 2);
      expect(loopBeats(settings) % settings.beats, 0);
      int energy(int start, int count) {
        var sum = 0;
        for (var n = start; n < start + count; n++) {
          sum += data.getInt16(44 + n * 2, Endian.little).abs();
        }
        return sum;
      }

      for (var beat = 0; beat < loopBeats(settings); beat++) {
        final start = (beat * interval).round();
        expect(energy(start, 600), beat % 3 == 2 ? 0 : greaterThan(100000));
        expect(energy(start + 600, 100), 0);
      }
      expect(energy(0, 600), greaterThan(energy(interval.round(), 600)));
      expect(energy(frames - 100, 100), 0);
    },
  );
}
