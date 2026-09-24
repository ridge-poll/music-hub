import 'dart:io';
import 'package:test/test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:music_hub/note.dart';
import 'package:music_hub/document.dart';
import 'package:music_hub/store.dart';

void main() {
  test(
    'standalone notes persist, attach independently and survive song deletion',
    () async {
      sqfliteFfiInit();
      final root = await Directory.systemTemp.createTemp('notes_');
      final location = '${root.path}/db.sqlite';
      var store = await MusicStore.open(
        factory: databaseFactoryFfi,
        location: location,
      );
      try {
        final note = MusicNote(title: 'Riff', text: '  7h9\n raw 🎸  ');
        expect(await store.saveNote(note), true);
        final stale = MusicNote.decode(note.encode(), note.revision);
        final song = SongDocument(title: 'Song');
        await store.save(song);
        await store.attachNote(note.id, song.id);
        note.text += 'more';
        expect(await store.saveNote(note), true);
        expect(await store.saveNote(stale), false);
        expect((await store.notes(songId: song.id)).single.text, note.text);
        await store.close();
        store = await MusicStore.open(
          factory: databaseFactoryFfi,
          location: location,
        );
        expect((await store.notes()).single.songId, song.id);
        await store.deleteSong(song.id);
        expect((await store.notes()).single.songId, isNull);
        expect((await store.notes()).single.text, note.text);
        await store.deleteNote(note.id);
        expect(await store.notes(), isEmpty);
        expect(await store.saveNote(note), false);
        expect((await store.db.query('notes')).single['deleted'], 1);
      } finally {
        await store.close();
        await root.delete(recursive: true);
      }
    },
  );
}
