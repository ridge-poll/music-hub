import 'dart:math' as math;
import 'dart:typed_data';

const fifthNames = [
  'C',
  'G',
  'D',
  'A',
  'E',
  'B',
  'F♯',
  'D♭',
  'A♭',
  'E♭',
  'B♭',
  'F',
];
const minorNames = [
  'A',
  'E',
  'B',
  'F♯',
  'C♯',
  'G♯',
  'D♯',
  'B♭',
  'F',
  'C',
  'G',
  'D',
];
const signatures = [
  '0',
  '1♯',
  '2♯',
  '3♯',
  '4♯',
  '5♯ / 7♭',
  '6♯ / 6♭',
  '5♭ / 7♯',
  '4♭',
  '3♭',
  '2♭',
  '1♭',
];
const fifthPitches = [0, 7, 2, 9, 4, 11, 6, 1, 8, 3, 10, 5];
const circleMinStep = -24, circleMaxStep = 35;

class CircleChord {
  const CircleChord(this.step, {this.minor = false});
  final int step;
  final bool minor;
  int get index => step % 12;
  int get octave => 4 + (step / 12).floor();
  int get root =>
      12 * (octave + 1) + (fifthPitches[index] + (minor ? 9 : 0)) % 12;
  String get name => minor ? '${minorNames[index]}m' : fifthNames[index];
  String get register =>
      '${minor ? minorNames[index] : fifthNames[index]}$octave';
  List<int> get notes => [root, root + (minor ? 3 : 4), root + 7];
}

/// Track signed turns rather than reducing accumulated movement modulo twelve.
class CircleDrag {
  CircleDrag(int step, double angle)
    : position = step + angle * 6 / math.pi - (angle * 6 / math.pi).round(),
      previous = angle;
  double position, previous;
  int move(double angle) {
    var delta = angle - previous;
    if (delta > math.pi) delta -= 2 * math.pi;
    if (delta < -math.pi) delta += 2 * math.pi;
    previous = angle;
    position = (position + delta * 6 / math.pi).clamp(
      circleMinStep.toDouble(),
      circleMaxStep.toDouble(),
    );
    return position.round();
  }
}

Uint8List renderCircleChord(CircleChord chord) {
  const rate = 22050, seconds = 1.8;
  final frames = (rate * seconds).round();
  final bytes = Uint8List(44 + frames * 2), header = ByteData(44);
  void tag(int offset, String value) =>
      bytes.setRange(offset, offset + value.length, value.codeUnits);
  header.setUint32(4, bytes.length - 8, Endian.little);
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little);
  header.setUint16(22, 1, Endian.little);
  header.setUint32(24, rate, Endian.little);
  header.setUint32(28, rate * 2, Endian.little);
  header.setUint16(32, 2, Endian.little);
  header.setUint16(34, 16, Endian.little);
  header.setUint32(40, frames * 2, Endian.little);
  bytes.setRange(0, 44, header.buffer.asUint8List());
  tag(0, 'RIFF');
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  tag(36, 'data');
  final pcm = ByteData.sublistView(bytes);
  final frequencies = chord.notes
      .map((n) => 440 * math.pow(2, (n - 69) / 12))
      .toList();
  for (var i = 0; i < frames; i++) {
    final t = i / rate;
    final envelope =
        math.min(1.0, t / .012) *
        math.exp(-2.4 * t) *
        math.min(1.0, (seconds - t) / .08);
    var value = 0.0;
    for (final hz in frequencies) {
      final phase = 2 * math.pi * hz * t;
      value +=
          math.sin(phase) +
          .18 * math.sin(2 * phase) +
          .06 * math.sin(3 * phase);
    }
    pcm.setInt16(
      44 + 2 * i,
      (value * envelope * 7000).round().clamp(-32767, 32767),
      Endian.little,
    );
  }
  return bytes;
}
