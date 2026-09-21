import 'package:path/path.dart' as path;
import 'package:sqflite_common/sqlite_api.dart';

import 'document.dart';
import 'recording.dart';
import 'tab_document.dart';

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
    var compact = false;
    final db = await f.openDatabase(
      p,
      options: OpenDatabaseOptions(
        version: 3,
        onUpgrade: (db, old, next) async {
          if (old < 2) {
            await db.execute(
              "ALTER TABLE recordings ADD COLUMN duration_ms INTEGER NOT NULL DEFAULT 0",
            );
            await db.execute(
              "ALTER TABLE recordings ADD COLUMN created_at TEXT NOT NULL DEFAULT ''",
            );
          }
          if (old < 3) {
            await db.execute('DROP TABLE IF EXISTS document_versions');
            compact = true;
          }
        },
        onOpen: (db) async {
          if (compact) await db.execute('VACUUM');
        },
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
            'CREATE TABLE recordings ($stamp, asset_id TEXT NOT NULL REFERENCES audio_assets(id), title TEXT NOT NULL, duration_ms INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL DEFAULT \'\')',
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

  // Reject stale/deleted documents; keep unsaved edits in the editor.
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
      return (true, revision);
    });
    if (result.$1) {
      song.revision = result.$2;
    }
    return result.$1;
  }

  Future<TabDocument> loadTab(String arrangementId) async {
    final rows = await db.query(
      'tab_documents',
      where: 'arrangement_id = ? AND deleted = 0',
      whereArgs: [arrangementId],
    );
    if (rows.isEmpty) return TabDocument(arrangementId: arrangementId);
    if (rows.length != 1) {
      throw StateError('Multiple tab documents for this arrangement');
    }
    return TabDocument.decode(
      rows.single['content'] as String,
      rows.single['revision'] as int,
    );
  }

  Future<bool> saveTab(TabDocument tab) async {
    final content = tab.encode();
    final revision = await db.transaction<int?>((tx) async {
      final parents = await tx.query(
        'arrangements',
        where: 'id = ? AND deleted = 0',
        whereArgs: [tab.arrangementId],
      );
      if (parents.isEmpty) return null;
      final rows = await tx.query(
        'tab_documents',
        where: 'arrangement_id = ?',
        whereArgs: [tab.arrangementId],
      );
      if (rows.isNotEmpty &&
          (rows.length != 1 ||
              rows.single['id'] != tab.id ||
              rows.single['revision'] != tab.revision ||
              rows.single['deleted'] == 1)) {
        return null;
      }
      final stamp = await _stamp(tx);
      if (rows.isEmpty) {
        await tx.insert('tab_documents', {
          'id': tab.id,
          ...stamp,
          'arrangement_id': tab.arrangementId,
          'content': content,
        });
      } else {
        await tx.update(
          'tab_documents',
          {...stamp, 'content': content},
          where: 'id = ?',
          whereArgs: [tab.id],
        );
      }
      return stamp['revision'] as int;
    });
    if (revision == null) return false;
    tab.revision = revision;
    return true;
  }

  Future<void> deleteSong(String id) async {
    await db.transaction((tx) async {
      final stamp = {...await _stamp(tx), 'deleted': 1};
      final links = await tx.query(
        'song_arrangements',
        where: 'song_id = ?',
        whereArgs: [id],
      );
      for (final link in links) {
        final arrangement = link['arrangement_id'];
        for (final table in [
          'chord_sheets',
          'tab_documents',
          'section_markers',
        ]) {
          await tx.update(
            table,
            stamp,
            where: 'arrangement_id = ?',
            whereArgs: [arrangement],
          );
        }
        await tx.update(
          'arrangements',
          stamp,
          where: 'id = ?',
          whereArgs: [arrangement],
        );
      }
      for (final table in [
        'song_arrangements',
        'song_recordings',
        'song_notes',
      ]) {
        await tx.update(table, stamp, where: 'song_id = ?', whereArgs: [id]);
      }
      await tx.update('songs', stamp, where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> deleteRecording(String id) async {
    await db.transaction((tx) async {
      final stamp = {...await _stamp(tx), 'deleted': 1};
      await tx.update(
        'song_recordings',
        stamp,
        where: 'recording_id = ?',
        whereArgs: [id],
      );
      await tx.update('recordings', stamp, where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<List<RecordingEntry>> recordings({String? songId}) async {
    final rows = await db.rawQuery(
      '''SELECT r.id, r.title, r.duration_ms, r.created_at,
      a.relative_path, s.id AS song_id, s.title AS song_title
      FROM recordings r JOIN audio_assets a ON a.id = r.asset_id
      LEFT JOIN song_recordings link ON link.recording_id = r.id AND link.deleted = 0
      LEFT JOIN songs s ON s.id = link.song_id AND s.deleted = 0
      WHERE r.deleted = 0 AND a.deleted = 0
      ${songId == null ? '' : 'AND s.id = ?'} ORDER BY r.revision DESC''',
      songId == null ? [] : [songId],
    );
    return rows
        .map(
          (r) => RecordingEntry(
            id: r['id'] as String,
            title: r['title'] as String,
            relativePath: r['relative_path'] as String,
            durationMs: r['duration_ms'] as int,
            createdAt: r['created_at'] as String,
            songId: r['song_id'] as String?,
            songTitle: r['song_title'] as String?,
          ),
        )
        .toList();
  }

  Future<void> saveRecording({
    required String id,
    required String title,
    required String hash,
    required String relativePath,
    required int durationMs,
    required String createdAt,
    String? songId,
  }) async {
    await db.transaction((tx) async {
      // A retry after a crash between database commit and draft cleanup is safe.
      if ((await tx.query(
        'recordings',
        where: 'id = ?',
        whereArgs: [id],
      )).isNotEmpty) {
        return;
      }
      final stamp = await _stamp(tx);
      final assets = await tx.query(
        'audio_assets',
        where: 'sha256 = ? AND deleted = 0',
        whereArgs: [hash],
      );
      final assetId = assets.isEmpty ? ids.v4() : assets.first['id'] as String;
      if (assets.isEmpty) {
        await tx.insert('audio_assets', {
          'id': assetId,
          ...stamp,
          'sha256': hash,
          'relative_path': relativePath,
        });
      }
      await tx.insert('recordings', {
        'id': id,
        ...stamp,
        'asset_id': assetId,
        'title': title,
        'duration_ms': durationMs,
        'created_at': createdAt,
      });
      if (songId != null) {
        await tx.insert('song_recordings', {
          'id': ids.v4(),
          ...stamp,
          'song_id': songId,
          'recording_id': id,
        });
      }
    });
  }

  Future<void> attachRecording(String recordingId, String? songId) async {
    await db.transaction((tx) async {
      final stamp = await _stamp(tx);
      await tx.update(
        'song_recordings',
        {...stamp, 'deleted': 1},
        where: 'recording_id = ? AND deleted = 0',
        whereArgs: [recordingId],
      );
      if (songId != null) {
        await tx.insert('song_recordings', {
          'id': ids.v4(),
          ...stamp,
          'song_id': songId,
          'recording_id': recordingId,
        });
      }
    });
  }

  Future<void> close() => db.close();
}
