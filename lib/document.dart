import 'dart:convert';
import 'package:uuid/uuid.dart';

const ids = Uuid();

// The user's text is the document. Whitespace, section labels and unfinished
// chord markers are literal content; presentation never rewrites this string.
class SongDocument {
  SongDocument({
    String? id,
    String? arrangementId,
    String? sheetId,
    this.title = '',
    this.artist = '',
    this.revision = 0,
    this.text = '',
  }) : id = id ?? ids.v4(),
       arrangementId = arrangementId ?? ids.v4(),
       sheetId = sheetId ?? ids.v4();
  final String id;
  final String arrangementId;
  final String sheetId;
  String title;
  String artist;
  String text;
  int revision;
  // Song-row metadata and component summaries are separate from sheet content.
  String lastEdited = '';
  int editedRevision = 0;
  bool hasTab = false, hasNotes = false;
  int recordingCount = 0;
  List<String> get components => [
    if (text.trim().isNotEmpty) 'Chords/Lyrics',
    if (hasTab) 'Tab',
    if (hasNotes) 'Notes',
    if (recordingCount > 0) 'Recordings',
  ];
  bool get isBlank =>
      title.trim().isEmpty && artist.trim().isEmpty && text.trim().isEmpty;

  Map<String, dynamic> toJson() => {
    'formatVersion': 2,
    'id': id,
    'arrangementId': arrangementId,
    'sheetId': sheetId,
    'title': title,
    'artist': artist,
    'text': text,
  };
  String encode() => jsonEncode(toJson());
  factory SongDocument.decode(String content, int revision) {
    final json = jsonDecode(content) as Map<String, dynamic>;
    final version = json['formatVersion'];
    if (version != 1 && version != 2) {
      throw const FormatException('Unsupported document version');
    }
    return SongDocument(
      id: json['id'],
      arrangementId: json['arrangementId'],
      sheetId: json['sheetId'],
      title: json['title'],
      artist: json['artist'],
      revision: revision,
      text: version == 2
          ? json['text'] as String
          : _legacyText(json['lines'] as List),
    );
  }
}

// Lazy content migration for current legacy documents.
// Inserting a marker at the old UTF-16 anchor preserves every original lyric
// character and chord, including repeated chords at the same position.
String _legacyText(List lines) => lines
    .map((value) {
      final line = value as Map<String, dynamic>;
      final lyric = line['lyric'] as String;
      final chords = (line['chords'] as List).asMap().entries.toList()
        ..sort((a, b) {
          final order = (a.value['offset'] as int).compareTo(
            b.value['offset'] as int,
          );
          return order == 0 ? a.key.compareTo(b.key) : order;
        });
      final output = StringBuffer();
      var cursor = 0;
      for (final entry in chords) {
        final chord = entry.value;
        final offset = (chord['offset'] as int).clamp(cursor, lyric.length);
        output.write(lyric.substring(cursor, offset));
        output.write('{${chord['name']}}');
        cursor = offset;
      }
      output.write(lyric.substring(cursor));
      return output.toString();
    })
    .join('\n');

// Only explicit chord-like braces are decorated. Ordinary prose in braces and
// [Intro] / [Verse] remain literal text; no ChordPro directives are interpreted.
final chordMarker = RegExp(r'\{([A-G](?:#|b|♯|♭)?[^{}\s\r\n]{0,23})\}');
