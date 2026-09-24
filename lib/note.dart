import 'dart:convert';
import 'document.dart';

class MusicNote {
  MusicNote({
    String? id,
    this.title = '',
    this.text = '',
    this.revision = 0,
    this.songId,
    this.songTitle,
  }) : id = id ?? ids.v4();
  final String id;
  String title, text;
  int revision;
  String? songId, songTitle;
  String encode() => jsonEncode({'id': id, 'title': title, 'text': text});
  factory MusicNote.decode(
    String content,
    int revision, {
    String? songId,
    String? songTitle,
  }) {
    final data = jsonDecode(content) as Map<String, dynamic>;
    return MusicNote(
      id: data['id'] as String,
      title: data['title'] as String,
      text: data['text'] as String,
      revision: revision,
      songId: songId,
      songTitle: songTitle,
    );
  }
}
