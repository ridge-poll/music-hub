import 'document.dart';

/// A deliberately small ChordPro subset. Unrecognized directives stay visible.
SongDocument importSongText(
  String source, {
  required String filename,
  bool chordPro = false,
}) {
  var text = source.startsWith('\uFEFF') ? source.substring(1) : source;
  var title = filename, artist = '';
  if (chordPro) {
    final lines = <String>[];
    for (final line in text.split('\n')) {
      final directive = RegExp(
        r'^\s*\{(title|t|artist):\s*(.*?)\}\s*$',
      ).firstMatch(line);
      if (directive != null) {
        if (directive[1] == 'artist') {
          artist = directive[2]!;
        } else {
          title = directive[2]!;
        }
        continue;
      }
      if (RegExp(r'^\s*\{(start_of_chorus|soc)\}\s*$').hasMatch(line)) {
        lines.add('[Chorus]');
        continue;
      }
      if (RegExp(r'^\s*\{(end_of_chorus|eoc)\}\s*$').hasMatch(line)) continue;
      lines.add(
        line.replaceAllMapped(
          RegExp(
            r'\[([A-G](?:#|b)?(?:m|maj|min|dim|aug|sus|add)?[0-9]*(?:/[A-G](?:#|b)?)?)\]',
          ),
          (m) => '{${m[1]}}',
        ),
      );
    }
    text = lines.join('\n');
  }
  // A filename or metadata alone must not turn an empty import into content.
  return SongDocument(
    title: text.trim().isEmpty ? '' : title,
    artist: text.trim().isEmpty ? '' : artist,
    text: text,
  );
}

String exportTabText(String text, String annotations) =>
    annotations.isEmpty ? text : '$text\n\n$annotations';
String safeFilename(String title) {
  final name = title
      .replaceAll(RegExp(r'[\x00-\x1f/\\:*?"<>|]'), '_')
      .trim()
      .replaceAll(RegExp(r'^\.+|\.+$'), '');
  return name.isEmpty
      ? 'MusicHub'
      : name.length > 80
      ? name.substring(0, 80)
      : name;
}
