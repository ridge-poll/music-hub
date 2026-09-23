import 'dart:math' as math;
import 'dart:typed_data';

class MetronomeSettings {
  MetronomeSettings({
    this.bpm = 100,
    this.beats = 4,
    this.unit = 4,
    List<int>? accents,
  }) : accents = List.unmodifiable(
         accents ?? List.generate(beats, (i) => i == 0 ? 2 : 1),
       );
  final int bpm, beats, unit;
  // 0 silent, 1 normal, 2 accented.
  final List<int> accents;
  Map<String, Object> toJson() => {
    'bpm': bpm,
    'beats': beats,
    'unit': unit,
    'accents': accents,
  };
  factory MetronomeSettings.fromJson(Map<String, dynamic> data) {
    final bpm = data['bpm'] as int,
        beats = data['beats'] as int,
        unit = data['unit'] as int;
    final accents = (data['accents'] as List).cast<int>();
    if (bpm < 40 ||
        bpm > 240 ||
        beats < 1 ||
        beats > 12 ||
        ![2, 4, 8].contains(unit) ||
        accents.length != beats ||
        accents.any((a) => a < 0 || a > 2)) {
      throw const FormatException('Invalid metronome settings');
    }
    return MetronomeSettings(
      bpm: bpm,
      beats: beats,
      unit: unit,
      accents: accents,
    );
  }
}

class TapTempo {
  final List<int> _taps = [];
  int? tap(int milliseconds) {
    if (_taps.isNotEmpty &&
        (milliseconds - _taps.last > 3000 || milliseconds <= _taps.last)) {
      _taps.clear();
    }
    _taps.add(milliseconds);
    if (_taps.length > 6) _taps.removeAt(0);
    if (_taps.length < 2) return null;
    return (60000 * (_taps.length - 1) / (_taps.last - _taps.first))
        .round()
        .clamp(40, 240);
  }
}

const metronomeSampleRate = 22050;
int loopBeats(MetronomeSettings settings) =>
    math.max(2, (settings.bpm / settings.beats).ceil()) * settings.beats;

/// An integral number of bars, with onsets calculated from absolute sample
/// positions. Native playback loops this PCM; UI timers never trigger clicks.
Uint8List renderMetronome(MetronomeSettings settings) {
  final interval = metronomeSampleRate * 60 / settings.bpm;
  final beats = loopBeats(settings);
  final frames = (beats * interval).round();
  final bytes = Uint8List(44 + frames * 2);
  final data = ByteData.sublistView(bytes);
  void ascii(int offset, String value) =>
      bytes.setRange(offset, offset + value.length, value.codeUnits);
  ascii(0, 'RIFF');
  data.setUint32(4, bytes.length - 8, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, metronomeSampleRate, Endian.little);
  data.setUint32(28, metronomeSampleRate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  data.setUint32(40, frames * 2, Endian.little);
  final length = (metronomeSampleRate * .025).round();
  for (var beat = 0; beat < beats; beat++) {
    final accent = settings.accents[beat % settings.beats];
    if (accent == 0) continue;
    final start = (beat * interval).round();
    for (var n = 0; n < length && start + n < frames; n++) {
      final envelope = math.min(1.0, n / 12) * math.exp(-7 * n / length);
      final sample =
          (math.sin(
                    2 *
                        math.pi *
                        (accent == 2 ? 1600 : 1050) *
                        n /
                        metronomeSampleRate,
                  ) *
                  envelope *
                  (accent == 2 ? 22000 : 14000))
              .round();
      data.setInt16(44 + (start + n) * 2, sample, Endian.little);
    }
  }
  return bytes;
}
