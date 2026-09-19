import 'package:path/path.dart' as path;
import 'package:sqflite_common/sqlite_api.dart';

import 'document.dart';

class SavedVersion {
  SavedVersion(this.revision, this.content, this.conflict);
  final int revision;
  final String content;
  final bool conflict;
}

class MusicStore {
  MusicStore(this.db);
  final Database db;
  static Future<MusicStore> open({
    required DatabaseFactory factory,
    String? location,
  }) async {
    final f = factory;
    final p =
        location ?? path.join(await f.getDatabasesPath(), 'music_hub.sqlite');
    final db = await f.openDatabase(
      p,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async {
          await db.execute(
            'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
          );
          for (final key in ['owner_id', 'device_id']) {
            await db.insert('settings', {'key': key, 'value': ids.v4()});
          }
          await db.insert('settings', {'key': 'clock', 'value': '0'});
          const stamp =
              'id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, revision INTEGER NOT NULL, device_id TEXT NOT NULL, deleted INTEGER NOT NULL DEFAULT 0 CHECK(deleted IN (0,1))';
          await db.execute(
            'CREATE TABLE songs ($stamp, title TEXT NOT NULL, artist TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE arrangements ($stamp, tuning TEXT NOT NULL, capo INTEGER NOT NULL DEFAULT 0, tempo REAL)',
          );
          await db.execute(
            'CREATE TABLE song_arrangements ($stamp, song_id TEXT NOT NULL REFERENCES songs(id), arrangement_id TEXT NOT NULL REFERENCES arrangements(id), is_default INTEGER NOT NULL DEFAULT 1)',
          );
          await db.execute(
            'CREATE TABLE chord_sheets ($stamp, arrangement_id TEXT NOT NULL REFERENCES arrangements(id), content TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE document_versions ($stamp, sheet_id TEXT NOT NULL REFERENCES chord_sheets(id), base_revision INTEGER NOT NULL, content TEXT NOT NULL, conflict INTEGER NOT NULL DEFAULT 0)',
          );
          await db.execute(
            'CREATE INDEX versions_by_sheet ON document_versions(sheet_id, revision DESC)',
          );
          // Inert schema allowances. No analysis or tab UI is implemented in slice 1.
          await db.execute(
            'CREATE TABLE tab_documents ($stamp, arrangement_id TEXT NOT NULL REFERENCES arrangements(id), content TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE notes ($stamp, content TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE audio_assets ($stamp, sha256 TEXT NOT NULL, relative_path TEXT NOT NULL, source_asset_id TEXT REFERENCES audio_assets(id), derivation_type TEXT, parameters TEXT)',
          );
          await db.execute(
            'CREATE TABLE recordings ($stamp, asset_id TEXT NOT NULL REFERENCES audio_assets(id), title TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE song_recordings ($stamp, song_id TEXT NOT NULL REFERENCES songs(id), recording_id TEXT NOT NULL REFERENCES recordings(id))',
          );
          await db.execute(
            'CREATE TABLE song_notes ($stamp, song_id TEXT NOT NULL REFERENCES songs(id), note_id TEXT NOT NULL REFERENCES notes(id))',
          );
          await db.execute(
            'CREATE TABLE section_markers ($stamp, arrangement_id TEXT NOT NULL REFERENCES arrangements(id), label TEXT NOT NULL, target_type TEXT NOT NULL, target_id TEXT NOT NULL, start_position TEXT NOT NULL, end_position TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE analysis_runs ($stamp, asset_id TEXT NOT NULL REFERENCES audio_assets(id), model_version TEXT NOT NULL, parameters TEXT NOT NULL, status TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE candidates ($stamp, analysis_run_id TEXT NOT NULL REFERENCES analysis_runs(id), source_start REAL NOT NULL, source_end REAL NOT NULL, confidence REAL, alternatives TEXT NOT NULL, payload TEXT NOT NULL)',
          );
        },
      ),
    );
    return MusicStore(db);
  }

  Future<List<SongDocument>> list() async {
    final rows = await db.rawQuery(
      '''SELECT c.content, c.revision FROM chord_sheets c
      JOIN song_arrangements a ON a.arrangement_id = c.arrangement_id
      JOIN songs s ON s.id = a.song_id
      WHERE c.deleted = 0 AND a.deleted = 0 AND s.deleted = 0 AND a.is_default = 1
      ORDER BY c.revision DESC''',
    );
    return rows
        .map(
          (r) =>
              SongDocument.decode(r['content'] as String, r['revision'] as int),
        )
        .toList();
  }

  // Local Lamport counter, persisted atomically. Future sync must advance it
  // past received counters; device UUID breaks ties. This is NOT a sync engine.
  Future<Map<String, Object>> _stamp(Transaction tx) async {
    final settings = {
      for (final row in await tx.query('settings')) row['key']: row['value'],
    };
    final next = int.parse(settings['clock'] as String) + 1;
    await tx.update(
      'settings',
      {'value': '$next'},
      where: 'key = ?',
      whereArgs: ['clock'],
    );
    return {
      'owner_id': settings['owner_id'] as String,
      'device_id': settings['device_id'] as String,
      'revision': next,
    };
  }

  // false means a stale edit was preserved as a recoverable version; current
  // authored content was not overwritten. All inserts/updates are atomic.
  Future<bool> save(SongDocument song) async {
    final content = song.encode();
    final baseRevision = song.revision;
    final result = await db.transaction((tx) async {
      final current = await tx.query(
        'chord_sheets',
        where: 'id = ?',
        whereArgs: [song.sheetId],
      );
      final stamp = await _stamp(tx);
      final revision = stamp['revision'] as int;
      if (current.isNotEmpty &&
          (current.single['revision'] != baseRevision ||
              current.single['deleted'] == 1)) {
        await tx.insert('document_versions', {
          'id': ids.v4(),
          ...stamp,
          'sheet_id': song.sheetId,
          'base_revision': baseRevision,
          'content': content,
          'conflict': 1,
        });
        return (false, baseRevision);
      }
      if (current.isEmpty) {
        await tx.insert('songs', {
          'id': song.id,
          ...stamp,
          'title': song.title,
          'artist': song.artist,
        });
        await tx.insert('arrangements', {
          'id': song.arrangementId,
          ...stamp,
          'tuning': '[64,59,55,50,45,40]',
        });
        await tx.insert('song_arrangements', {
          'id': ids.v4(),
          ...stamp,
          'song_id': song.id,
          'arrangement_id': song.arrangementId,
        });
        await tx.insert('chord_sheets', {
          'id': song.sheetId,
          ...stamp,
          'arrangement_id': song.arrangementId,
          'content': content,
        });
      } else {
        await tx.update(
          'songs',
          {...stamp, 'title': song.title, 'artist': song.artist},
          where: 'id = ?',
          whereArgs: [song.id],
        );
        await tx.update(
          'chord_sheets',
          {...stamp, 'content': content},
          where: 'id = ?',
          whereArgs: [song.sheetId],
        );
      }
      await tx.insert('document_versions', {
        'id': ids.v4(),
        ...stamp,
        'sheet_id': song.sheetId,
        'base_revision': baseRevision,
        'content': content,
      });
      return (true, revision);
    });
    if (result.$1) {
      song.revision = result.$2;
    }
    return result.$1;
  }

  Future<List<SavedVersion>> history(String sheetId) async =>
      (await db.query(
            'document_versions',
            where: 'sheet_id = ?',
            whereArgs: [sheetId],
            orderBy: 'revision DESC',
          ))
          .map(
            (r) => SavedVersion(
              r['revision'] as int,
              r['content'] as String,
              r['conflict'] == 1,
            ),
          )
          .toList();

  Future<void> close() => db.close();
}
