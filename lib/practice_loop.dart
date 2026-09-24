class PracticeLoop {
  const PracticeLoop(this.startMs, this.endMs);
  final int startMs, endMs;
  bool validFor(int durationMs) =>
      startMs >= 0 && endMs <= durationMs && endMs - startMs >= 200;
  int get lengthMs => endMs - startMs;
  int toAbsolute(int positionMs) => startMs + positionMs.clamp(0, lengthMs);
  int toRelative(int positionMs) => (positionMs - startMs).clamp(0, lengthMs);
}

String preciseTime(int ms) =>
    '${ms ~/ 60000}:${((ms ~/ 1000) % 60).toString().padLeft(2, '0')}.${((ms % 1000) ~/ 10).toString().padLeft(2, '0')}';
