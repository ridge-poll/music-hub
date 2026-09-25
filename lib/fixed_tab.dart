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

/// Six continuous strings, rendered in fixed-width visual chunks. Characters
/// remain opaque graphemes: this describes layout, not musical events.
class FixedTabLayout {
  FixedTabLayout(this.rows);
  factory FixedTabLayout.blank() => FixedTabLayout(
    List.generate(6, (_) => List.filled(tabColumns, '-', growable: true)),
  );
  final List<List<String>> rows;
  int get length => rows.first.length;
  int get blockCount => length ~/ tabColumns;
  bool get hasContent =>
      rows.any((row) => row.any((c) => c != '-' && c.trim().isNotEmpty));
  bool get lastBlockEmpty =>
      rows.every((row) => row.skip(length - tabColumns).every((c) => c == '-'));
  void appendBlock() {
    for (final row in rows) {
      row.addAll(List.filled(tabColumns, '-'));
    }
  }

  void ensurePosition(int position) {
    while (position >= length) {
      appendBlock();
    }
  }

  void removeLastBlock() {
    if (blockCount <= 1 || !lastBlockEmpty) return;
    final start = length - tabColumns;
    for (final row in rows) {
      row.removeRange(start, row.length);
    }
  }

  String render() => List.generate(
    blockCount,
    (b) => List.generate(6, (r) {
      final prefix = b == 0 ? '${tabLabels[r]}|' : '  ';
      final suffix = b == blockCount - 1 ? '|' : '';
      return '$prefix${rows[r].skip(b * tabColumns).take(tabColumns).join()}$suffix';
    }).join('\n'),
  ).join('\n\n');

  /// Accept the previous fixed blocks as well as the continuation rendering.
  /// Reject anything else rather than guessing where authored text belongs.
  static FixedTabLayout? read(String text) {
    final blocks = text.split('\n\n');
    final rows = List.generate(6, (_) => <String>[]);
    for (var b = 0; b < blocks.length; b++) {
      final lines = blocks[b].split('\n');
      if (lines.length != 6) return null;
      for (var r = 0; r < 6; r++) {
        final chars = lines[r].characters.toList();
        final oldPrefix = lines[r].startsWith('${tabLabels[r]}|');
        final continuation = b > 0 && lines[r].startsWith('  ');
        if (!oldPrefix && !continuation) return null;
        if (chars.length != tabColumns + 2 && chars.length != tabColumns + 3) {
          return null;
        }
        if (chars.length == tabColumns + 3 && chars.last != '|') return null;
        rows[r].addAll(chars.sublist(2, tabColumns + 2));
      }
    }
    return FixedTabLayout(rows);
  }

  /// Coordinates use UTF-16 for the platform caret and graphemes for slots.
  ({int row, int position}) locate(int offset) {
    var start = 0;
    final lines = render().split('\n');
    var lineIndex = 0;
    for (var b = 0; b < blockCount; b++) {
      for (var r = 0; r < 6; r++) {
        final line = lines[lineIndex++];
        if (offset <= start + line.length) {
          var point = start + 2;
          var c = 0;
          while (c < tabColumns && point < offset) {
            point += rows[r][b * tabColumns + c].length;
            c++;
          }
          return (row: r, position: b * tabColumns + c);
        }
        start += line.length + 1;
      }
      if (b < blockCount - 1) {
        start++;
        lineIndex++;
      }
    }
    return (row: 5, position: length);
  }

  int offsetFor(int row, int position) {
    final p = position.clamp(0, length);
    final block = p == length ? blockCount - 1 : p ~/ tabColumns;
    final column = p == length ? tabColumns : p % tabColumns;
    final lines = render().split('\n');
    final lineIndex = block * 7 + row;
    return lines
            .take(lineIndex)
            .fold<int>(0, (n, line) => n + line.length + 1) +
        2 +
        rows[row].skip(block * tabColumns).take(column).join().length;
  }

  void clearSelection(int start, int end) {
    if (start >= end) return;
    // Gather original UTF-16 offsets before changing any grapheme widths.
    final selected = <(int, int)>[];
    var offset = 0;
    for (var b = 0; b < blockCount; b++) {
      for (var r = 0; r < 6; r++) {
        offset += 2;
        for (var c = 0; c < tabColumns; c++) {
          final p = b * tabColumns + c;
          if (offset >= start && offset < end) selected.add((r, p));
          offset += rows[r][p].length;
        }
        offset += 1 + (b == blockCount - 1 ? 1 : 0);
      }
      offset++;
    }
    for (final (r, p) in selected) {
      rows[r][p] = '-';
    }
  }
}

/// Deliberately narrow paste support: complete labeled six-row ASCII blocks.
/// No chord, pitch, technique, rhythm or annotation parser.
List<List<String>>? asciiPasteRows(String text) {
  final blocks = text
      .replaceAll('\r\n', '\n')
      .replaceFirst(RegExp(r'\n+$'), '')
      .split(RegExp(r'\n\s*\n'));
  final result = List.generate(6, (_) => <String>[]);
  for (final block in blocks) {
    final lines = block.split('\n');
    if (lines.length != 6) return null;
    final rows = <List<String>>[];
    for (var r = 0; r < 6; r++) {
      if (!lines[r].startsWith('${tabLabels[r]}|')) return null;
      var body = lines[r].substring(2);
      if (body.endsWith('|')) body = body.substring(0, body.length - 1);
      rows.add(body.characters.toList());
    }
    final width = rows.fold<int>(
      0,
      (n, row) => row.length > n ? row.length : n,
    );
    for (var r = 0; r < 6; r++) {
      result[r].addAll(rows[r]);
      result[r].addAll(List.filled(width - rows[r].length, '-'));
    }
  }
  return result;
}
