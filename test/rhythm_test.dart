import 'dart:convert';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:music_hub/rhythm.dart';

RhythmRow hits(int count, {RhythmSound sound = RhythmSound.click}) {
  var row = RhythmRow(sound: sound).divide([], count);
  for (var i = 0; i < count; i++) {
    row = row.cycleHit(count == 1 ? [] : [i]);
  }
  return row;
}

void main() {
  test('every division 1–16 exactly partitions its parent; one is a no-op', () {
    final original = RhythmRow();
    for (var n = 1; n <= 16; n++) {
      final row = original.divide([], n),
          leaves = rhythmLeaves(original.divide([], n).root);
      expect(leaves.length, n);
      expect(leaves.map((l) => l.duration.toString()).toSet(), {'1/$n'});
      final total = leaves.fold(
        CycleFraction.of(0),
        (sum, l) => sum + l.duration,
      );
      expect(total.toString(), '1/1');
      expect(row.root.isLeaf, n == 1);
    }
    expect(original.root.isLeaf, true);
  });
  test(
    'third quarter divided by three has true twelfth durations and exact offsets',
    () {
      final row = RhythmRow().divide([], 4).divide([2], 3);
      final leaves = rhythmLeaves(row.root);
      expect(leaves.map((l) => l.duration.toString()), [
        '1/4',
        '1/4',
        '1/12',
        '1/12',
        '1/12',
        '1/4',
      ]);
      expect(leaves.map((l) => l.start.toString()), [
        '0/1',
        '1/4',
        '1/2',
        '7/12',
        '2/3',
        '3/4',
      ]);
      expect(row.root.children.length, 4);
      expect(row.root.children[2].children.length, 3);
    },
  );
  test(
    'hit cycling, divide inheritance and sibling merge are immutable and local',
    () {
      final base = RhythmRow().divide([], 4).cycleHit([2]).cycleHit([2]);
      final nested = base.divide([2], 3).cycleHit([2, 1]);
      expect(rhythmLeaves(nested.root).map((l) => l.hit), [0, 0, 2, 1, 0, 0]);
      final merged = nested.merge([2, 2]);
      expect(merged.root.toJson(), base.root.toJson());
      expect(nested.root.children[2].children.length, 3);
      expect(merged.cycleHit([2]).root.children[2].hit, 0);
      expect(merged.merge([]).root.toJson(), merged.root.toJson());
    },
  );
  test(
    'nested sevenths and elevenths stay ordered and fill the whole span',
    () {
      var row = RhythmRow();
      var path = <int>[];
      for (var depth = 0; depth < 8; depth++) {
        final n = depth.isEven ? 7 : 11;
        row = row.divide(path, n);
        path = [...path, n - 1];
      }
      final leaves = rhythmLeaves(row.root);
      var end = CycleFraction.of(0);
      for (final leaf in leaves) {
        expect(leaf.start.toString(), end.toString());
        end = end + leaf.duration;
      }
      expect(end.toString(), '1/1');
      expect(() => row.divide(path, 2), throwsFormatException);
      expect(() => RhythmRow().divide([], 17), throwsFormatException);
      var dense = RhythmRow().divide([], 16);
      for (var i = 0; i < 16; i++) {
        dense = dense.divide([i], 16);
      }
      expect(rhythmLeaves(dense.root).length, 256);
      expect(() => dense.divide([0, 0], 2), throwsFormatException);
    },
  );
  for (final pair in [(3, 4), (5, 7), (7, 11)]) {
    test(
      '${pair.$1}:${pair.$2} schedules independent fractions on one sample clock',
      () {
        final pattern = RhythmPattern(
          bpm: 137,
          pulses: 5,
          rows: [
            hits(pair.$1),
            hits(pair.$2, sound: RhythmSound.kick),
          ],
        );
        final frames = rhythmCycleFrames(pattern),
            events = rhythmOnsets(pattern);
        for (var r = 0; r < 2; r++) {
          final n = r == 0 ? pair.$1 : pair.$2,
              actual = events.where((e) => e.row == r).toList();
          expect(actual.length, n);
          for (var i = 0; i < n; i++) {
            expect(actual[i].frame, (i * frames / n).round());
          }
        }
        expect(events.where((e) => e.frame == 0).map((e) => e.row), [0, 1]);
        expect(pattern.rows.map((r) => r.root.children.length), [
          pair.$1,
          pair.$2,
        ]);
      },
    );
  }
  test(
    'PCM render is deterministic, periodic, bounded, and distinguishes sounds/accents',
    () {
      final patterns = [
        for (final s in RhythmSound.values)
          RhythmPattern(bpm: 240, pulses: 1, rows: [hits(1, sound: s)]),
      ];
      final outputs = [for (final p in patterns) renderRhythm(p)];
      expect(outputs.map((b) => base64Encode(b)).toSet().length, 4);
      for (var i = 0; i < patterns.length; i++) {
        final bytes = outputs[i],
            data = ByteData.sublistView(bytes),
            cycle = rhythmCycleFrames(patterns[i]);
        expect(bytes.sublist(0, 4), ascii.encode('RIFF'));
        expect(data.getUint32(24, Endian.little), 22050);
        expect(data.getUint16(22, Endian.little), 1);
        expect((bytes.length - 44) ~/ 2 % cycle, 0);
        expect(renderRhythm(patterns[i]), bytes);
        expect(
          bytes.sublist(44, 44 + cycle * 2),
          bytes.sublist(44 + cycle * 2, 44 + cycle * 4),
        );
      }
      int peak(Uint8List b) {
        final d = ByteData.sublistView(b);
        var peak = 0;
        for (var i = 44; i < b.length; i += 2) {
          final v = d.getInt16(i, Endian.little).abs();
          if (v > peak) peak = v;
        }
        return peak;
      }

      final hit = hits(1), accent = hit.cycleHit([]);
      expect(
        peak(renderRhythm(RhythmPattern(rows: [accent]))),
        greaterThan(peak(renderRhythm(RhythmPattern(rows: [hit])))),
      );
      final dense = RhythmPattern(
        bpm: 240,
        pulses: 1,
        rows: List.generate(8, (_) => hits(16, sound: RhythmSound.snare)),
      );
      expect(peak(renderRhythm(dense)), lessThan(32767));
      expect(
        renderRhythm(RhythmPattern(rows: [])).skip(44).every((n) => n == 0),
        true,
      );
    },
  );
  test(
    'pattern JSON preserves arbitrary trees; invalid saved state is rejected',
    () {
      final pattern = RhythmPattern(
        bpm: 173,
        pulses: 7,
        rows: [
          hits(7),
          hits(11, sound: RhythmSound.hiHat).divide([4], 13),
        ],
      );
      final encoded = jsonEncode(pattern.toJson());
      expect(
        jsonEncode(RhythmPattern.fromJson(jsonDecode(encoded)).toJson()),
        encoded,
      );
      final bad = <void Function(Map<String, dynamic>)>[
        (d) => d['formatVersion'] = 2,
        (d) => d['bpm'] = 0,
        (d) => d['pulses'] = 0,
        (d) => d['rows'][0]['sound'] = 'sample',
        (d) => d['rows'][1]['id'] = d['rows'][0]['id'],
        (d) => d['rows'][0]['root'] = {
          'children': [
            {'hit': 0},
          ],
        },
        (d) => d['rows'][0]['root'] = {'hit': 3},
        (d) => d['rows'][0]['root'] = {
          'hit': 0,
          'children': [
            {'hit': 1},
            {'hit': 0},
          ],
        },
      ];
      for (final mutate in bad) {
        final d = jsonDecode(encoded) as Map<String, dynamic>;
        mutate(d);
        expect(() => RhythmPattern.fromJson(d), throwsFormatException);
      }
    },
  );
}
