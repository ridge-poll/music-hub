part of 'store.dart';

extension MusicStorePortability on MusicStore {
  Future<LibraryBundle> snapshot() => db.transaction((tx) async {
    final settings = {
      for (final r in await tx.query('settings'))
        r['key'] as String: r['value'] as String,
    };
    final songs = await tx.rawQuery(
      '''SELECT s.id,s.title,s.artist,s.created_at,s.last_edited,s.edited_revision,
      a.id AS arrangement_id,a.tuning,a.capo,a.tempo,c.id AS sheet_id,c.content
      FROM songs s JOIN song_arrangements l ON l.song_id=s.id AND l.deleted=0 AND l.is_default=1
      JOIN arrangements a ON a.id=l.arrangement_id AND a.deleted=0
      JOIN chord_sheets c ON c.arrangement_id=a.id AND c.deleted=0 WHERE s.deleted=0''',
    );
    final tabRows = await tx.query('tab_documents', where: 'deleted=0');
    final tabs = {for (final r in tabRows) r['arrangement_id']: r};
    final notes = await tx.rawQuery(
      '''SELECT l.song_id,n.content,n.revision FROM notes n JOIN song_notes l ON l.note_id=n.id AND l.deleted=0 WHERE n.deleted=0''',
    );
    final bySong = {for (final r in notes) r['song_id']: r};
    final activeSongs = await tx.query(
      'songs',
      columns: ['id'],
      where: 'deleted=0',
    );
    final activeNotes = await tx.query(
      'notes',
      columns: ['id'],
      where: 'deleted=0',
    );
    final songIds = songs.map((s) => s['id']).toSet();
    final arrangementIds = songs.map((s) => s['arrangement_id']).toSet();
    if (activeSongs.length != songs.length ||
        tabs.length != tabRows.length ||
        notes.length != bySong.length ||
        activeNotes.length != notes.length ||
        bySong.keys.any((id) => !songIds.contains(id)) ||
        tabs.keys.any((id) => !arrangementIds.contains(id))) {
      throw const FormatException(
        'The library contains inconsistent document relationships. Backup was not created.',
      );
    }

    final songData = <Map<String, dynamic>>[];
    for (final row in songs) {
      final sheet = SongDocument.decode(row['content'] as String, 0);
      final tabRow = tabs[row['arrangement_id']];
      final tab = tabRow == null
          ? null
          : TabDocument.decode(
              tabRow['content'] as String,
              tabRow['revision'] as int,
            );
      final noteRow = bySong[row['id']];
      final note = noteRow == null
          ? null
          : MusicNote.decode(
              noteRow['content'] as String,
              noteRow['revision'] as int,
            );
      songData.add({
        'id': row['id'],
        'title': row['title'],
        'artist': row['artist'],
        'createdAt': row['created_at'],
        'lastEdited': row['last_edited'],
        'editOrder': row['edited_revision'],
        'arrangementId': row['arrangement_id'],
        'sheetId': row['sheet_id'],
        'tuning': jsonDecode(row['tuning'] as String),
        'capo': row['capo'],
        'tempo': row['tempo'],
        'chords': sheet.text,
        'tabId': tab?.id,
        'tab': tab?.text,
        'annotations': tab?.annotations ?? '',
        'noteId': note?.id,
        'notes': note?.text,
        'noteTitle': note?.title ?? '',
      });
    }
    final recordings = await tx.rawQuery(
      '''SELECT r.id,r.title,r.duration_ms,r.created_at,a.id AS asset_id,a.sha256,a.relative_path,s.id AS song_id
      FROM recordings r JOIN audio_assets a ON a.id=r.asset_id AND a.deleted=0
      LEFT JOIN song_recordings l ON l.recording_id=r.id AND l.deleted=0
      LEFT JOIN songs s ON s.id=l.song_id AND s.deleted=0 WHERE r.deleted=0''',
    );
    final activeRecordings = await tx.query(
      'recordings',
      columns: ['id'],
      where: 'deleted=0',
    );
    if (activeRecordings.length != recordings.length) {
      throw const FormatException(
        'A recording has an invalid audio relationship. Backup was not created.',
      );
    }
    return LibraryBundle({
      'application': 'MusicHub',
      'formatVersion': 1,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'ownerId': settings['owner_id'],
      'settings': {
        for (final e in settings.entries)
          if (portableSettings.contains(e.key)) e.key: e.value,
      },
      'songs': songData,
      'recordings': [
        for (final r in recordings)
          {
            'id': r['id'],
            'assetId': r['asset_id'],
            'title': r['title'],
            'durationMs': r['duration_ms'],
            'createdAt': r['created_at'],
            'songId': r['song_id'],
            'sha256': r['sha256'],
            'audioPath':
                'recordings/${r['asset_id']}${path.extension(r['relative_path'] as String).toLowerCase()}',
            'relativePath': r['relative_path'],
          },
      ],
    });
  });

