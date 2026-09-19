import 'dart:convert';

import 'package:uuid/uuid.dart';

const ids = Uuid();

class Chord {
  Chord(this.offset, this.name);
  int offset;
  String name;
  Map<String, dynamic> toJson() => {'offset': offset, 'name': name};
}

class LyricLine {
  LyricLine({String? id, this.lyric = '', List<Chord>? chords})
    : id = id ?? ids.v4(),
      chords = chords ?? [];
  final String id;
  String lyric;
  final List<Chord> chords;

  // Offsets use Dart/TextEditingValue UTF-16 units, not bytes or pixels.
  // Preserve anchors around an edit; anchors in replaced text land at its start.
  void edit(String next) {
    var prefix = 0;
    while (prefix < lyric.length &&
        prefix < next.length &&
        lyric.codeUnitAt(prefix) == next.codeUnitAt(prefix)) {
      prefix++;
    }
    var suffix = 0;
    while (suffix < lyric.length - prefix &&
        suffix < next.length - prefix &&
        lyric.codeUnitAt(lyric.length - suffix - 1) ==
            next.codeUnitAt(next.length - suffix - 1)) {
      suffix++;
    }
    final oldEnd = lyric.length - suffix;
    for (final chord in chords) {
      if (chord.offset >= oldEnd) {
        chord.offset += next.length - lyric.length;
      } else if (chord.offset > prefix) {
        chord.offset = prefix;
      }
      chord.offset = chord.offset.clamp(0, next.length);
    }
    lyric = next;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'lyric': lyric,
    'chords': chords.map((c) => c.toJson()).toList(),
  };
  factory LyricLine.fromJson(Map<String, dynamic> json) => LyricLine(
    id: json['id'] as String,
    lyric: json['lyric'] as String,
    chords: (json['chords'] as List)
        .map((c) => Chord(c['offset'] as int, c['name'] as String))
        .toList(),
  );
}

class SongDocument {
  SongDocument({
    String? id,
    String? arrangementId,
    String? sheetId,
    this.title = '',
    this.artist = '',
    this.revision = 0,
    List<LyricLine>? lines,
  }) : id = id ?? ids.v4(),
       arrangementId = arrangementId ?? ids.v4(),
       sheetId = sheetId ?? ids.v4(),
       lines = lines ?? [LyricLine()];
  final String id;
  final String arrangementId;
  final String sheetId;
  String title;
  String artist;
  int revision;
  final List<LyricLine> lines;
  Map<String, dynamic> toJson() => {
    'formatVersion': 1,
    'id': id,
    'arrangementId': arrangementId,
    'sheetId': sheetId,
    'title': title,
    'artist': artist,
    'lines': lines.map((l) => l.toJson()).toList(),
  };
  String encode() => jsonEncode(toJson());
  factory SongDocument.decode(String content, int revision) {
    final json = jsonDecode(content) as Map<String, dynamic>;
    if (json['formatVersion'] != 1) {
      throw const FormatException('Unsupported document version');
    }
    return SongDocument(
      id: json['id'],
      arrangementId: json['arrangementId'],
      sheetId: json['sheetId'],
      title: json['title'],
      artist: json['artist'],
      revision: revision,
      lines: (json['lines'] as List).map((l) => LyricLine.fromJson(l)).toList(),
    );
  }
}

// ChordPro is an interchange representation, never the stored source of truth.
String exportChordPro(SongDocument song) {
  final result = StringBuffer(
    '{title: ${song.title}}\n{artist: ${song.artist}}\n',
  );
  for (final line in song.lines) {
    final chords = [...line.chords]
      ..sort((a, b) => a.offset.compareTo(b.offset));
    var cursor = 0;
    for (final chord in chords) {
      final offset = chord.offset.clamp(cursor, line.lyric.length);
      result.write(line.lyric.substring(cursor, offset));
      result.write('[${chord.name}]');
      cursor = offset;
    }
    result.writeln(line.lyric.substring(cursor));
  }
  return result.toString();
}
