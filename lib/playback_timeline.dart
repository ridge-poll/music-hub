import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'practice_loop.dart';

/// One surface for seeking and region selection. Audio clipping is committed
/// only at the end of a drag; the handles themselves track every pointer update.
class PlaybackTimeline extends StatefulWidget {
  const PlaybackTimeline({
    super.key,
    required this.durationMs,
    required this.positionMs,
    required this.region,
    required this.onSeek,
    required this.onRegion,
    this.enabled = true,
  });
  final int durationMs, positionMs;
  final PracticeLoop? region;
  final ValueChanged<int> onSeek;
  final ValueChanged<PracticeLoop?> onRegion;
  final bool enabled;
  @override
  State<PlaybackTimeline> createState() => _PlaybackTimelineState();
}

class _PlaybackTimelineState extends State<PlaybackTimeline> {
  double? left, right;
  int? dragging;
  double get start => left ?? widget.region?.startMs.toDouble() ?? 0;
  double get end =>
      right ?? widget.region?.endMs.toDouble() ?? widget.durationMs.toDouble();
  double get minimum => math.min(200, widget.durationMs).toDouble();
  @override
  void didUpdateWidget(covariant PlaybackTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.enabled && widget.enabled) {
      left = null;
      right = null;
    }
  }

  void finish() {
    if (dragging == 0 || dragging == 1) {
      widget.onRegion(
        start.round() == 0 && end.round() == widget.durationMs
            ? null
            : PracticeLoop(start.round(), end.round()),
      );
    }
    setState(() {
      if (dragging == 2) {
        left = null;
        right = null;
      }
      dragging = null;
    });
  }

  void adjust(bool isStart, double delta) {
    if (!widget.enabled) return;
    final a = isStart ? (start + delta).clamp(0, end - minimum) : start;
    final b = isStart
        ? end
        : (end + delta).clamp(start + minimum, widget.durationMs.toDouble());
    widget.onRegion(
      a.round() == 0 && b.round() == widget.durationMs
          ? null
          : PracticeLoop(a.round(), b.round()),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const inset = 16.0;
      final width = math.max(1.0, constraints.maxWidth - inset * 2);
      final total = math.max(1, widget.durationMs);
      double x(double value) => inset + value / total * width;
      double time(double point) =>
          ((point - inset) / width * total).clamp(0, total.toDouble());
      final enabled = widget.enabled && widget.durationMs > 0;
      return Column(
        children: [
          GestureDetector(
            key: const Key('playback-timeline'),
            behavior: HitTestBehavior.opaque,
            onTapUp: enabled
                ? (details) => widget.onSeek(
                    time(
                      details.localPosition.dx,
                    ).round().clamp(start.round(), end.round()),
                  )
                : null,
            onHorizontalDragStart: enabled
                ? (details) {
                    final point = details.localPosition.dx;
                    final dl = (point - x(start)).abs(),
                        dr = (point - x(end)).abs();
                    setState(() {
                      dragging = math.min(dl, dr) <= 24
                          ? (dl <= dr ? 0 : 1)
                          : 2;
                      left = start;
                      right = end;
                    });
                  }
                : null,
            onHorizontalDragUpdate: enabled
                ? (details) {
                    final value = time(details.localPosition.dx);
                    if (dragging == 2) {
                      widget.onSeek(
                        value.round().clamp(start.round(), end.round()),
                      );
                      return;
                    }
                    setState(() {
                      if (dragging == 0) {
                        left = value.clamp(0, end - minimum);
                      } else if (dragging == 1) {
                        right = value.clamp(start + minimum, total.toDouble());
                      }
                    });
                  }
                : null,
            onHorizontalDragEnd: enabled ? (_) => finish() : null,
            onHorizontalDragCancel: () => setState(() {
              dragging = null;
              left = null;
              right = null;
            }),
            child: SizedBox(
              height: 56,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _TimelinePainter(
                        start: start / total,
                        end: end / total,
                        position:
                            widget.positionMs.clamp(
                              start.round(),
                              end.round(),
                            ) /
                            total,
                        color: Theme.of(context).colorScheme.primary,
                        muted: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: .22),
                      ),
                    ),
                  ),
                  Positioned(
                    left: x(start) - 14,
                    top: 4,
                    bottom: 4,
                    width: 28,
                    child: IgnorePointer(
                      child: Semantics(
                        label: 'Playback region start',
                        value: preciseTime(start.round()),
                        increasedValue: preciseTime((start + 200).round()),
                        decreasedValue: preciseTime(
                          (start - 200).round().clamp(0, total),
                        ),
                        onIncrease: enabled ? () => adjust(true, 200) : null,
                        onDecrease: enabled ? () => adjust(true, -200) : null,
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                  Positioned(
                    left: x(end) - 14,
                    top: 4,
                    bottom: 4,
                    width: 28,
                    child: IgnorePointer(
                      child: Semantics(
                        label: 'Playback region end',
                        value: preciseTime(end.round()),
                        increasedValue: preciseTime(
                          (end + 200).round().clamp(0, total),
                        ),
                        decreasedValue: preciseTime((end - 200).round()),
                        onIncrease: enabled ? () => adjust(false, 200) : null,
                        onDecrease: enabled ? () => adjust(false, -200) : null,
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                preciseTime(start.round()),
                style: Theme.of(context).textTheme.labelSmall,
              ),
              Text(
                preciseTime(widget.positionMs),
                style: Theme.of(context).textTheme.labelSmall,
              ),
              Text(
                preciseTime(end.round()),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ],
      );
    },
  );
}

class _TimelinePainter extends CustomPainter {
  _TimelinePainter({
    required this.start,
    required this.end,
    required this.position,
    required this.color,
    required this.muted,
  });
  final double start, end, position;
  final Color color, muted;
  @override
  void paint(Canvas canvas, Size size) {
    double x(double value) => 16 + value * (size.width - 32);
    final y = size.height / 2;
    final line = Paint()
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(x(0), y),
      Offset(x(1), y),
      line..color = muted.withValues(alpha: .10),
    );
    canvas.drawLine(
      Offset(x(start), y),
      Offset(x(end), y),
      line..color = muted,
    );
    canvas.drawLine(
      Offset(x(start), y),
      Offset(x(position), y),
      line..color = color,
    );
    canvas.drawCircle(Offset(x(position), y), 4, Paint()..color = color);
    for (final edge in [start, end]) {
      canvas.drawLine(
        Offset(x(edge), y - 13),
        Offset(x(edge), y + 13),
        Paint()
          ..color = color
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter old) =>
      old.start != start ||
      old.end != end ||
      old.position != position ||
      old.color != color ||
      old.muted != muted;
}
