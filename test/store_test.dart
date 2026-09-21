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
        text: '{D}Take the long way',
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
      reopened.text += ' home';
      expect(await store.save(reopened), true);
      expect(reopened.revision, greaterThan(firstRevision));
      expect((await store.db.query('arrangements')).length, 1);
      expect((await store.db.query('song_arrangements')).length, 1);
      expect(
        await store.db.rawQuery(
          "SELECT name FROM sqlite_master WHERE name='document_versions'",
        ),
        isEmpty,
      );
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
    expect(b.title, 'Second edit');
  });

  test(
    'delete song keeps recordings unattached and stale saves cannot resurrect it',
    () async {
      final song = SongDocument(title: 'Delete me');
      await store.save(song);
      await store.saveRecording(
        id: 'take',
        title: 'Take',
        hash: 'hash',
        relativePath: 'audio.m4a',
        durationMs: 1000,
        createdAt: '',
        songId: song.id,
      );
      await store.deleteSong(song.id);
      expect(await store.list(), isEmpty);
      expect(await store.save(song), false);
      expect((await store.recordings()).single.songId, isNull);
      await store.deleteRecording('take');
      expect(await store.recordings(), isEmpty);
      expect((await store.db.query('recordings')).single['deleted'], 1);
      expect((await store.db.query('song_recordings')).single['deleted'], 1);
    },
  );

  test(
    'version 2 migration drops history and preserves current song',
    () async {
      final song = SongDocument(title: 'Keep me', text: 'Latest');
      await store.save(song);
      await store.db.execute('CREATE TABLE document_versions (content TEXT)');
      await store.db.execute(
        "INSERT INTO document_versions VALUES ('old history')",
      );
      await store.db.setVersion(2);
      await store.close();
      store = await MusicStore.open(
        factory: databaseFactoryFfi,
        location: location,
      );
      expect((await store.list()).single.text, 'Latest');
      expect(
        await store.db.rawQuery(
          "SELECT name FROM sqlite_master WHERE name='document_versions'",
        ),
        isEmpty,
      );
      expect(await store.db.getVersion(), 3);
    },
  );

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
