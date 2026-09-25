import 'dart:io';
import 'package:test/test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:music_hub/document.dart';
import 'package:music_hub/note.dart';
import 'package:music_hub/tab_document.dart';
import 'package:music_hub/store.dart';

void main() {
  late Directory root;
  late MusicStore store;
  setUpAll(sqfliteFfiInit);
  setUp(() async {
    root = await Directory.systemTemp.createTemp('song_store_');
    store = await MusicStore.open(
      factory: databaseFactoryFfi,
      location: '${root.path}/db.sqlite',
    );
  });
  tearDown(() async {
    await store.close();
    await root.delete(recursive: true);
  });
  test(
    'only actual edits reorder Songs; visits and no-op saves preserve lastEdited',
    () async {
      final a = SongDocument(title: 'First'), b = SongDocument(title: 'Second');
      await store.save(a);
      await store.save(b);
      final first = (await store.list()).last;
      final tab = await store.loadTab(a.arrangementId);
      await store.songNote(a);
      await store.save(a);
      expect((await store.list()).map((s) => s.id), [b.id, a.id]);
      expect((await store.list()).last.lastEdited, first.lastEdited);
      tab.text = tab.text.replaceRange(3, 4, '7');
      await store.saveTab(tab, song: a);
      var changed = (await store.list()).first;
      expect(changed.id, a.id);
      expect(changed.hasTab, true);
      expect(changed.editedRevision, greaterThan(first.editedRevision));
      await store.saveTab(tab, song: a);
      expect((await store.list()).first.lastEdited, changed.lastEdited);
      final note = MusicNote(songId: b.id, text: 'Try capo 2');
      await store.saveNote(note, song: b);
      expect((await store.list()).first.id, b.id);
      changed = (await store.list()).first;
      await store.saveNote(note, song: b);
      expect((await store.list()).first.editedRevision, changed.editedRevision);
      await store.saveRecording(
        id: 'r',
        title: 'Take',
        hash: 'hash',
        relativePath: 'r.m4a',
        durationMs: 1000,
        createdAt: '',
      );
      await store.attachRecording('r', a.id);
      changed = (await store.list()).first;
      expect(changed.id, a.id);
      expect(changed.recordingCount, 1);
      await store.attachRecording('r', a.id);
      expect((await store.list()).first.lastEdited, changed.lastEdited);
      await store.deleteRecording('r');
      expect(
        (await store.list()).first.editedRevision,
        greaterThan(changed.editedRevision),
      );
      expect((await store.list()).first.recordingCount, 0);
    },
  );
  test(
    'child and new Song commit atomically; duplicate notes cannot lose content',
    () async {
      final song = SongDocument();
      final note = MusicNote(songId: song.id, text: '  Idea\n');
      expect(await store.saveNote(note, song: song), true);
      expect((await store.list()).single.components, ['Notes']);
      final revision = song.revision;
      final changed = SongDocument.decode(song.encode(), song.revision)
        ..title = 'Must roll back';
      await expectLater(
        store.saveNote(
          MusicNote(songId: song.id, text: 'second'),
          song: changed,
        ),
        throwsStateError,
      );
      expect((await store.list()).single.title, isEmpty);
      expect(changed.revision, revision);
      expect((await store.notes()).single.text, '  Idea\n');
      final another = SongDocument();
      await expectLater(
        store.saveTab(
          TabDocument(arrangementId: song.arrangementId),
          song: another,
        ),
        throwsArgumentError,
      );
      expect((await store.list()).length, 1);
    },
  );
  test(
    'v3 note migration preserves every title/body and recording; repeated open is inert',
    () async {
      final song = SongDocument(title: 'Existing');
      await store.save(song);
      final standalone = MusicNote(title: 'Loose idea', text: '  standalone\n');
      final n1 = MusicNote(title: 'One', text: '  first\n', songId: song.id);
      final n2 = MusicNote(title: 'Two', text: 'second');
      await store.saveNote(standalone);
      await store.saveNote(n1);
      await store.saveNote(n2);
      // Reproduce the old multi-note relationship before upgrading.
      final link = (await store.db.query('song_notes')).single;
      await store.db.insert('song_notes', {
        ...link,
        'id': 'second-link',
        'note_id': n2.id,
      });
      await store.saveRecording(
        id: 'r',
        title: 'Keep audio',
        hash: 'hash',
        relativePath: 'r.m4a',
        durationMs: 1000,
        createdAt: '',
        songId: song.id,
      );
      await store.db.execute('ALTER TABLE songs DROP COLUMN created_at');
      await store.db.execute('ALTER TABLE songs DROP COLUMN last_edited');
      await store.db.execute('ALTER TABLE songs DROP COLUMN edited_revision');
      await store.db.setVersion(3);
      await store.close();
      store = await MusicStore.open(
        factory: databaseFactoryFfi,
        location: '${root.path}/db.sqlite',
      );
      final songs = await store.list();
      expect(songs.length, 2);
      expect(songs.every((s) => s.lastEdited.isEmpty), true);
      final loose = songs.singleWhere((s) => s.title == 'Loose idea');
      expect((await store.songNote(loose)).text, standalone.text);
      final merged = await store.songNote(song);
      expect(merged.text, contains('One\n  first\n'));
      expect(merged.text, contains('Two\nsecond'));
      expect((await store.notes(songId: song.id)).length, 1);
      expect((await store.recordings()).single.songId, song.id);
      final before = songs.map((s) => s.editedRevision).toList();
      await store.close();
      store = await MusicStore.open(
        factory: databaseFactoryFfi,
        location: '${root.path}/db.sqlite',
      );
      expect((await store.songNote(song)).text, merged.text);
      expect((await store.list()).map((s) => s.editedRevision), before);
    },
  );
}
