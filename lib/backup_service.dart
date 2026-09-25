import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'audio_files.dart';
import 'document.dart';
import 'library_bundle.dart';
import 'store.dart';

const _prefix = 'MusicHub Backup/';
const _maxArchiveBytes = 8 * 1024 * 1024 * 1024;
Future<String> _digest(File file) async =>
    (await sha256.bind(file.openRead()).first).toString();

class PreparedBackup {
  PreparedBackup(this.bundle, this.directory);
  final LibraryBundle bundle;
  final Directory directory;
  Future<void> dispose() async {
    try {
      if (await directory.exists()) await directory.delete(recursive: true);
    } on FileSystemException {
      /* Temporary files can be cleaned up later. */
    }
  }
}

/// Logical, readable backups. SQLite remains exclusively an implementation detail.
class BackupService {
  BackupService(this.store, this.files);
  final MusicStore store;
  final AudioFiles files;
  Future<void> _checkDrafts() async {
    if ((await files.pending()).isNotEmpty) {
      throw const FormatException(
        'Save or discard unfinished recording drafts before backing up or restoring.',
      );
    }
  }

  Future<File> create(Directory working) async {
    await _checkDrafts();
    final bundle = await store.snapshot();
    final root = files.root.path;
    final destination = working.path;
    return File(
      await Isolate.run(() => _encode(bundle.data, root, destination)),
    );
  }

  Future<PreparedBackup> prepare(File source) async {
    await _checkDrafts();
    final staging = await Directory(
      p.join(files.root.path, 'restore-staging'),
    ).create(recursive: true);
    final work = await staging.createTemp('restore-');
    try {
      if (await source.length() > _maxArchiveBytes) {
        throw const FormatException('Backup is too large.');
      }
      final copy = await source.copy(p.join(work.path, 'input.zip'));
      final destination = work.path;
      final sourcePath = copy.path;
      final data = await Isolate.run(() => _decode(sourcePath, destination));
      return PreparedBackup(LibraryBundle(data), work);
    } catch (_) {
      await work.delete(recursive: true);
      rethrow;
    }
  }

  Future<void> restore(PreparedBackup backup) async {
    await _checkDrafts();
    final installed = Directory(
      p.join(files.root.path, 'audio', 'restored', ids.v4()),
    );
    await installed.create(recursive: true);
    try {
      final paths = <String, String>{};
      for (final r in backup.bundle.recordings) {
        final name = r['audioPath'] as String;
        if (paths.containsKey(name)) continue;
        final source = File(p.join(backup.directory.path, name));
        // Verify again at the commit boundary, before changing live metadata.
        if (await _digest(source) != r['sha256']) {
          throw const FormatException('Staged audio failed verification.');
        }
        final target = await source.copy(
          p.join(installed.path, p.basename(name)),
        );
        paths[name] = p.relative(target.path, from: files.root.path);
      }
      await store.restoreSnapshot(backup.bundle, paths);
    } catch (_) {
      await installed.delete(recursive: true);
      rethrow;
    }
  }
}

Future<String> _encode(
  Map<String, dynamic> source,
  String root,
  String destination,
) async {
  final data = LibraryBundle(source).data;
  final directory = Directory(destination);
  await directory.create(recursive: true);
  final payload = <String, File>{};
  for (final song in (data['songs'] as List).cast<Map<String, dynamic>>()) {
    for (final key in ['chords', 'tab', 'notes', 'annotations']) {
      final text = song[key] as String?;
      if (text == null) continue;
      final name = 'songs/${song['id']}/$key.txt';
      final file = File(p.join(destination, name));
      await file.parent.create(recursive: true);
      await file.writeAsString(text, flush: true);
      payload[name] = file;
      song[key] = {'file': name};
    }
  }
  for (final r in (data['recordings'] as List).cast<Map<String, dynamic>>()) {
    final file = AudioFiles(
      Directory(root),
    ).resolve(r.remove('relativePath') as String);
    if (await _digest(file) != r['sha256']) {
      throw const FormatException(
        'A recording is missing or damaged. Backup was not created.',
      );
    }
    payload[r['audioPath'] as String] = file;
  }
  var total = 0;
  final entries = <String, dynamic>{};
  for (final e in payload.entries) {
    final size = await e.value.length();
    total += size;
    if (size > 2 * 1024 * 1024 * 1024 || total > _maxArchiveBytes) {
      throw const FormatException('Backup exceeds V1 size limits.');
    }
    entries[e.key] = {'size': size, 'sha256': await _digest(e.value)};
  }
  data['files'] = entries;
  final manifest = File(p.join(destination, 'library.json'));
  await manifest.writeAsString(
    const JsonEncoder.withIndent('  ').convert(data),
  );
  if (await manifest.length() > 16 * 1024 * 1024) {
    throw const FormatException('Backup metadata is too large.');
  }
  final output = p.join(
    destination,
    'MusicHub-Backup-${DateTime.now().toIso8601String().substring(0, 10)}.zip',
  );
  final encoder = ZipFileEncoder()..create(output);
  try {
    await encoder.addFile(manifest, '${_prefix}library.json');
    for (final e in payload.entries) {
      await encoder.addFile(
        e.value,
        '$_prefix${e.key}',
        e.key.startsWith('recordings/') ? 0 : 1,
      );
    }
  } finally {
    await encoder.close();
  }
  return output;
}

