import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'document.dart';
import 'store.dart';

class AudioDraft {
  AudioDraft({
    required this.id,
    required this.createdAt,
    required this.title,
    this.songId,
    this.durationMs = 0,
  });
  final String id;
  final String createdAt;
  String title;
  String? songId;
  int durationMs;
  Map<String, dynamic> toJson() => {
    'id': id,
    'createdAt': createdAt,
    'title': title,
    'songId': songId,
    'durationMs': durationMs,
  };
  factory AudioDraft.fromJson(Map<String, dynamic> json) => AudioDraft(
    id: json['id'],
    createdAt: json['createdAt'],
    title: json['title'],
    songId: json['songId'],
    durationMs: json['durationMs'] ?? 0,
  );
}

// Capture drafts are durable and distinct from immutable published assets.
// SQL commit precedes draft cleanup, so an interrupted save can be retried.
class AudioFiles {
  AudioFiles(this.root);
  final Directory root;
  Directory get drafts => Directory(path.join(root.path, 'audio', 'drafts'));
  File draftAudio(AudioDraft draft) =>
      File(path.join(drafts.path, '${draft.id}.m4a'));
  File _manifest(AudioDraft draft) =>
      File(path.join(drafts.path, '${draft.id}.json'));
  File resolve(String relativePath) {
    final absolute = path.normalize(path.join(root.path, relativePath));
    if (path.isAbsolute(relativePath) || !path.isWithin(root.path, absolute)) {
      throw const FormatException('Audio path must stay within the library');
    }
    return File(absolute);
  }

  Future<AudioDraft> createDraft({String? songId}) async {
    final now = DateTime.now();
    final draft = AudioDraft(
      id: ids.v4(),
      createdAt: now.toIso8601String(),
      title:
          'Take ${now.month}/${now.day} · ${now.hour}:${now.minute.toString().padLeft(2, '0')}',
      songId: songId,
    );
    await writeDraft(draft);
    return draft;
  }

  Future<void> writeDraft(AudioDraft draft) async {
    await drafts.create(recursive: true);
    final pending = File('${_manifest(draft).path}.pending');
    await pending.writeAsString(jsonEncode(draft.toJson()), flush: true);
    await pending.rename(_manifest(draft).path);
  }

  Future<List<AudioDraft>> pending() async {
    if (!await drafts.exists()) {
      return [];
    }
    final result = <AudioDraft>[];
    await for (final file in drafts.list()) {
      if (file is File && file.path.endsWith('.json')) {
        final draft = AudioDraft.fromJson(
          jsonDecode(await file.readAsString()),
        );
        if (!RegExp(r'^[a-f0-9-]{36}$').hasMatch(draft.id)) {
          throw const FormatException('Invalid draft identity');
        }
        result.add(draft);
      }
    }
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  Future<void> save(MusicStore store, AudioDraft draft) async {
    await writeDraft(draft);
    final source = draftAudio(draft);
    if (!await source.exists() || await source.length() == 0) {
      throw const FileSystemException('This draft contains no audio');
    }
    final hash = (await sha256.bind(source.openRead()).first).toString();
    final relative = path.join('audio', 'objects', '$hash.m4a');
    final asset = resolve(relative);
    await asset.parent.create(recursive: true);
    if (!await asset.exists()) {
      final staged = await source.copy('${asset.path}.${draft.id}.pending');
      // Never replace an existing asset. Identical bytes share one blob.
      if (!await asset.exists()) {
        await staged.rename(asset.path);
      } else {
        await staged.delete();
      }
    }
    // Verify an existing asset before trusting it or deleting the capture copy.
    if ((await sha256.bind(asset.openRead()).first).toString() != hash) {
      throw const FileSystemException('Stored audio failed verification');
    }
    await store.saveRecording(
      id: draft.id,
      title: draft.title.trim().isEmpty ? 'Untitled take' : draft.title.trim(),
      hash: hash,
      relativePath: relative,
      durationMs: draft.durationMs,
      createdAt: draft.createdAt,
      songId: draft.songId,
    );
    // Cleanup failure cannot invalidate a successful, verified save. A remaining
    // draft is safe to retry because its recording UUID is already committed.
    try {
      await discard(draft);
    } on FileSystemException {
      /* Retain redundant bytes. */
    }
  }

  Future<void> discard(AudioDraft draft) async {
    // Remove the manifest first. After SQL commit, a crash during cleanup may
    // leave redundant bytes, but never a false recoverable-draft entry.
    final manifest = _manifest(draft);
    if (await manifest.exists()) {
      await manifest.delete();
    }
    final source = draftAudio(draft);
    if (await source.exists()) {
      await source.delete();
    }
  }
}
