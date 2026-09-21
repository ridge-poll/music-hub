class RecordingEntry {
  const RecordingEntry({
    required this.id,
    required this.title,
    required this.relativePath,
    required this.durationMs,
    required this.createdAt,
    this.songId,
    this.songTitle,
  });
  final String id;
  final String title;
  final String relativePath;
  final int durationMs;
  final String createdAt;
  final String? songId;
  final String? songTitle;
}

String audioTime(Duration duration) {
  final seconds = duration.inSeconds;
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}