// A streaming output with a hard expanded-byte limit, including dishonest ZIP
// size headers. Never extract paths supplied by an archive without validation.
class _BoundedOutput extends OutputFileStream {
  _BoundedOutput(String path, this.limit)
    : super.withFileHandle(FileHandle(path, mode: FileAccess.write));
  final int limit;
  void _check(int count) {
    if (length + count > limit) {
      throw const FormatException(
        'Expanded archive exceeds its declared size.',
      );
    }
  }

  @override
  void writeByte(int value) {
    _check(1);
    super.writeByte(value);
  }

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    _check(length ?? bytes.length);
    super.writeBytes(bytes, length: length);
  }
}

Future<Map<String, dynamic>> _decode(String source, String destination) async {
  final input = InputFileStream(source);
  try {
    // Inspect directory entries before materializing ArchiveFile objects.
    // ZipDecoder coalesces duplicate names and eagerly reads symlink targets.
    final directory = ZipDirectory()..read(input);
    if (directory.fileHeaders.length > 60001) {
      throw const FormatException('Too many archive entries.');
    }
    final entries = <String, ArchiveFile>{};
    var total = 0;
    for (final header in directory.fileHeaders) {
      final compressed = header.file;
      final name = header.filename;
      if (compressed == null ||
          compressed.filename != name ||
          (header.externalFileAttributes >> 16) & 0xf000 == 0xa000 ||
          header.generalPurposeBitFlag & 1 != 0 ||
          ![0, 8].contains(header.compressionMethod)) {
        throw const FormatException('Unsupported or unsafe archive entry.');
      }
      final entry = ArchiveFile.file(
        name,
        compressed.uncompressedSize,
        compressed,
      )..compression = compressed.compressionMethod;
      if (!name.startsWith(_prefix) ||
          name.contains('\\') ||
          name.contains('\x00') ||
          name.split('/').any((s) => s == '..' || s == '.') ||
          entry.isSymbolicLink ||
          name.endsWith('/') ||
          entries.containsKey(name)) {
        throw const FormatException('Unsafe or duplicate archive entry.');
      }
      if (entry.size < 0 || entry.size > 2 * 1024 * 1024 * 1024) {
        throw const FormatException('Archive entry is too large.');
      }
      total += entry.size;
      if (total > _maxArchiveBytes) {
        throw const FormatException('Expanded backup is too large.');
      }
      entries[name] = entry;
    }
    Future<File> extract(String name, int limit) async {
      final entry = entries['$_prefix$name'];
      if (entry == null || entry.size > limit) {
        throw const FormatException('Missing or oversized backup file.');
      }
      final file = File(p.join(destination, name));
      await file.parent.create(recursive: true);
      final output = _BoundedOutput(file.path, entry.size);
      try {
        entry.writeContent(output);
      } finally {
        await output.close();
      }
      if (await file.length() != entry.size) {
        throw const FormatException('Incomplete backup file.');
      }
      return file;
    }

    final manifest = await extract('library.json', 16 * 1024 * 1024);
    final data =
        jsonDecode(await manifest.readAsString()) as Map<String, dynamic>;
    if (data['application'] != 'MusicHub' || data['formatVersion'] != 1) {
      throw const FormatException('Unsupported Music Hub backup version.');
    }
    final checks = data.remove('files') as Map<String, dynamic>;
    final expected = <String>{'${_prefix}library.json'};
    Future<File> checked(String name, int limit) async {
      if (!RegExp(
        r'^(songs/[A-Za-z0-9_-]{1,80}/(chords|tab|notes|annotations)\.txt|recordings/[A-Za-z0-9_-]{1,80}\.[a-z0-9]+)$',
      ).hasMatch(name)) {
        throw const FormatException('Invalid content path.');
      }
      expected.add('$_prefix$name');
      final check = checks[name];
      if (check is! Map ||
          check['size'] is! int ||
          check['size'] < 0 ||
          check['size'] > limit ||
          check['sha256'] is! String ||
          !LibraryBundle.hash.hasMatch(check['sha256'])) {
        throw const FormatException('Invalid content checksum metadata.');
      }
      final file = await extract(name, limit);
      if (await file.length() != check['size'] ||
          await _digest(file) != check['sha256']) {
        throw const FormatException('Backup content failed verification.');
      }
      return file;
    }

    var totalText = 0;
    for (final song in data['songs'] as List) {
      if (!LibraryBundle.identity.hasMatch(song['id'] as String)) {
        throw const FormatException('Invalid Song identity.');
      }
      for (final key in ['chords', 'tab', 'notes', 'annotations']) {
        if (song[key] == null) continue;
        final name = 'songs/${song['id']}/$key.txt';
        if (song[key] is! Map || song[key]['file'] != name) {
          throw const FormatException('Invalid document reference.');
        }
        final entry = entries['$_prefix$name'];
        totalText += entry?.size ?? 0;
        if (totalText > maxLibraryTextBytes) {
          throw const FormatException(
            'Backup text exceeds the 64 MB V1 limit.',
          );
        }
        song[key] = await (await checked(name, maxTextBytes)).readAsString();
      }
    }
    final seen = <String>{};
    for (final recording in data['recordings'] as List) {
      final name = recording['audioPath'] as String;
      if (seen.add(name)) await checked(name, 2 * 1024 * 1024 * 1024);
      if (checks[name]['sha256'] != recording['sha256']) {
        throw const FormatException('Conflicting recording checksum.');
      }
    }
    if (expected.length != entries.length ||
        checks.length != expected.length - 1 ||
        !entries.keys.every(expected.contains)) {
      throw const FormatException('Unexpected files in backup.');
    }
    return LibraryBundle(data).data;
  } finally {
    await input.close();
  }
}
