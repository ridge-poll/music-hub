import 'dart:io';
import 'package:test/test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:music_hub/audio_files.dart';
import 'package:music_hub/document.dart';
import 'package:music_hub/store.dart';

void main() {
  late Directory root;
  late MusicStore store;
  late AudioFiles files;
  setUpAll(sqfliteFfiInit);
  setUp(() async {
    root = await Directory.systemTemp.createTemp('music_audio_');
    files = AudioFiles(root);
    store = await MusicStore.open(
      factory: databaseFactoryFfi,
      location: '${root.path}/db.sqlite',
    );
  });
  tearDown(() async {
    await store.close();
    await root.delete(recursive: true);
  });
  Future<AudioDraft> captured({String? songId}) async {
    final draft = await files.createDraft(songId: songId);
    // Repository-level fixture: native media validation belongs to recorder UI.
    await files.draftAudio(draft).writeAsBytes([1, 8, 3, 6, 9]);
    draft.durationMs = 2000;
    return draft;
  }

  test(
    'save captures immutable content-addressed audio and survives restart',
    () async {
      final draft = await captured();
      await files.save(store, draft);
      expect(await files.pending(), isEmpty);
      await store.close();
      store = await MusicStore.open(
        factory: databaseFactoryFfi,
        location: '${root.path}/db.sqlite',
      );
      final entry = (await store.recordings()).single;
      expect(entry.id, draft.id);
      expect(entry.durationMs, 2000);
      expect(await files.resolve(entry.relativePath).readAsBytes(), [
        1,
        8,
        3,
        6,
        9,
      ]);
      expect(entry.relativePath, matches(r'^audio/objects/[0-9a-f]{64}\.m4a$'));
    },
  );
  test('same bytes share an asset but remain separate recordings', () async {
    await files.save(store, await captured());
    await files.save(store, await captured());
    expect(await store.recordings(), hasLength(2));
    expect(await store.db.query('audio_assets'), hasLength(1));
  });
  test(
    'failed SQL commit keeps recoverable draft and retry is idempotent',
    () async {
      final draft = await captured(songId: 'missing-song');
      await expectLater(
        files.save(store, draft),
        throwsA(isA<DatabaseException>()),
      );
      expect(await files.pending(), hasLength(1));
      expect(await files.draftAudio(draft).exists(), true);
      expect(await store.recordings(), isEmpty);
      draft.songId = null;
      await files.save(store, draft);
      final existing = (await store.recordings()).single;
      // Simulate process death after commit but before draft cleanup.
      await files.writeDraft(draft);
      await files
          .resolve(existing.relativePath)
          .copy(files.draftAudio(draft).path);
      await files.save(store, draft);
      expect(await store.recordings(), hasLength(1));
      expect(await files.pending(), isEmpty);
    },
  );
  test(
    'attachment changes use tombstoned relationship rows without changing audio',
    () async {
      final a = SongDocument(title: 'A');
      final b = SongDocument(title: 'B');
      await store.save(a);
      await store.save(b);
      final draft = await captured(songId: a.id);
      await files.save(store, draft);
      await store.attachRecording(draft.id, b.id);
      expect(await store.recordings(songId: a.id), isEmpty);
      expect((await store.recordings(songId: b.id)).single.songTitle, 'B');
      final links = await store.db.query('song_recordings');
      expect(links.where((l) => l['deleted'] == 1), hasLength(1));
      await store.attachRecording(draft.id, null);
      expect((await store.recordings()).single.songId, isNull);
      expect(await store.db.query('audio_assets'), hasLength(1));
    },
  );
  test(
    'version 1 database upgrades in place and keeps the existing song',
    () async {
      final song = SongDocument(title: 'Keep me', text: '  C    G\nwords\n');
      await store.save(song);
      final owner = await store.db.query(
        'settings',
        where: 'key = ?',
        whereArgs: ['owner_id'],
      );
      await store.db.execute('ALTER TABLE recordings DROP COLUMN duration_ms');
      await store.db.execute('ALTER TABLE recordings DROP COLUMN created_at');
      await store.db.execute('ALTER TABLE songs DROP COLUMN last_edited');
      await store.db.execute('ALTER TABLE songs DROP COLUMN edited_revision');
      await store.db.execute('PRAGMA user_version = 1');
      await store.close();
      store = await MusicStore.open(
        factory: databaseFactoryFfi,
        location: '${root.path}/db.sqlite',
      );
      expect((await store.list()).single.text, song.text);
      expect(
        await store.db.query(
          'settings',
          where: 'key = ?',
          whereArgs: ['owner_id'],
        ),
        owner,
      );
      await files.save(store, await captured());
      expect((await store.recordings()).single.durationMs, 2000);
    },
  );
  test(
    'empty or escaped audio paths are rejected without losing drafts',
    () async {
      final draft = await files.createDraft();
      await expectLater(
        files.save(store, draft),
        throwsA(isA<FileSystemException>()),
      );
      expect(await files.pending(), hasLength(1));
      expect(() => files.resolve('../outside.m4a'), throwsFormatException);
      expect(() => files.resolve('/tmp/outside.m4a'), throwsFormatException);
    },
  );
}
