import 'package:characters/characters.dart';

const tabColumns = 40;
const tabLabels = ['e', 'B', 'G', 'D', 'A', 'E'];
String blankFixedBlock() =>
    tabLabels.map((s) => '$s|${'-' * tabColumns}|').join('\n');

/// Recognize only six-row ASCII layout, never musical notation. Long rows
/// continue in later blocks; everything outside that layout remains verbatim.
(String, String) fitLegacyTab(String source) {
  final lines = source.split('\n');
  final blocks = <String>[];
  final annotations = <String>[];
  for (var i = 0; i < lines.length;) {
    final rows = <String>[];
    if (i + 6 <= lines.length) {
      for (var r = 0; r < 6; r++) {
        final line = lines[i + r];
        if (!line.startsWith('${tabLabels[r]}|') || !line.endsWith('|')) break;
        rows.add(line.substring(2, line.length - 1));
      }
    }
    if (rows.length != 6) {
      annotations.add(lines[i++]);
      continue;
    }
    final cells = rows.map((row) => row.characters.toList()).toList();
    final length = cells.fold<int>(
      tabColumns,
      (n, row) => row.length > n ? row.length : n,
    );
    for (var start = 0; start < length; start += tabColumns) {
      blocks.add(
        List.generate(6, (r) {
          final body = List.generate(
            tabColumns,
            (c) => start + c < cells[r].length ? cells[r][start + c] : '-',
          ).join();
          return '${tabLabels[r]}|$body|';
        }).join('\n'),
      );
    }
    i += 6;
  }
  return (
    blocks.isEmpty ? blankFixedBlock() : blocks.join('\n\n'),
    annotations.join('\n'),
  );
}
