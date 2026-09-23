import 'dart:convert';
import 'dart:math' as math;
import 'document.dart';

final blankTabBlock = [
  'e',
  'B',
  'G',
  'D',
  'A',
  'E',
].map((label) => '$label|${'-' * 62}|').join('\n');

/// Opaque authored text. No note, position or rhythm interpretation.
class TabDocument {
  TabDocument({
    String? id,
    required this.arrangementId,
    this.revision = 0,
    String? text,
    this.migrated = false,
  }) : id = id ?? ids.v4(),
       text = text ?? blankTabBlock;
  final String id, arrangementId;
  final bool migrated;
  int revision;
  String text;
  String encode() => jsonEncode({
    'formatVersion': 2,
    'id': id,
    'arrangementId': arrangementId,
    'text': text,
  });
  factory TabDocument.decode(String content, int revision) {
    final data = jsonDecode(content) as Map<String, dynamic>;
    final version = data['formatVersion'];
    if (version != 1 && version != 2) {
      throw const FormatException('Unsupported tab format');
    }
    return TabDocument(
      id: data['id'] as String,
      arrangementId: data['arrangementId'] as String,
      revision: revision,
      text: version == 2 ? data['text'] as String : _migrate(data),
      migrated: version == 1,
    );
  }
}

String _migrate(Map<String, dynamic> data) {
  final positions = data['positions'] as List;
  if (positions.isEmpty ||
      positions.length % 12 != 0 ||
      positions.map((p) => p['id']).toSet().length != positions.length) {
    throw const FormatException('Invalid tab positions');
  }
  final columns = positions.map((p) {
    final cells = (p['cells'] as List).cast<String>();
    if (cells.length != 6) throw const FormatException('Expected six rows');
    return cells;
  }).toList();
  final blocks = <String>[];
  final verbatim = <String>[];
  for (var start = 0; start < columns.length; start += 12) {
    final display = <List<String>>[];
    for (var c = start; c < start + 12; c++) {
      display.add(
        List.generate(6, (r) {
          final raw = columns[c][r];
          if (raw.contains(RegExp(r'[\r\n\t]'))) {
            final marker = '[cell ${c + 1}/${r + 1}]';
            verbatim.add(
              '$marker — original text follows:\n$raw\n[end cell ${c + 1}/${r + 1}]',
            );
            return marker;
          }
          return raw;
        }),
      );
    }
    final widths = display
        .map(
          (cells) => cells.fold<int>(
            3,
            (width, cell) => math.max(width, cell.runes.length + 2),
          ),
        )
        .toList();
    blocks.add(
      List.generate(6, (r) {
        final line = StringBuffer('${['e', 'B', 'G', 'D', 'A', 'E'][r]}|');
        for (var c = 0; c < 12; c++) {
          final cell = display[c][r];
          line.write(cell);
          line.write('-' * (widths[c] - cell.runes.length));
        }
        return '$line|';
      }).join('\n'),
    );
  }
  return [...blocks, ...verbatim].join('\n\n');
}
