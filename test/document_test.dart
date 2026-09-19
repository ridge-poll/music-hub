import 'package:test/test.dart';
import 'package:music_hub/document.dart';

void main() {
  test('lyric edits shift anchors and clamp chords inside removed text', () {
    final line = LyricLine(
      lyric: 'hello world',
      chords: [Chord(0, 'C'), Chord(6, 'G')],
    );
    line.edit('oh hello world');
    expect(line.chords.map((c) => c.offset), [3, 9]);
    line.edit('oh world');
    expect(line.chords.map((c) => c.offset), [3, 3]);
    line.edit('');
    expect(line.chords.map((c) => c.offset), [0, 0]);
  });
  test(
    'native serialization retains IDs, unicode, anchors and clean authored content',
    () {
      final song = SongDocument(
        title: 'An idea 🎸',
        lines: [
          LyricLine(
            lyric: 'Sing with me',
            chords: [Chord(0, 'Am'), Chord(10, 'G')],
          ),
        ],
      );
      final restored = SongDocument.decode(song.encode(), 4);
      expect(restored.id, song.id);
      expect(restored.arrangementId, song.arrangementId);
      expect(restored.lines.first.id, song.lines.first.id);
      expect(restored.toJson(), song.toJson());
      expect(restored.revision, 4);
      expect(exportChordPro(restored), contains('[Am]Sing with [G]me'));
      expect(restored.toJson().containsKey('confidence'), false);
    },
  );
}
