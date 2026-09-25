import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:file_saver/file_saver.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'audio_files.dart';
import 'backup_service.dart';
import 'document.dart';
import 'library_bundle.dart';
import 'store.dart';
import 'text_portability.dart';

abstract class LibraryFileDialogs {
  const LibraryFileDialogs();
  Future<File?> pick(String kind);
  Future<bool> save(File file, String name);
}

class NativeLibraryFiles extends LibraryFileDialogs {
  const NativeLibraryFiles();
  @override
  Future<File?> pick(String kind) async {
    final types = switch (kind) {
      'audio' => [
        XTypeGroup(
          label: 'Audio',
          extensions: audioExtensions.toList(),
          uniformTypeIdentifiers: ['public.audio'],
        ),
      ],
      'backup' => [
        const XTypeGroup(
          label: 'Music Hub backup',
          extensions: ['zip'],
          uniformTypeIdentifiers: ['public.zip-archive'],
        ),
      ],
      // ChordPro extensions have no universal UTI; validate content after picking.
      _ => <XTypeGroup>[],
    };
    final selected = await openFile(acceptedTypeGroups: types);
    return selected == null ? null : File(selected.path);
  }

  @override
  Future<bool> save(File file, String name) async =>
      await FileSaver.instance.saveAs(
        name: p.basenameWithoutExtension(name),
        filePath: file.path,
        fileExtension: p.extension(name).replaceFirst('.', ''),
        mimeType: MimeType.custom,
        customMimeType: name.endsWith('.zip')
            ? 'application/zip'
            : name.endsWith('.txt')
            ? 'text/plain'
            : 'application/octet-stream',
      ) !=
      null;
}

/// One operation at a time. Leaving while installing a restore is disabled;
/// errors and cancellation remain visible and never claim a successful save.
class FileTaskScreen extends StatefulWidget {
  const FileTaskScreen({super.key, required this.title, required this.run});
  final String title;
  final Future<String> Function(BuildContext) run;
  @override
  State<FileTaskScreen> createState() => _FileTaskScreenState();
}

class _FileTaskScreenState extends State<FileTaskScreen> {
  bool busy = true;
  String? message;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => start());
  }

  Future<void> start() async {
    String result;
    try {
      result = await widget.run(context);
    } catch (e) {
      result = e is FormatException
          ? e.message
          : 'Could not complete this operation. Check the file and available storage, then try again.';
    }
    if (mounted) {
      setState(() {
        busy = false;
        message = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        automaticallyImplyLeading: !busy,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: busy
              ? const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 20),
                    Text('Working…'),
                  ],
                )
              : Text(message!, textAlign: TextAlign.center),
        ),
      ),
    ),
  );
}

Future<void> fileTask(
  BuildContext context,
  String title,
  Future<String> Function(BuildContext) run,
) => Navigator.push<void>(
  context,
  MaterialPageRoute(
    builder: (_) => FileTaskScreen(title: title, run: run),
  ),
);

Future<void> backupLibrary(
  BuildContext context,
  MusicStore store,
  AudioFiles files, {
  LibraryFileDialogs dialogs = const NativeLibraryFiles(),
}) => fileTask(context, 'Back Up Music Hub', (_) async {
  final working = await (await getTemporaryDirectory()).createTemp(
    'music-hub-backup-',
  );
  try {
    final archive = await BackupService(store, files).create(working);
    return await dialogs.save(archive, p.basename(archive.path))
        ? 'Backup saved.'
        : 'Backup cancelled.';
  } finally {
    await _removeTemporary(working);
  }
});
Future<bool> restoreLibrary(
  BuildContext context,
  MusicStore store,
  AudioFiles files, {
  LibraryFileDialogs dialogs = const NativeLibraryFiles(),
}) async {
  var restored = false;
  await fileTask(context, 'Restore Music Hub', (context) async {
    final source = await dialogs.pick('backup');
    if (source == null) return 'Restore cancelled.';
    final service = BackupService(store, files);
    final prepared = await service.prepare(source);
    try {
      if (!context.mounted) return 'Restore cancelled.';
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Replace library?'),
          content: Text(
            'Restore ${prepared.bundle.songs.length} Songs and ${prepared.bundle.recordings.length} recordings from ${prepared.bundle.data['createdAt']}?\n\nThis replaces the current library, including preferences. Back up your current library first if you want to keep it.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Replace library'),
            ),
          ],
        ),
      );
      if (confirmed != true) {
        return 'Restore cancelled. Your library is unchanged.';
      }
      await service.restore(prepared);
      restored = true;
      return 'Library restored.';
    } finally {
      await prepared.dispose();
    }
  });
  return restored;
}

