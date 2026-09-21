import 'dart:io';
import 'package:test/test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:music_hub/document.dart';
import 'package:music_hub/tab_document.dart';
import 'package:music_hub/store.dart';

void main() {
  test('raw cells and stable positions round-trip across added blocks', () {
    final tab = TabDocument(arrangementId: 'arrangement');
    const values = [
      '3',
      '0',
      '0h2',
      '3/5',
      r'7\6',
      'x',
      ':)',
      '  exact  ',
      '\nline\n',
      '🎸𝄞',
      '{Am}',
      '',
    ];
    for (var c = 0; c < 12; c++) {
      tab.positions[c].cells[c % 6] = values[c];
    }
    final ids = tab.positions.map((p) => p.id).toList();
    tab.addBlock();
    final copy = TabDocument.decode(tab.encode(), 7);
    expect(copy.encode(), tab.encode());
    expect(copy.revision, 7);
    expect(copy.positions.take(12).map((p) => p.id), ids);
    expect(copy.positions.map((p) => p.id).toSet().length, 24);
    expect(copy.positions.expand((p) => p.cells).length, 144);
  });
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
        tab.positions[0].cells[0] = r' 7\6 :) ';
        tab.addBlock();
        tab.positions[13].cells[5] = '0h2\nraw';
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
        expect(
          (await store.loadTab(other.arrangementId)).positions.first.cells,
          everyElement(''),
        );
        loaded.positions[1].cells[2] = 'anything';
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