  /// Called only after archive validation and audio installation. All metadata
  /// replacement is one transaction; failures leave the existing library intact.
  Future<void> restoreSnapshot(
    LibraryBundle bundle,
    Map<String, String> audioPaths,
  ) async {
    // Revalidate the in-memory object at the commit boundary.
    final validated = LibraryBundle(bundle.data);
    for (final r in validated.recordings) {
      if (!audioPaths.containsKey(r['audioPath'])) {
        throw const FormatException('Missing staged audio.');
      }
    }
    await db.transaction((tx) async {
      var maxOrder = int.parse(
        (await tx.query(
              'settings',
              where: 'key=?',
              whereArgs: ['clock'],
            )).single['value']
            as String,
      );
      for (final s in validated.songs) {
        if (s['editOrder'] > maxOrder) maxOrder = s['editOrder'] as int;
      }
      await tx.update(
        'settings',
        {'value': '$maxOrder'},
        where: 'key=?',
        whereArgs: ['clock'],
      );
      await tx.update(
        'settings',
        {'value': validated.ownerId},
        where: 'key=?',
        whereArgs: ['owner_id'],
      );
      final stamp = await _stamp(tx);
      for (final table in [
        'songs',
        'arrangements',
        'song_arrangements',
        'chord_sheets',
        'tab_documents',
        'notes',
        'song_notes',
        'recordings',
        'song_recordings',
        'audio_assets',
        'section_markers',
        'analysis_runs',
        'candidates',
      ]) {
        await tx.update(table, {...stamp, 'deleted': 1}, where: 'deleted=0');
      }
      Future<void> upsert(String table, Map<String, Object?> row) async {
        final values = {...stamp, 'deleted': 0, ...row};
        final changed = await tx.update(
          table,
          values,
          where: 'id=?',
          whereArgs: [row['id']],
        );
        if (changed == 0) await tx.insert(table, values);
      }

      for (final s in validated.songs) {
        final song = SongDocument(
          id: s['id'],
          arrangementId: s['arrangementId'],
          sheetId: s['sheetId'],
          title: s['title'],
          artist: s['artist'],
          text: s['chords'],
        );
        await upsert('songs', {
          'id': song.id,
          'title': song.title,
          'artist': song.artist,
          'created_at': s['createdAt'],
          'last_edited': s['lastEdited'],
          'edited_revision': s['editOrder'],
        });
        await upsert('arrangements', {
          'id': song.arrangementId,
          'tuning': jsonEncode(s['tuning']),
          'capo': s['capo'],
          'tempo': s['tempo'],
        });
        await upsert('song_arrangements', {
          'id': ids.v4(),
          'song_id': song.id,
          'arrangement_id': song.arrangementId,
          'is_default': 1,
        });
        await upsert('chord_sheets', {
          'id': song.sheetId,
          'arrangement_id': song.arrangementId,
          'content': song.encode(),
        });
        if (s['tabId'] != null) {
          final tab = TabDocument(
            id: s['tabId'],
            arrangementId: song.arrangementId,
            text: s['tab'],
            annotations: s['annotations'],
          );
          await upsert('tab_documents', {
            'id': tab.id,
            'arrangement_id': song.arrangementId,
            'content': tab.encode(),
          });
        }
        if (s['noteId'] != null) {
          final note = MusicNote(
            id: s['noteId'],
            title: s['noteTitle'],
            text: s['notes'],
          );
          await upsert('notes', {'id': note.id, 'content': note.encode()});
          await upsert('song_notes', {
            'id': ids.v4(),
            'song_id': song.id,
            'note_id': note.id,
          });
        }
      }
      for (final r in validated.recordings) {
        await upsert('audio_assets', {
          'id': r['assetId'],
          'sha256': r['sha256'],
          'relative_path': audioPaths[r['audioPath']],
          'source_asset_id': null,
          'derivation_type': null,
          'parameters': null,
        });
        await upsert('recordings', {
          'id': r['id'],
          'asset_id': r['assetId'],
          'title': r['title'],
          'duration_ms': r['durationMs'],
          'created_at': r['createdAt'],
        });
        if (r['songId'] != null) {
          await upsert('song_recordings', {
            'id': ids.v4(),
            'song_id': r['songId'],
            'recording_id': r['id'],
          });
        }
      }
      for (final key in portableSettings) {
        await tx.delete('settings', where: 'key=?', whereArgs: [key]);
      }
      for (final e in validated.settings.entries) {
        await tx.insert('settings', {'key': e.key, 'value': e.value});
      }
    });
  }
}