Future<SongDocument?> importText(
  BuildContext context,
  MusicStore store, {
  LibraryFileDialogs dialogs = const NativeLibraryFiles(),
}) async {
  SongDocument? imported;
  await fileTask(context, 'Import text / ChordPro', (_) async {
    final file = await dialogs.pick('text');
    if (file == null) return 'Import cancelled.';
    final extension = p.extension(file.path).toLowerCase();
    if (!['.txt', '.cho', '.chopro', '.pro', '.chordpro'].contains(extension)) {
      throw const FormatException(
        'Choose plain UTF-8 text (.txt) or ChordPro (.cho, .chopro, .pro, .chordpro).',
      );
    }
    if (await file.length() > maxTextBytes) {
      throw const FormatException('Text files must be smaller than 8 MB.');
    }
    final song = importSongText(
      await file.readAsString(),
      filename: p.basenameWithoutExtension(file.path),
      chordPro: extension != '.txt',
    );
    if (song.isBlank) return 'This file is empty. Nothing was created.';
    if (!await store.save(song)) {
      throw const FormatException('Could not save imported text.');
    }
    imported = song;
    return 'Text imported. Return to open it.';
  });
  return imported;
}

Future<void> importRecording(
  BuildContext context,
  MusicStore store,
  AudioFiles files, {
  String? songId,
  LibraryFileDialogs dialogs = const NativeLibraryFiles(),
}) => fileTask(context, 'Import audio', (_) async {
  final source = await dialogs.pick('audio');
  if (source == null) return 'Import cancelled.';
  if (!audioExtensions.contains(
        p.extension(source.path).toLowerCase().replaceFirst('.', ''),
      ) ||
      await source.length() == 0) {
    throw const FormatException('Choose a supported, nonempty audio file.');
  }
  final player = AudioPlayer();
  Duration? duration;
  try {
    duration = await player
        .setFilePath(source.path)
        .timeout(const Duration(seconds: 30));
  } finally {
    await player.dispose();
  }
  if (duration == null || duration.inMilliseconds <= 0) {
    throw const FormatException(
      'This audio format could not be read on this device.',
    );
  }
  await files.importAudio(
    store,
    source,
    title: p.basenameWithoutExtension(source.path),
    durationMs: duration.inMilliseconds,
    songId: songId,
  );
  return 'Recording imported.';
});
Future<void> exportAudio(
  BuildContext context,
  File file,
  String title, {
  LibraryFileDialogs dialogs = const NativeLibraryFiles(),
}) => fileTask(context, 'Export recording', (_) async {
  if (!await file.exists()) {
    throw const FormatException('The audio file is missing.');
  }
  return await dialogs.save(
        file,
        '${safeFilename(title)}${p.extension(file.path)}',
      )
      ? 'Recording exported.'
      : 'Export cancelled.';
});

class SongExportScreen extends StatefulWidget {
  const SongExportScreen({
    super.key,
    required this.store,
    required this.songId,
    required this.files,
    this.dialogs = const NativeLibraryFiles(),
  });
  final MusicStore store;
  final String songId;
  final AudioFiles files;
  final LibraryFileDialogs dialogs;
  @override
  State<SongExportScreen> createState() => _SongExportScreenState();
}

class _SongExportScreenState extends State<SongExportScreen> {
  late final data = widget.store.snapshot();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Export Song')),
    body: FutureBuilder<LibraryBundle>(
      future: data,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text('Could not read Song. Reopen and try again.'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final song = snapshot.data!.songs
            .where((s) => s['id'] == widget.songId)
            .firstOrNull;
        if (song == null) {
          return const Center(child: Text('Song no longer exists.'));
        }
        final choices = {
          'Chords-Lyrics': song['chords'] as String,
          'Tab': song['tab'] == null
              ? ''
              : exportTabText(song['tab'], song['annotations']),
          'Notes': song['notes'] as String? ?? '',
        };
        final recordings = snapshot.data!.recordings
            .where((r) => r['songId'] == widget.songId)
            .toList();
        return ListView(
          children: [
            if (choices.values.every((s) => s.trim().isEmpty) &&
                recordings.isEmpty)
              const ListTile(title: Text('No content to export.')),
            for (final recording in recordings)
              ListTile(
                title: Text(recording['title']),
                subtitle: const Text('Audio file'),
                leading: const Icon(Icons.file_download_outlined),
                onTap: () => exportAudio(
                  context,
                  widget.files.resolve(recording['relativePath']),
                  recording['title'],
                  dialogs: widget.dialogs,
                ),
              ),
            for (final item in choices.entries)
              if (item.value.trim().isNotEmpty)
                ListTile(
                  title: Text(
                    item.key == 'Chords-Lyrics'
                        ? 'Chords/Lyrics (.txt)'
                        : '${item.key} (.txt)',
                  ),
                  leading: const Icon(Icons.file_download_outlined),
                  onTap: () =>
                      fileTask(context, 'Export ${item.key}', (_) async {
                        final directory = await (await getTemporaryDirectory())
                            .createTemp('music-hub-export-');
                        try {
                          final name =
                              '${safeFilename(song['title'])}-${item.key}.txt';
                          final file = await File(
                            p.join(directory.path, name),
                          ).writeAsString(item.value);
                          return await widget.dialogs.save(file, name)
                              ? 'Text exported.'
                              : 'Export cancelled.';
                        } finally {
                          await _removeTemporary(directory);
                        }
                      }),
                ),
          ],
        );
      },
    ),
  );
}

Future<void> _removeTemporary(Directory directory) async {
  try {
    await directory.delete(recursive: true);
  } on FileSystemException {
    /* A completed save/restore remains successful if temporary cleanup fails. */
  }
}
