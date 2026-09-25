import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:test/test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:music_hub/audio_files.dart';
import 'package:music_hub/backup_service.dart';
import 'package:music_hub/document.dart';
import 'package:music_hub/library_bundle.dart';
import 'package:music_hub/note.dart';
import 'package:music_hub/store.dart';
import 'package:music_hub/tab_document.dart';
import 'package:music_hub/text_portability.dart';

void main() {
  late Directory root;
  late MusicStore store;
  late AudioFiles files;
  late BackupService service;
  setUpAll(sqfliteFfiInit);
  setUp(() async {
    root = await Directory.systemTemp.createTemp('portability_');
    store = await MusicStore.open(
      factory: databaseFactoryFfi,
      location: '${root.path}/library.db',
    );
    files = AudioFiles(root);
    service = BackupService(store, files);
  });
  tearDown(() async {
    await store.close();
    await root.delete(recursive: true);
  });
  Future<SongDocument> seed() async {
    final song = SongDocument(
      title: 'Été / idea',
      artist: 'Me',
      text: '[Verse]\n  {Am}Hello  world\n',
    );
    await store.save(song);
    final tab = TabDocument(
      arrangementId: song.arrangementId,
      text: blankTabBlock.replaceFirst('---', '7h9'),
      annotations: 'odd :) spacing  ',
    );
    await store.saveTab(tab, song: song);
    await store.saveNote(
      MusicNote(songId: song.id, title: 'Notes', text: 'Remember\n  this'),
      song: song,
    );
    for (var i = 0; i < 3; i++) {
      final draft = await files.createDraft(songId: i < 2 ? song.id : null);
      draft.durationMs = 1200 + i;
      await files.draftAudio(draft).writeAsBytes([1, 2, 3, i]);
      await files.save(store, draft);
    }
    await store.setSetting('dark_mode', 'true');
    await store.setSetting(
      'metronome',
      '{"bpm":90,"beats":3,"unit":4,"accents":[2,0,1]}',
    );
    return song;
  }

  Future<File> backup() async =>
      service.create(await root.createTemp('archives-'));
  Map<String, dynamic> logical(LibraryBundle b) {
    final data = jsonDecode(jsonEncode(b.data)) as Map<String, dynamic>;
    data.remove('createdAt');
    for (final r in data['recordings'] as List) {
      r.remove('relativePath');
    }
    (data['songs'] as List).sort(
      (a, b) => (a['id'] as String).compareTo(b['id']),
    );
    (data['recordings'] as List).sort(
      (a, b) => (a['id'] as String).compareTo(b['id']),
    );
    return data;
  }

  Future<File> altered(File source, void Function(Archive) edit) async {
    final archive = ZipDecoder().decodeBytes(await source.readAsBytes());
    edit(archive);
    return File(
      '${root.path}/changed.zip',
    ).writeAsBytes(ZipEncoder().encode(archive));
  }

  void modifyManifest(
    Archive archive,
    void Function(Map<String, dynamic>) edit,
  ) {
    final original = archive.findFile('MusicHub Backup/library.json')!;
    final data =
        jsonDecode(utf8.decode(original.content)) as Map<String, dynamic>;
    edit(data);
    archive.removeFile(original);
    archive.addFile(ArchiveFile.string(original.name, jsonEncode(data)));
  }

  test(
    'readable ZIP round trip preserves IDs, text, dates, preferences, and recordings',
    () async {
      final song = await seed();
      final before = await store.snapshot();
      final zip = await backup();
      final archive = ZipDecoder().decodeBytes(await zip.readAsBytes());
      expect(
        utf8.decode(
          archive
              .findFile('MusicHub Backup/songs/${song.id}/chords.txt')!
              .content,
        ),
        song.text,
      );
      expect(archive.files.any((f) => f.name.endsWith('.sqlite')), false);
      final extra = SongDocument(title: 'Will be replaced');
      await store.save(extra);
      final prepared = await service.prepare(zip);
      expect(
        (await store.list()).length,
        2,
      ); // preparation never modifies library
      await service.restore(prepared);
      expect(logical(await store.snapshot()), logical(before));
      final takes = await store.recordings();
      expect(takes.where((r) => r.songId == song.id).length, 2);
      expect(takes.where((r) => r.songId == null).length, 1);
      for (final r in takes) {
        expect(await files.resolve(r.relativePath).length(), 4);
      }
      await service.restore(prepared); // repeat replace, never duplicate
      expect(logical(await store.snapshot()), logical(before));
      final loaded = (await store.list()).single;
      loaded.text += 'edit';
      await store.save(loaded);
      expect(
        (await store.list()).single.editedRevision,
        greaterThan(before.songs.single['editOrder'] as int),
      );
      await prepared.dispose();
    },
  );
  test(
    'restores into another library with a different owner and stable identities',
    () async {
      await seed();
      final before = await store.snapshot();
      final zip = await backup();
      final targetRoot = await Directory('${root.path}/target').create();
      final target = await MusicStore.open(
        factory: databaseFactoryFfi,
        location: '${targetRoot.path}/db',
      );
      try {
        final other = BackupService(target, AudioFiles(targetRoot));
        final staged = await other.prepare(zip);
        await other.restore(staged);
        expect(logical(await target.snapshot()), logical(before));
        await staged.dispose();
      } finally {
        await target.close();
      }
    },
  );
  test('invalid archives cannot mutate live content', () async {
    final song = await seed();
    final zip = await backup();
    final before = logical(await store.snapshot());
    final cases = <void Function(Archive)>[
      (a) => a.addFile(ArchiveFile.string('../escape', 'oops')),
      (a) => a.addFile(ArchiveFile.string('MusicHub Backup/extra.txt', 'oops')),
      (a) => modifyManifest(a, (m) => m['formatVersion'] = 99),
      (a) {
        a.findFile('MusicHub Backup/library.json')!.mode = 0xa1ff;
      },
      (a) => modifyManifest(a, (m) => m['songs'].add(m['songs'].first)),
      (a) => modifyManifest(a, (m) => m['recordings'][0]['songId'] = 'missing'),
      (a) =>
          modifyManifest(a, (m) => m['songs'][0]['lastEdited'] = 'not-a-date'),
      (a) => modifyManifest(a, (m) => m['settings']['dark_mode'] = 'invalid'),
      (a) {
        final f = a.findFile('MusicHub Backup/songs/${song.id}/chords.txt')!;
        a.removeFile(f);
        a.addFile(ArchiveFile.string(f.name, 'corrupt'));
      },
      (a) {
        a.removeFile(a.files.firstWhere((f) => f.name.endsWith('.m4a')));
      },
      (a) => modifyManifest(
        a,
        (m) => m['songs'][0]['tab'] = {'file': '../../outside'},
      ),
    ];
    for (final change in cases) {
      await expectLater(
        service.prepare(await altered(zip, change)),
        throwsA(anything),
      );
      expect(logical(await store.snapshot()), before);
    }
    // Build duplicate ZIP entries directly; Archive itself coalesces names.
    final original = ZipDecoder().decodeBytes(await zip.readAsBytes());
    final output = OutputMemoryStream();
    final encoder = ZipEncoder()..startEncode(output);
    for (final file in original.files) {
      encoder.add(file);
    }
    encoder.add(
      ArchiveFile.string('MusicHub Backup/library.json', 'duplicate'),
    );
    encoder.endEncode();
    final duplicate = await File(
      '${root.path}/duplicate.zip',
    ).writeAsBytes(output.getBytes());
    await expectLater(service.prepare(duplicate), throwsFormatException);
    expect(logical(await store.snapshot()), before);
  });
  test(
    'SQL failure rolls back replacement and removes newly installed audio',
    () async {
      await seed();
      final zip = await backup();
      final prepared = await service.prepare(zip);
      final current = SongDocument(title: 'Keep me');
      await store.save(current);
      final before = logical(await store.snapshot());
      await store.db.execute(
        "CREATE TRIGGER fail_restore BEFORE UPDATE ON recordings BEGIN SELECT RAISE(ABORT, 'test failure'); END",
      );
      await expectLater(service.restore(prepared), throwsA(anything));
      expect(logical(await store.snapshot()), before);
      expect(
        await Directory('${root.path}/audio/restored').list().toList(),
        isEmpty,
      );
      await prepared.dispose();
    },
  );
  test(
    'changed staged audio and unfinished drafts block restore safely',
    () async {
      await seed();
      final zip = await backup();
      final before = logical(await store.snapshot());
      final staged = await service.prepare(zip);
      await File(
        '${staged.directory.path}/${staged.bundle.recordings.first['audioPath']}',
      ).writeAsString('damaged');
      await expectLater(service.restore(staged), throwsFormatException);
      expect(logical(await store.snapshot()), before);
      final draft = await files.createDraft();
      await expectLater(backup(), throwsFormatException);
      await expectLater(service.prepare(zip), throwsFormatException);
      await files.discard(draft);
      await staged.dispose();
    },
  );
  test('empty library round trip and deleted items stay deleted', () async {
    final song = await seed();
    for (final r in await store.recordings()) {
      await store.deleteRecording(r.id);
    }
    await store.deleteSong(song.id);
    final zip = await backup();
    final staged = await service.prepare(zip);
    expect(staged.bundle.songs, isEmpty);
    expect(staged.bundle.recordings, isEmpty);
    await service.restore(staged);
    expect(await store.list(), isEmpty);
    expect(await store.recordings(), isEmpty);
    await staged.dispose();
  });
  test(
    'audio import preserves bytes and extension, deduplicates, and rejects empties',
    () async {
      final source = await File(
        '${root.path}/source.wav',
      ).writeAsBytes([5, 9, 2, 1]);
      await files.importAudio(
        store,
        source,
        title: 'Imported',
        durationMs: 2300,
      );
      await files.importAudio(store, source, title: 'Again', durationMs: 2300);
      final rows = await store.recordings();
      expect(rows.length, 2);
      expect(rows.first.relativePath, endsWith('.wav'));
      expect(await files.resolve(rows.first.relativePath).readAsBytes(), [
        5,
        9,
        2,
        1,
      ]);
      expect(await store.db.query('audio_assets'), hasLength(1));
      await source.writeAsBytes([]);
      await expectLater(
        files.importAudio(store, source, title: 'empty', durationMs: 1),
        throwsFormatException,
      );
      expect(await store.recordings(), hasLength(2));
    },
  );
  test(
    'larger library stays ordered and reads do not change dates or revisions',
    () async {
      for (var i = 0; i < 500; i++) {
        await store.save(SongDocument(title: 'Song $i', text: 'line $i'));
      }
      final first = await store.list();
      final bundle = await store.snapshot();
      final second = await store.list();
      expect(first.first.title, 'Song 499');
      expect(bundle.songs, hasLength(500));
      expect(
        second.map((s) => [s.id, s.lastEdited, s.editedRevision, s.createdAt]),
        first.map((s) => [s.id, s.lastEdited, s.editedRevision, s.createdAt]),
      );
    },
  );
  test(
    'v4 migration preserves existing data without inventing old creation dates',
    () async {
      final song = SongDocument(title: 'Existing', text: 'keep');
      await store.save(song);
      final before = (await store.list()).single;
      await store.db.execute('ALTER TABLE songs DROP COLUMN created_at');
      await store.db.setVersion(4);
      await store.close();
      store = await MusicStore.open(
        factory: databaseFactoryFfi,
        location: '${root.path}/library.db',
      );
      final after = (await store.list()).single;
      expect(after.createdAt, '');
      expect(after.lastEdited, before.lastEdited);
      expect(after.text, 'keep');
      await store.save(SongDocument(title: 'New'));
      expect(
        DateTime.tryParse((await store.list()).first.createdAt),
        isNotNull,
      );
    },
  );
  test(
    'plain text stays exact; small ChordPro subset preserves unknown directives',
    () {
      const source = '  Hello\n C    G\n\n';
      expect(importSongText(source, filename: 'Song').text, source);
      final song = importSongText(
        '{title: My song}\n{artist: Me}\n{soc}\n[Am]Hi [G/B]you\n{eoc}\n{custom: keep}\n[Intro]',
        filename: 'file',
        chordPro: true,
      );
      expect(song.title, 'My song');
      expect(song.artist, 'Me');
      expect(song.text, '[Chorus]\n{Am}Hi {G/B}you\n{custom: keep}\n[Intro]');
      expect(importSongText('  \n', filename: 'Empty').isBlank, true);
      expect(safeFilename('../a/b'), '_a_b');
      expect(
        exportTabText(' e|---|', '  annotation'),
        ' e|---|\n\n  annotation',
      );
    },
  );
}
