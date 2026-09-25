import 'portability_screen.dart';
import 'package:flutter/material.dart';
import 'audio_files.dart';
import 'audio_screen.dart';
import 'delete_action.dart';
import 'document.dart';
import 'main.dart' show EditorScreen, PerformanceScreen;
import 'notes_screen.dart';
import 'store.dart';
import 'tab_screen.dart';

Future<void> openSong(
  BuildContext context,
  MusicStore store,
  AudioFiles files,
  SongDocument song, {
  String? component,
}) async {
  final type =
      component ??
      (song.components.length == 1 ? song.components.single : null);
  final result = await Navigator.push<String>(
    context,
    MaterialPageRoute<String>(
      builder: (_) => switch (type) {
        'Chords/Lyrics' => EditorScreen(store: store, song: song, files: files),
        'Tab' => TabScreen(store: store, song: song),
        'Notes' => SongNotesScreen(store: store, song: song),
        'Recordings' => SongRecordingsScreen(
          store: store,
          files: files,
          song: song,
        ),
        _ => SongWorkspaceScreen(store: store, files: files, song: song),
      },
    ),
  );
  if (result == 'workspace' && context.mounted) {
    final latest = (await store.list())
        .where((s) => s.id == song.id)
        .firstOrNull;
    if (context.mounted) {
      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => SongWorkspaceScreen(
            store: store,
            files: files,
            song: latest ?? song,
          ),
        ),
      );
    }
  }
}

class SongWorkspaceScreen extends StatefulWidget {
  const SongWorkspaceScreen({
    super.key,
    required this.store,
    required this.files,
    required this.song,
  });
  final MusicStore store;
  final AudioFiles files;
  final SongDocument song;
  @override
  State<SongWorkspaceScreen> createState() => _SongWorkspaceScreenState();
}

class _SongWorkspaceScreenState extends State<SongWorkspaceScreen> {
  late SongDocument song = widget.song;
  String? error;
  Future<void> refresh() async {
    final latest = (await widget.store.list())
        .where((s) => s.id == song.id)
        .firstOrNull;
    if (mounted) {
      if (latest == null && song.revision > 0) {
        Navigator.pop(context);
        return;
      }
      setState(() => song = latest ?? song);
    }
  }

  Future<void> edit(String type) async {
    // Consume workspace requests here: the editor returns to this same overview.
    await Navigator.push<String>(
      context,
      MaterialPageRoute<String>(
        builder: (_) => switch (type) {
          'Chords/Lyrics' => EditorScreen(
            store: widget.store,
            song: song,
            files: widget.files,
          ),
          'Tab' => TabScreen(store: widget.store, song: song),
          _ => SongNotesScreen(store: widget.store, song: song),
        },
      ),
    );
    await refresh();
  }

  Future<void> rename() async {
    var editedTitle = song.title;
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Song title'),
        content: TextFormField(
          initialValue: editedTitle,
          autofocus: true,
          onChanged: (value) => editedTitle = value,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, editedTitle),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (value == null || value.trim() == song.title) return;
    final snapshot = SongDocument.decode(song.encode(), song.revision)
      ..title = value.trim();
    if (snapshot.revision == 0 && snapshot.isBlank) return;
    try {
      if (!await widget.store.save(snapshot)) throw StateError('stale');
      song = snapshot;
      await refresh();
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Could not save title. Please reopen and retry.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(song.title.isEmpty ? 'Untitled song' : song.title),
      actions: [
        if (song.revision > 0)
          IconButton(
            tooltip: 'Export Song',
            icon: const Icon(Icons.file_download_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => SongExportScreen(
                  store: widget.store,
                  songId: song.id,
                  files: widget.files,
                ),
              ),
            ),
          ),

        IconButton(
          tooltip: 'Rename song',
          onPressed: rename,
          icon: const Icon(Icons.edit_outlined),
        ),
      ],
    ),
    body: SafeArea(
      child: ListView(
        children: [
          if (error != null)
            Padding(padding: const EdgeInsets.all(16), child: Text(error!)),
          for (final type in ['Chords/Lyrics', 'Tab', 'Notes'])
            ListTile(
              title: Text(type),
              leading: Icon(
                song.components.contains(type)
                    ? Icons.description_outlined
                    : Icons.add,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => edit(type),
            ),
          if (song.revision > 0)
            ListTile(
              title: const Text('Recordings'),
              subtitle: song.recordingCount > 0
                  ? Text('${song.recordingCount} saved')
                  : null,
              leading: const Icon(Icons.graphic_eq),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute<String>(
                    builder: (_) => SongRecordingsScreen(
                      store: widget.store,
                      files: widget.files,
                      song: song,
                    ),
                  ),
                );
                await refresh();
              },
            ),
          if (song.text.trim().isNotEmpty)
            ListTile(
              leading: const Icon(Icons.play_circle_outline),
              title: const Text('Performance mode'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => PerformanceScreen(song: song),
                ),
              ),
            ),
          if (song.revision > 0)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: TextButton(
                onPressed: () async {
                  if (await confirmDelete(
                        context,
                        'Song',
                        () => widget.store.deleteSong(song.id),
                        detail:
                            'Its documents will be deleted. Recordings remain in Recordings.',
                      ) &&
                      context.mounted) {
                    Navigator.pop(context);
                  }
                },
                child: Text(
                  'Delete Song',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
