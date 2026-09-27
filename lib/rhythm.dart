import 'dart:math' as math;
import 'dart:typed_data';
import 'document.dart' show ids;

const rhythmMaxRows = 8, rhythmMaxLeaves = 256, rhythmMaxDepth = 8;
const rhythmSampleRate = 22050;

enum RhythmSound { click, kick, snare, hiHat }

extension RhythmSoundLabel on RhythmSound {
  String get label => switch (this) {
    RhythmSound.click => 'Click',
    RhythmSound.kick => 'Kick',
    RhythmSound.snare => 'Snare',
    RhythmSound.hiHat => 'Hi-hat',
  };
}

/// Exact normalized position/duration; no common tick grid or accumulated time.
class CycleFraction {
  CycleFraction(BigInt numerator, BigInt denominator)
    : numerator = numerator ~/ numerator.gcd(denominator),
      denominator = denominator ~/ numerator.gcd(denominator) {
    if (denominator <= BigInt.zero) {
      throw ArgumentError('Positive denominator required');
    }
  }
  factory CycleFraction.of(int n, [int d = 1]) =>
      CycleFraction(BigInt.from(n), BigInt.from(d));
  final BigInt numerator, denominator;
  CycleFraction operator +(CycleFraction b) => CycleFraction(
    numerator * b.denominator + b.numerator * denominator,
    denominator * b.denominator,
  );
  CycleFraction divide(int n) =>
      CycleFraction(numerator, denominator * BigInt.from(n));
  double get value => numerator.toDouble() / denominator.toDouble();
  int frame(int frames) =>
      ((numerator * BigInt.from(frames) + denominator ~/ BigInt.two) ~/
              denominator)
          .toInt();
  @override
  String toString() => '$numerator/$denominator';
}

/// Only leaves have musical state: 0 rest, 1 hit, 2 accent.
/// Children, when present, partition the parent into equal spans.
class RhythmBlock {
  RhythmBlock({this.hit = 0, List<RhythmBlock> children = const []})
    : children = List.unmodifiable(children);
  final int hit;
  final List<RhythmBlock> children;
  bool get isLeaf => children.isEmpty;
  RhythmBlock at(List<int> path) =>
      path.isEmpty ? this : children[path.first].at(path.sublist(1));
  RhythmBlock replace(List<int> path, RhythmBlock replacement) {
    if (path.isEmpty) return replacement;
    final next = children.toList();
    next[path.first] = next[path.first].replace(path.sublist(1), replacement);
    return RhythmBlock(children: next);
  }

  Map<String, dynamic> toJson() => isLeaf
      ? {'hit': hit}
      : {'children': children.map((c) => c.toJson()).toList()};
}

class RhythmLeaf {
  RhythmLeaf(this.path, this.start, this.duration, this.hit);
  final List<int> path;
  final CycleFraction start, duration;
  final int hit;
}

List<RhythmLeaf> rhythmLeaves(RhythmBlock root) {
  final result = <RhythmLeaf>[];
  void visit(
    RhythmBlock block,
    List<int> path,
    CycleFraction start,
    CycleFraction duration,
  ) {
    if (block.isLeaf) {
      result.add(
        RhythmLeaf(List.unmodifiable(path), start, duration, block.hit),
      );
      return;
    }
    final childDuration = duration.divide(block.children.length);
    var position = start;
    for (var i = 0; i < block.children.length; i++) {
      visit(block.children[i], [...path, i], position, childDuration);
      position = position + childDuration;
    }
  }

  visit(root, [], CycleFraction.of(0), CycleFraction.of(1));
  return result;
}

class RhythmRow {
  RhythmRow({String? id, this.sound = RhythmSound.click, RhythmBlock? root})
    : id = id ?? ids.v4(),
      root = root ?? RhythmBlock();
  final String id;
  final RhythmSound sound;
  final RhythmBlock root;
  RhythmRow copy({RhythmSound? sound, RhythmBlock? root}) =>
      RhythmRow(id: id, sound: sound ?? this.sound, root: root ?? this.root);
  RhythmRow cycleHit(List<int> path) {
    final block = root.at(path);
    if (!block.isLeaf) throw ArgumentError('Select a leaf');
    return copy(
      root: root.replace(path, RhythmBlock(hit: (block.hit + 1) % 3)),
    );
  }

