import 'dart:convert';
import 'metronome.dart';

const audioExtensions = {
  'm4a',
  'mp3',
  'wav',
  'aac',
  'aif',
  'aiff',
  'caf',
  'flac',
  'ogg',
};
const portableSettings = {'dark_mode', 'metronome', 'tuner_tuning'};
const maxTextBytes = 8 * 1024 * 1024;
const maxLibraryTextBytes = 64 * 1024 * 1024;

/// Logical library snapshot, deliberately independent of SQLite tables.
/// Text is inlined here; the ZIP adapter stores it as ordinary UTF-8 files.
class LibraryBundle {
  LibraryBundle(Map<String, dynamic> source)
    : data = jsonDecode(jsonEncode(source)) as Map<String, dynamic> {
    _validate();
  }
  final Map<String, dynamic> data;
  List<Map<String, dynamic>> get songs =>
      (data['songs'] as List).cast<Map<String, dynamic>>();
  List<Map<String, dynamic>> get recordings =>
      (data['recordings'] as List).cast<Map<String, dynamic>>();
  Map<String, dynamic> get settings => data['settings'] as Map<String, dynamic>;
  String get ownerId => data['ownerId'] as String;
  static final identity = RegExp(r'^[A-Za-z0-9_-]{1,80}$');
  static final hash = RegExp(r'^[a-f0-9]{64}$');
  void _validate() {
    if (data['formatVersion'] != 1 || data['application'] != 'MusicHub') {
      throw const FormatException('Unsupported Music Hub backup version.');
    }
    final identities = <String>{};
    String id(dynamic value, {bool shared = false}) {
      if (value is! String || !identity.hasMatch(value)) {
        throw const FormatException('Invalid backup identity.');
      }
      if (!shared && !identities.add(value)) {
        throw const FormatException('Duplicate backup identity.');
      }
      return value;
    }

    var textBytes = 0;
    void text(dynamic value) {
      if (value is! String || utf8.encode(value).length > maxTextBytes) {
        throw const FormatException('Invalid or oversized backup text.');
      }
      textBytes += utf8.encode(value).length;
      if (textBytes > maxLibraryTextBytes) {
        throw const FormatException('Backup text exceeds the 64 MB V1 limit.');
      }
    }

    void date(dynamic value) {
      text(value);
      if (value != '' && DateTime.tryParse(value) == null) {
        throw const FormatException('Invalid backup date.');
      }
    }

    void number(dynamic value, int max) {
      if (value is! int || value < 0 || value > max) {
        throw const FormatException('Invalid backup number.');
      }
    }

    id(data['ownerId'], shared: true);
    date(data['createdAt']);
    if (data['songs'] is! List ||
        data['recordings'] is! List ||
        data['settings'] is! Map<String, dynamic>) {
      throw const FormatException('Incomplete backup metadata.');
    }
    if (songs.length > 10000 || recordings.length > 20000) {
      throw const FormatException('Backup exceeds V1 library limits.');
    }
    final songIds = <String>{};
    for (final s in songs) {
      songIds.add(id(s['id']));
      id(s['arrangementId']);
      id(s['sheetId']);
      for (final key in [
        'title',
        'artist',
        'chords',
        'annotations',
        'noteTitle',
      ]) {
        text(s[key]);
      }
      date(s['createdAt']);
      date(s['lastEdited']);
      number(s['editOrder'], 9007199254740990);
      for (final pair in [('tabId', 'tab'), ('noteId', 'notes')]) {
        if (s[pair.$1] == null) {
          if (s[pair.$2] != null) {
            throw const FormatException('Missing document identity.');
          }
        } else {
          id(s[pair.$1]);
          text(s[pair.$2]);
        }
      }
      final tuning = s['tuning'];
      if (tuning is! List ||
          tuning.length != 6 ||
          tuning.any((n) => n is! int || n < 0 || n > 127)) {
        throw const FormatException('Invalid tuning.');
      }
      number(s['capo'], 24);
      if (s['tempo'] != null &&
          (s['tempo'] is! num ||
              !(s['tempo'] as num).isFinite ||
              s['tempo'] <= 0 ||
              s['tempo'] > 1000)) {
        throw const FormatException('Invalid tempo.');
      }
    }
    final assets = <String, String>{};
    for (final r in recordings) {
      id(r['id']);
      text(r['title']);
      date(r['createdAt']);
      number(r['durationMs'], 31536000000);
      if (r['songId'] != null && !songIds.contains(r['songId'])) {
        throw const FormatException('Recording refers to a missing Song.');
      }
      final asset = id(r['assetId'], shared: true);
      final sha = r['sha256'];
      if (sha is! String || !hash.hasMatch(sha)) {
        throw const FormatException('Invalid audio checksum.');
      }
      final audio = r['audioPath'];
      if (audio is! String ||
          !audio.startsWith('recordings/$asset.') ||
          !audioExtensions.contains(
            audio.substring('recordings/$asset.'.length),
          )) {
        throw const FormatException('Invalid recording path.');
      }
      final signature = '$sha:$audio';
      if (assets.containsKey(asset)) {
        if (assets[asset] != signature) {
          throw const FormatException('Conflicting audio assets.');
        }
      } else {
        if (!identities.add(asset)) {
          throw const FormatException('Duplicate asset identity.');
        }
        assets[asset] = signature;
      }
    }
    for (final e in settings.entries) {
      if (!portableSettings.contains(e.key) || e.value is! String) {
        throw const FormatException('Unsupported preference.');
      }
      if (e.key == 'dark_mode' && !['true', 'false'].contains(e.value)) {
        throw const FormatException('Invalid theme preference.');
      }
      if (e.key == 'metronome') MetronomeSettings.fromJson(jsonDecode(e.value));
      if (e.key == 'tuner_tuning') {
        final tuning = jsonDecode(e.value);
        if (tuning is! List ||
            tuning.length != 6 ||
            tuning.any((n) => n is! int || n < 0 || n > 127)) {
          throw const FormatException('Invalid tuner preference.');
        }
      }
    }
  }
}
