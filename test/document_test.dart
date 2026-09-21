import 'dart:convert';
import 'package:test/test.dart';
import 'package:music_hub/document.dart';

void main() {
  test(
    'plain text round trips verbatim including spacing, blank lines and partial markers',
    () {
      const text =
          '[Intro]\nC       Em   Am Am\nWise men say\n       F         C      G G\n\n  {Am}\t🎸 café\n{unfinished\n';
      final song = SongDocument(title: 'An idea', text: text);
      final loaded = SongDocument.decode(song.encode(), 12);
      expect(loaded.text, text);
      expect(loaded.id, song.id);
      expect(loaded.arrangementId, song.arrangementId);
      expect(loaded.sheetId, song.sheetId);
      expect(loaded.revision, 12);
      expect(loaded.toJson()['formatVersion'], 2);
    },
  );
  test(
    'v1 songs and histories open without losing lyrics, chords or identities',
    () {
      final old = jsonEncode({
        'formatVersion': 1,
        'id': 'song',
        'arrangementId': 'arr',
        'sheetId': 'sheet',
        'title': 'Older song',
        'artist': '',
        'lines': [
          {
            'id': 'line1',
            'lyric': 'Sing with me',
            'chords': [
              {'offset': 0, 'name': 'Am'},
              {'offset': 10, 'name': 'G'},
              {'offset': 10, 'name': 'C/G'},
            ],
          },
          {'id': 'line2', 'lyric': '', 'chords': []},
          {'id': 'line3', 'lyric': '  🎸 ', 'chords': []},
        ],
      });
      final migrated = SongDocument.decode(old, 7);
      expect(migrated.text, '{Am}Sing with {G}{C/G}me\n\n  🎸 ');
      expect(migrated.id, 'song');
      expect(migrated.sheetId, 'sheet');
      expect(SongDocument.decode(migrated.encode(), 8).text, migrated.text);
      expect(jsonDecode(old)['formatVersion'], 1);
    },
  );
  test(
    'only explicit chord braces are decorated; ordinary lyrics remain plain',
    () {
      const text =
          '[Intro] C Em Am {Am} {C/G} {F♯m7} {lyrics here} {unfinished';
      expect(chordMarker.allMatches(text).map((m) => m.group(1)), [
        'Am',
        'C/G',
        'F♯m7',
      ]);
    },
  );
  test('unknown format is rejected without rewriting data', () {
    expect(
      () => SongDocument.decode('{"formatVersion":99}', 1),
      throwsFormatException,
    );
  });
}