  RhythmRow divide(List<int> path, int count) {
    if (count < 1 || count > 16) {
      throw const FormatException('Divide into 1–16 blocks.');
    }
    final block = root.at(path);
    if (!block.isLeaf) throw ArgumentError('Select a leaf');
    if (count == 1) return this;
    if (path.length >= rhythmMaxDepth ||
        rhythmLeaves(root).length + count - 1 > rhythmMaxLeaves) {
      throw const FormatException(
        'This row has reached its subdivision limit.',
      );
    }
    return copy(
      root: root.replace(
        path,
        RhythmBlock(
          children: List.generate(
            count,
            (i) => RhythmBlock(hit: i == 0 ? block.hit : 0),
          ),
        ),
      ),
    );
  }

  RhythmRow merge(List<int> leafPath) {
    if (leafPath.isEmpty) return this;
    final parent = leafPath.sublist(0, leafPath.length - 1);
    return copy(
      root: root.replace(
        parent,
        RhythmBlock(hit: rhythmLeaves(root.at(parent)).first.hit),
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'sound': sound.name,
    'root': root.toJson(),
  };
}

/// A single saved workspace. Pulse count only sets cycle duration; subdivision
/// trees and their fractional positions are completely independent of meter.
class RhythmPattern {
  RhythmPattern({this.bpm = 100, this.pulses = 4, List<RhythmRow>? rows})
    : rows = List.unmodifiable(rows ?? [RhythmRow()]);
  final int bpm, pulses;
  final List<RhythmRow> rows;
  RhythmPattern copy({int? bpm, int? pulses, List<RhythmRow>? rows}) =>
      RhythmPattern(
        bpm: bpm ?? this.bpm,
        pulses: pulses ?? this.pulses,
        rows: rows ?? this.rows,
      );
  RhythmPattern replaceRow(int index, RhythmRow row) {
    final next = rows.toList();
    next[index] = row;
    return copy(rows: next);
  }

  Map<String, dynamic> toJson() => {
    'formatVersion': 1,
    'bpm': bpm,
    'pulses': pulses,
    'rows': rows.map((r) => r.toJson()).toList(),
  };
  factory RhythmPattern.fromJson(dynamic value) {
    if (value is! Map ||
        value['formatVersion'] != 1 ||
        value['bpm'] is! int ||
        value['bpm'] < 40 ||
        value['bpm'] > 240 ||
        value['pulses'] is! int ||
        value['pulses'] < 1 ||
        value['pulses'] > 16 ||
        value['rows'] is! List ||
        value['rows'].length > rhythmMaxRows) {
      throw const FormatException('Invalid rhythm pattern.');
    }
    final identifiers = <String>{}, rows = <RhythmRow>[];
    for (final row in value['rows']) {
      if (row is! Map ||
          row['id'] is! String ||
          !RegExp(r'^[A-Za-z0-9_-]{1,80}$').hasMatch(row['id']) ||
          !identifiers.add(row['id'])) {
        throw const FormatException('Invalid rhythm row.');
      }
      final sound = RhythmSound.values
          .where((s) => s.name == row['sound'])
          .firstOrNull;
      if (sound == null) throw const FormatException('Unknown rhythm sound.');
      var leaves = 0, nodes = 0;
      RhythmBlock read(dynamic block, int depth) {
        if (depth > rhythmMaxDepth || ++nodes > 512 || block is! Map) {
          throw const FormatException('Invalid subdivision tree.');
        }
        if (block.containsKey('children')) {
          final children = block['children'];
          if (block.containsKey('hit') ||
              children is! List ||
              children.length < 2 ||
              children.length > 16) {
            throw const FormatException('Invalid division.');
          }
          return RhythmBlock(
            children: [for (final c in children) read(c, depth + 1)],
          );
        }
        if (++leaves > rhythmMaxLeaves ||
            block['hit'] is! int ||
            block['hit'] < 0 ||
            block['hit'] > 2) {
          throw const FormatException('Invalid hit.');
        }
        return RhythmBlock(hit: block['hit']);
      }

      rows.add(
        RhythmRow(id: row['id'], sound: sound, root: read(row['root'], 0)),
      );
    }
    return RhythmPattern(
      bpm: value['bpm'],
      pulses: value['pulses'],
      rows: rows,
    );
  }
}

int rhythmCycleFrames(RhythmPattern pattern) =>
    (rhythmSampleRate * 60 * pattern.pulses / pattern.bpm).round();

class RhythmOnset {
  RhythmOnset(this.row, this.frame, this.hit, this.sound);
  final int row, frame, hit;
  final RhythmSound sound;
}

List<RhythmOnset> rhythmOnsets(RhythmPattern pattern) {
  final frames = rhythmCycleFrames(pattern);
  return [
    for (var r = 0; r < pattern.rows.length; r++)
      for (final leaf in rhythmLeaves(pattern.rows[r].root))
        if (leaf.hit > 0)
          RhythmOnset(
            r,
            leaf.start.frame(frames) % frames,
            leaf.hit,
            pattern.rows[r].sound,
          ),
  ];
}

/// Mix every row into one periodic PCM buffer: one native clock, simultaneous
/// sample-aligned onsets, and no UI timer or separately drifting row players.
Uint8List renderRhythm(RhythmPattern input) {
  final pattern = RhythmPattern.fromJson(input.toJson());
  final cycle = rhythmCycleFrames(pattern);
  final repeats = math.max(1, (rhythmSampleRate * 2 / cycle).ceil());
  final frames = cycle * repeats;
  final mix = Float64List(frames);
  final voices = {for (final sound in RhythmSound.values) sound: _voice(sound)};
  for (final onset in rhythmOnsets(pattern)) {
    final voice = voices[onset.sound]!;
    final gain = onset.hit == 2 ? 0.85 : 0.5;
    for (var c = 0; c < repeats; c++) {
      final start = c * cycle + onset.frame;
      for (var n = 0; n < voice.length; n++) {
        mix[(start + n) % frames] += voice[n] * gain;
      }
    }
  }
  final bytes = Uint8List(44 + frames * 2);
  final data = ByteData.sublistView(bytes);
  void ascii(int offset, String value) =>
      bytes.setRange(offset, offset + value.length, value.codeUnits);
  ascii(0, 'RIFF');
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  ascii(36, 'data');
  data.setUint32(4, bytes.length - 8, Endian.little);
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, rhythmSampleRate, Endian.little);
  data.setUint32(28, rhythmSampleRate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  data.setUint32(40, frames * 2, Endian.little);
  final pcm = ByteData.sublistView(bytes);
  final gain = 1 / math.sqrt(math.max(1, pattern.rows.length));
  for (var i = 0; i < frames; i++) {
    final v = mix[i] * gain;
    pcm.setInt16(
      44 + i * 2,
      (32760 * v / (1 + v.abs())).round(),
      Endian.little,
    );
  }
  return bytes;
}

Float64List _voice(RhythmSound sound) {
  final seconds = switch (sound) {
    RhythmSound.click => 0.025,
    RhythmSound.kick => 0.18,
    RhythmSound.snare => 0.12,
    RhythmSound.hiHat => 0.055,
  };
  final samples = Float64List((seconds * rhythmSampleRate).round());
  final random = math.Random(417);
  var last = 0.0;
  for (var n = 0; n < samples.length; n++) {
    final t = n / rhythmSampleRate, noise = random.nextDouble() * 2 - 1;
    final attack = math.min(1.0, n / 12),
        decay = math.exp(-7 * n / samples.length);
    final wave = switch (sound) {
      RhythmSound.click => math.sin(2 * math.pi * 1400 * t),
      RhythmSound.kick => math.sin(
        2 * math.pi * (48 * t + 85 * 0.025 * (1 - math.exp(-t / 0.025))),
      ),
      RhythmSound.snare =>
        0.75 * noise + 0.25 * math.sin(2 * math.pi * 180 * t),
      RhythmSound.hiHat => (noise - last) * 0.5,
    };
    samples[n] = wave * attack * decay;
    last = noise;
  }
  return samples;
}
