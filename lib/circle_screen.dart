import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'circle.dart';
import 'circle_audio.dart';

class CircleScreen extends StatefulWidget {
  const CircleScreen({super.key, this.audio});
  final CircleAudio? audio;
  @override
  State<CircleScreen> createState() => _CircleScreenState();
}

class _CircleScreenState extends State<CircleScreen>
    with WidgetsBindingObserver {
  late final audio = widget.audio ?? NativeCircleAudio();
  CircleChord chord = const CircleChord(0);
  CircleDrag? drag;
  int? pointer;
  String? error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      drag = null;
      pointer = null;
      unawaited(audio.stop().catchError((Object _) {}));
    }
  }

  void select(int step, bool minor) {
    setState(() {
      chord = CircleChord(
        step.clamp(circleMinStep, circleMaxStep),
        minor: minor,
      );
      error = null;
    });
    unawaited(
      audio.play(chord).catchError((Object _) {
        if (mounted) {
          setState(() => error = 'Could not play chord. Tap to retry.');
        }
      }),
    );
  }

  double angle(Offset point, double size) =>
      math.atan2(point.dx - size / 2, size / 2 - point.dy);
  void begin(PointerDownEvent event, double size) {
    if (pointer != null) return;
    final radius =
        (event.localPosition - Offset(size / 2, size / 2)).distance /
        (size / 2);
    if (radius < .34 || radius > 1) return;
    final a = angle(event.localPosition, size);
    final index = (a * 6 / math.pi).round() % 12;
    select((chord.step / 12).floor() * 12 + index, radius < .63);
    drag = CircleDrag(chord.step, a);
    pointer = event.pointer;
  }

  void move(PointerMoveEvent event, double size) {
    if (pointer != event.pointer || drag == null) return;
    final radius = (event.localPosition - Offset(size / 2, size / 2)).distance;
    if (radius < size * .17) {
      drag = null;
      return;
    }
    final step = drag!.move(angle(event.localPosition, size));
    if (step != chord.step) select(step, chord.minor);
  }

  void end(PointerEvent event) {
    if (pointer == event.pointer) {
      pointer = null;
      drag = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(audio.dispose().catchError((Object _) {}));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Circle of Fifths')),
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = math.max(
            0.0,
            math.min(
              520.0,
              math.min(constraints.maxWidth - 32, constraints.maxHeight - 176),
            ),
          );
          return Stack(
            children: [
              Center(
                child: SizedBox.square(
                  dimension: size,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Listener(
                        onPointerDown: (e) => begin(e, size),
                        onPointerMove: (e) => move(e, size),
                        onPointerUp: end,
                        onPointerCancel: end,
                        child: CustomPaint(
                          size: Size.square(size),
                          painter: CirclePainter(
                            chord,
                            Theme.of(context).colorScheme,
                            fontFamily: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.fontFamily,
                          ),
                        ),
                      ),
                      IgnorePointer(
                        child: SizedBox(
                          width: size * .30,
                          height: size * .30,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  chord.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  chord.register,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                Text(chord.minor ? 'minor' : 'major'),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (error != null)
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Text(
                    error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 340),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Lower octave',
                          onPressed: chord.step - 12 >= circleMinStep
                              ? () => select(chord.step - 12, chord.minor)
                              : null,
                          icon: const Icon(Icons.remove),
                        ),
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('Octave ${chord.octave}'),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Higher octave',
                          onPressed: chord.step + 12 <= circleMaxStep
                              ? () => select(chord.step + 12, chord.minor)
                              : null,
                          icon: const Icon(Icons.add),
                        ),
                        IconButton(
                          tooltip: 'Play selected chord',
                          onPressed: () => select(chord.step, chord.minor),
                          icon: const Icon(Icons.play_arrow),
                        ),
                        IconButton(
                          tooltip: 'Stop sound',
                          onPressed: () => unawaited(audio.stop()),
                          icon: const Icon(Icons.stop),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class CirclePainter extends CustomPainter {
  CirclePainter(this.chord, this.colors, {this.fontFamily});
  final CircleChord chord;
  final ColorScheme colors;
  final String? fontFamily;
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero), radius = size.width / 2;
    final paint = Paint();
    void label(
      String text,
      double angle,
      double r,
      double font,
      Color color, {
      bool bold = false,
    }) {
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: color,
            fontFamily: fontFamily,
            fontSize: font,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();
      final point =
          center + Offset(math.sin(angle), -math.cos(angle)) * (radius * r);
      tp.paint(canvas, point - Offset(tp.width / 2, tp.height / 2));
    }

    for (var i = 0; i < 12; i++) {
      final angle = i * math.pi / 6, delta = (i - chord.index) % 12;
      final clustered = delta == 0 || delta == 1 || delta == 11;
      for (final minor in [false, true]) {
        final inner = minor ? .34 : .72, outer = minor ? .63 : 1.0;
        final active = i == chord.index && minor == chord.minor;
        final fill = active
            ? colors.primary
            : clustered
            ? (minor ? colors.tertiaryContainer : colors.primaryContainer)
            : colors.surfaceContainerHighest;
        final ink = active
            ? colors.onPrimary
            : clustered
            ? (minor ? colors.onTertiaryContainer : colors.onPrimaryContainer)
            : colors.onSurfaceVariant;
        final start = angle - math.pi / 2 - math.pi / 12;
        final path = Path()
          ..arcTo(
            Rect.fromCircle(center: center, radius: radius * outer),
            start,
            math.pi / 6,
            false,
          )
          ..arcTo(
            Rect.fromCircle(center: center, radius: radius * inner),
            start + math.pi / 6,
            -math.pi / 6,
            false,
          )
          ..close();
        paint
          ..style = PaintingStyle.fill
          ..color = fill;
        canvas.drawPath(path, paint);
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = colors.surface;
        canvas.drawPath(path, paint);
        label(
          minor ? '${minorNames[i]}m' : fifthNames[i],
          angle,
          minor ? .50 : .87,
          radius * (minor ? .073 : .10),
          ink,
          bold: !minor,
        );
        if (clustered) {
          final degree = chord.minor
              ? (minor
                    ? (delta == 0
                          ? 'i'
                          : delta == 1
                          ? 'v'
                          : 'iv')
                    : (delta == 0
                          ? 'III'
                          : delta == 1
                          ? 'VII'
                          : 'VI'))
              : (minor
                    ? (delta == 0
                          ? 'vi'
                          : delta == 1
                          ? 'iii'
                          : 'ii')
                    : (delta == 0
                          ? 'I'
                          : delta == 1
                          ? 'V'
                          : 'IV'));
          label(degree, angle, minor ? .39 : .76, radius * .052, ink);
        }
      }
      label(signatures[i], angle, .675, radius * .046, colors.onSurfaceVariant);
    }
  }

  @override
  bool shouldRepaint(CirclePainter oldDelegate) =>
      oldDelegate.chord.step != chord.step ||
      oldDelegate.chord.minor != chord.minor ||
      oldDelegate.colors != colors ||
      oldDelegate.fontFamily != fontFamily;
}
