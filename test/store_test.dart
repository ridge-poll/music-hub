import 'dart:io';

import 'package:test/test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:music_hub/document.dart';
import 'package:music_hub/store.dart';

void main() {
  late Directory temporary;
  late MusicStore store;
  late String location;
  setUpAll(sqfliteFfiInit);
  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('music_hub_test_');
    location = '${temporary.path}/library.sqlite';
    store = await MusicStore.open(
      factory: databaseFactoryFfi,
      location: location,
    );
  });
  tearDown(() async {
    await store.close();
    await temporary.delete(recursive: true);
  });

  test(
    'save, close database, reopen and edit retains identity and monotonic revisions',
    () async {
      final song = SongDocument(
        title: 'Porch light',
        lines: [
          LyricLine(lyric: 'Take the long way', chords: [Chord(0, 'D')]),
        ],
      );
      expect(await store.save(song), true);
      final firstRevision = song.revision;
      await store.close();
      store = await MusicStore.open(
        factory: databaseFactoryFfi,
        location: location,
      );
      final reopened = (await store.list()).single;
      expect(reopened.encode(), song.encode());
      reopened.lines.first.edit('Take the long way home');
      expect(await store.save(reopened), true);
      expect(reopened.revision, greaterThan(firstRevision));
      expect((await store.db.query('arrangements')).length, 1);
      expect((await store.db.query('song_arrangements')).length, 1);
      expect((await store.history(song.sheetId)).length, 2);
      expect((await store.db.query('candidates')), isEmpty);
    },
  );

  test('overlapping edit cannot silently replace current document', () async {
    final original = SongDocument(title: 'Original');
    await store.save(original);
    final a = SongDocument.decode(original.encode(), original.revision);
    final b = SongDocument.decode(original.encode(), original.revision);
    a.title = 'First edit';
    b.title = 'Second edit';
    await store.save(a);
    expect(await store.save(b), false);
    expect((await store.list()).single.title, 'First edit');
    final history = await store.history(b.sheetId);
    expect(history.first.conflict, true);
    expect(SongDocument.decode(history.first.content, 0).title, 'Second edit');
    expect(history.map((v) => v.revision).toSet().length, 3);
  });

  test(
    'a failed transaction never creates a partial song or advances caller revision',
    () async {
      final song = SongDocument(title: 'Existing');
      await store.save(song);
      final bad = SongDocument(id: song.id, title: 'Duplicate ID');
      await expectLater(store.save(bad), throwsA(isA<DatabaseException>()));
      expect(bad.revision, 0);
      expect((await store.list()).single.title, 'Existing');
      expect((await store.db.query('arrangements')).length, 1);
    },
  );
}
