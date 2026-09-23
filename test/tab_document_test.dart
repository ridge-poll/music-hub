import 'dart:io';
import 'dart:convert';
import 'package:test/test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:music_hub/document.dart';
import 'package:music_hub/tab_document.dart';
import 'package:music_hub/store.dart';

void main() {
  test('plain text round trips without normalization', () {
    final tab = TabDocument(arrangementId: 'arrangement');
    expect(tab.text, blankTabBlock);
    tab.text = '  0h2  3/5 7\\6 :) 🎸\r\n\t spaced  \n';
    final copy = TabDocument.decode(tab.encode(), 7);
    expect(copy.text, tab.text);
    expect(copy.encode(), tab.encode());
    expect(copy.revision, 7);
  });
  test(
    'legacy grids migrate every cell, including multiline verbatim content',
    () {
      final cells = List.generate(24, (_) => List.filled(6, ''));
      const values = [
        '0h2',
        '3/5',
        r'7\6',
        '  spaced  ',
        '🎸𝄞',
        'first\r\nsecond\t  ',
        ':)',
        'x',
      ];
      for (var i = 0; i < values.length; i++) {
        cells[i * 3][i % 6] = values[i];
      }
      final content = jsonEncode({
        'formatVersion': 1,
        'id': 'tab',
        'arrangementId': 'arrangement',
        'positions': List.generate(24, (i) => {'id': 'p$i', 'cells': cells[i]}),
      });
      final tab = TabDocument.decode(content, 9);
      expect(tab.migrated, true);
      expect(tab.id, 'tab');
      expect(tab.arrangementId, 'arrangement');
      expect(tab.revision, 9);
      for (final value in values) {
        expect(tab.text, contains(value));
      }
      expect('e|'.allMatches(tab.text).length, 2);
      final copy = TabDocument.decode(tab.encode(), 10);
      expect(copy.migrated, false);
      expect(copy.text, tab.text);
    },
  );
  test(
    'actual SQLite reopen retains text, arrangement separation and deletion protection',
    () async {
      sqfliteFfiInit();
      final root = await Directory.systemTemp.createTemp('tab_store_');
      final path = '${root.path}/db.sqlite';
      var store = await MusicStore.open(
        factory: databaseFactoryFfi,
        location: path,
      );
      try {
        final song = SongDocument(title: 'First'),
            other = SongDocument(title: 'Other');
        await store.save(song);
        await store.save(other);
        final tab = await store.loadTab(song.arrangementId);
        tab.text = ' 7\\6 :) \n0h2\nraw';
        expect(await store.saveTab(tab), true);
        final revision = tab.revision;
        final stale = TabDocument.decode(tab.encode(), tab.revision);
        await store.close();
        store = await MusicStore.open(
          factory: databaseFactoryFfi,
          location: path,
        );
        final loaded = await store.loadTab(song.arrangementId);
        expect(loaded.encode(), tab.encode());
        expect((await store.loadTab(other.arrangementId)).text, blankTabBlock);
        loaded.text += 'anything';
        expect(await store.saveTab(loaded), true);
        expect(loaded.revision, greaterThan(revision));
        expect(await store.saveTab(stale), false);
        expect(
          (await store.list()).firstWhere((s) => s.id == song.id).revision,
          song.revision,
        );
        await store.deleteSong(song.id);
        expect(await store.saveTab(loaded), false);
        expect((await store.db.query('tab_documents')).single['deleted'], 1);
      } finally {
        await store.close();
        await root.delete(recursive: true);
      }
    },
  );
  test(
    'legacy stored grid upgrades in place and survives database reopen',
    () async {
      sqfliteFfiInit();
      final root = await Directory.systemTemp.createTemp('tab_migration_');
      final location = '${root.path}/db.sqlite';
      var store = await MusicStore.open(
        factory: databaseFactoryFfi,
        location: location,
      );
      try {
        final song = SongDocument(title: 'Legacy');
        await store.save(song);
        final original = await store.loadTab(song.arrangementId);
        await store.saveTab(original);
        final legacy = jsonEncode({
          'formatVersion': 1,
          'id': original.id,
          'arrangementId': original.arrangementId,
          'positions': List.generate(
            12,
            (i) => {
              'id': 'column-$i',
              'cells': [
                i == 0 ? '0h2' : '',
                i == 1 ? '  raw\n\tvalue  ' : '',
                '',
                '',
                '',
                '',
              ],
            },
          ),
        });
        await store.db.update(
          'tab_documents',
          {'content': legacy},
          where: 'id = ?',
          whereArgs: [original.id],
        );
        final migrated = await store.loadTab(song.arrangementId);
        expect(migrated.migrated, true);
        expect(await store.saveTab(migrated), true);
        await store.close();
        store = await MusicStore.open(
          factory: databaseFactoryFfi,
          location: location,
        );
        final reopened = await store.loadTab(song.arrangementId);
        expect(reopened.id, original.id);
        expect(reopened.text, migrated.text);
        expect(reopened.text, contains('  raw\n\tvalue  '));
        expect(reopened.migrated, false);
        expect((await store.db.query('tab_documents')).length, 1);
      } finally {
        await store.close();
        await root.delete(recursive: true);
      }
    },
  );
  test('two fresh opens cannot silently create duplicate tabs', () async {
    sqfliteFfiInit();
    final store = await MusicStore.open(
      factory: databaseFactoryFfi,
      location: inMemoryDatabasePath,
    );
    try {
      final song = SongDocument();
      await store.save(song);
      final a = await store.loadTab(song.arrangementId),
          b = await store.loadTab(song.arrangementId);
      expect(await store.saveTab(a), true);
      expect(await store.saveTab(b), false);
      expect((await store.db.query('tab_documents')).length, 1);
    } finally {
      await store.close();
    }
  });
}
