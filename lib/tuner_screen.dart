import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'dsp.dart';
import 'pitch_tracker.dart';
import 'store.dart';

Future<PitchFrame> analyzeInBackground(List<double> samples, int rate) =>
    Isolate.run(() => analyzePitch(samples, rate));

class TunerScreen extends StatefulWidget {
  const TunerScreen({super.key, required this.store});
  final MusicStore store;
  @override
  State<TunerScreen> createState() => _TunerScreenState();
}

class _TunerScreenState extends State<TunerScreen> with WidgetsBindingObserver {
  final recorder = AudioRecorder();
  Future<void>? stopping;
  StreamSubscription<Uint8List>? stream;
  StreamSubscription<RecordState>? states;
  final samples = <double>[];
  int? oddByte;
  int rate = 22050, generation = 0;
  bool running = false, busy = false, processing = false, foreground = true;
  String? error;
  PitchFrame? frame;
  final tracker = PitchTracker();
  final trackingClock = Stopwatch()..start();
  TrackedPitch? tracked;
  int? autoTarget;
  List<int> tuning = [40, 45, 50, 55, 59, 64];
  int? selected;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    states = recorder.onStateChanged().listen((state) {
      if (state != RecordState.record && running && mounted) {
        unawaited(stop());
      }
    });
    unawaited(load());
  }

  Future<void> load() async {
    try {
      final rows = await widget.store.db.query(
        'settings',
        where: 'key = ?',
        whereArgs: ['tuner_tuning'],
      );
      if (rows.isNotEmpty) {
        final value = (jsonDecode(rows.single['value'] as String) as List)
            .cast<int>();
        if (value.length == 6 &&
            value.every((v) => v >= 28 && v <= 88) &&
            mounted) {
          setState(() {
            tuning = value;
          });
        }
      }
    } catch (_) {
      /* A missing preference must not block microphone use. */
    }
    if (mounted && foreground) await start();
  }

  Future<void> start() async {
    await stopping;
    if (!mounted || busy || running || !foreground) return;
    rate = 22050;
    tracker.reset();
    tracked = null;
    autoTarget = null;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (!await recorder.hasPermission()) {
        throw StateError(
          'Microphone access is off. Enable it in Settings, then retry.',
        );
      }
      if (!mounted || !foreground) return;
      await recorder.setOnConfigChanged((config) {
        rate = config.sampleRate;
        samples.clear();
        oddByte = null;
        generation++;
        tracker.reset();
        tracked = null;
        autoTarget = null;
      });
      final input = await recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 22050,
          numChannels: 1,
          autoGain: false,
          echoCancel: false,
          noiseSuppress: false,
        ),
      );
      if (!mounted || !foreground) {
        await recorder.stop();
        return;
      }
      running = true;
      generation++;
      samples.clear();
      oddByte = null;
      stream = input.listen(
        consume,
        onError: (Object e) {
          unawaited(stop());
          if (mounted) {
            setState(() {
              error = 'Microphone stream stopped. Tap Start tuner to retry.';
            });
          }
        },
        onDone: () {
          if (mounted && running) unawaited(stop());
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e is StateError
              ? e.message.toString()
              : 'Could not start microphone. Please retry.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  void consume(Uint8List bytes) {
    if (!running) return;
    var i = 0;
    if (oddByte != null && bytes.isNotEmpty) {
      final raw = oddByte! | (bytes[0] << 8);
      samples.add((raw >= 32768 ? raw - 65536 : raw) / 32768);
      i = 1;
      oddByte = null;
    }
    for (; i + 1 < bytes.length; i += 2) {
      final raw = bytes[i] | (bytes[i + 1] << 8);
      samples.add((raw >= 32768 ? raw - 65536 : raw) / 32768);
    }
    if (i < bytes.length) oddByte = bytes[i];
    const window = 4096;
    if (samples.length < window) return;
    if (samples.length > window) {
      samples.removeRange(0, samples.length - window);
    }
    if (processing) return;
    final input = List<double>.of(samples),
        sampleRate = rate,
        token = generation;
    samples.removeRange(0, 1024);
    processing = true;
    analyzeInBackground(input, sampleRate)
        .then((value) {
          if (mounted && running && token == generation) {
            setState(() {
              frame = value;
              tracked = tracker.update(value, trackingClock.elapsed);
              if (tracked != null && (autoTarget == null || tracked!.newNote)) {
                autoTarget = closestTuning(
                  tracked!.frequency,
                  tuning,
                  previous: autoTarget,
                );
              }
            });
          }
        })
        .catchError((Object e) {
          if (mounted) {
            setState(() {
              error = 'Could not analyze this input. Restart the tuner.';
            });
          }
        })
        .whenComplete(() {
          processing = false;
        });
  }

  Future<void> stop() => stopping ??= finishStop().whenComplete(() {
    stopping = null;
  });

  Future<void> finishStop() async {
    running = false;
    generation++;
    samples.clear();
    oddByte = null;
    await stream?.cancel();
    stream = null;
    try {
      await recorder.stop();
    } catch (_) {}
    if (mounted) {
      setState(() {
        frame = null;
        tracker.reset();
        tracked = null;
        autoTarget = null;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    if (!foreground) unawaited(stop());
  }

  Future<void> configure() async {
    var edited = List<int>.of(tuning);
    final result = await showDialog<List<int>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Guitar tuning'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: () => setDialog(() {
                        edited = [40, 45, 50, 55, 59, 64];
                      }),
                      child: const Text('Standard'),
                    ),
                    TextButton(
                      onPressed: () => setDialog(() {
                        edited = [38, 45, 50, 55, 59, 64];
                      }),
                      child: const Text('Drop D'),
                    ),
                  ],
                ),
                const Text('Low string → high string'),
                for (var i = 0; i < 6; i++)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('String ${6 - i}'),
                      IconButton(
                        onPressed: edited[i] > 28
                            ? () => setDialog(() {
                                edited[i]--;
                              })
                            : null,
                        icon: const Icon(Icons.remove),
                      ),
                      Text(noteName(edited[i])),
                      IconButton(
                        onPressed: edited[i] < 88
                            ? () => setDialog(() {
                                edited[i]++;
                              })
                            : null,
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, edited),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;
    try {
      await widget.store.db.rawInsert(
        'INSERT OR REPLACE INTO settings(key,value) VALUES (?,?)',
        ['tuner_tuning', jsonEncode(result)],
      );
      if (mounted) {
        setState(() {
          tuning = result;
          autoTarget = null;
          selected = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          error = 'Could not save tuning. Please retry.';
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    running = false;
    generation++;
    unawaited(stream?.cancel());
    unawaited(states?.cancel());
    unawaited(releaseMicrophone());
    super.dispose();
  }

  Future<void> releaseMicrophone() async {
    try {
      await recorder.stop();
    } catch (_) {}
    await recorder.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hz = tracked?.frequency;
    final target = selected == null
        ? (autoTarget ?? tuning.first)
        : tuning[selected!];
    final cents = hz == null ? null : centsFrom(hz, noteFrequency(target));
    final inTune = cents != null && cents.abs() < 5;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tuner'),
        actions: [
          IconButton(
            tooltip: 'Guitar tuning',
            onPressed: configure,
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 20),
            Center(
              child: ChoiceChip(
                label: const Text('Auto'),
                selected: selected == null,
                onSelected: (_) => setState(() {
                  selected = null;
                }),
              ),
            ),
            const SizedBox(height: 8),
            // Face-on headstock: D/A/E on the left, G/B/E on the right.
            for (final pair in [
              [2, 3],
              [1, 4],
              [0, 5],
            ])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (final i in pair)
                      Semantics(
                        label: 'String ${6 - i}, ${noteName(tuning[i])}',
                        selected: selected == i,
                        child: SizedBox(
                          width: 56,
                          height: 56,
                          child: OutlinedButton(
                            key: ValueKey('tuner-string-$i'),
                            style: OutlinedButton.styleFrom(
                              shape: const CircleBorder(),
                              padding: EdgeInsets.zero,
                              backgroundColor:
                                  selected == i ||
                                      (selected == null &&
                                          autoTarget == tuning[i])
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.primaryContainer
                                  : null,
                            ),
                            onPressed: () => setState(() {
                              selected = i;
                            }),
                            child: Text(
                              noteName(
                                tuning[i],
                              ).replaceAll(RegExp(r'-?\d+'), ''),
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            Text(
              hz == null ? '—' : noteName(target),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 80,
                fontWeight: FontWeight.w600,
                color: inTune ? Theme.of(context).colorScheme.primary : null,
              ),
            ),
            Text(
              cents == null
                  ? (running ? 'Listening…' : 'Tuner paused')
                  : '${cents >= 0 ? '+' : ''}${cents.toStringAsFixed(1)} cents',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 24),
            CustomPaint(
              size: const Size(double.infinity, 60),
              painter: _CentsPainter(
                cents,
                Theme.of(context).colorScheme.primary,
              ),
            ),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [Text('−200'), Text('0'), Text('+200 cents')],
            ),
            Text(
              cents == null
                  ? 'A4 = 440 Hz'
                  : inTune
                  ? (tracked?.held == true ? 'Holding last pitch…' : 'In tune')
                  : tracked?.held == true
                  ? 'Holding last pitch…'
                  : cents < 0
                  ? 'Tune up'
                  : 'Tune down',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            FilledButton.icon(
              onPressed: busy
                  ? null
                  : running
                  ? stop
                  : start,
              icon: Icon(running ? Icons.pause : Icons.mic),
              label: Text(
                busy
                    ? 'Starting…'
                    : running
                    ? 'Pause tuner'
                    : 'Start tuner',
              ),
            ),
            ExpansionTile(
              title: const Text('Audio details'),
              children: [
                Text(
                  'Frequency: ${hz?.toStringAsFixed(2) ?? '—'} Hz · Confidence: ${((frame?.confidence ?? 0) * 100).round()}%',
                ),
                Text(
                  'Input: ${frame == null ? '—' : (20 * math.log(math.max(frame!.rms, 1e-8)) / math.ln10).toStringAsFixed(1)} dBFS · $rate Hz PCM',
                ),
                const SizedBox(height: 12),
                const Text('Live spectrum · 0–2,000 Hz'),
                SizedBox(
                  height: 140,
                  child: CustomPaint(
                    size: const Size(double.infinity, 140),
                    painter: _SpectrumPainter(
                      frame?.spectrum ?? [],
                      rate,
                      Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                if (hz != null)
                  Text(
                    'Harmonic guides: ${List.generate(4, (i) => '${(hz * (i + 1)).round()} Hz').join(' · ')}',
                  ),
                const Text(
                  'YIN periodicity confidence; harmonic guides are multiples of the detected fundamental.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CentsPainter extends CustomPainter {
  _CentsPainter(this.cents, this.color);
  final Color color;
  final double? cents;
  @override
  void paint(Canvas canvas, Size size) {
    final pen = Paint()
      ..color = Colors.grey
      ..strokeWidth = 2;
    canvas.drawLine(Offset(0, 30), Offset(size.width, 30), pen);
    for (final t in [-200, -100, 0, 100, 200]) {
      final x = (t + 200) / 400 * size.width;
      canvas.drawLine(Offset(x, 20), Offset(x, 40), pen);
    }
    if (cents != null) {
      canvas.drawCircle(
        Offset((cents!.clamp(-200, 200) + 200) / 400 * size.width, 30),
        7,
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_CentsPainter old) =>
      old.cents != cents || old.color != color;
}

class _SpectrumPainter extends CustomPainter {
  _SpectrumPainter(this.bins, this.rate, this.color);
  final Color color;
  final List<double> bins;
  final int rate;
  @override
  void paint(Canvas canvas, Size size) {
    if (bins.isEmpty) return;
    final path = Path();
    final end = math.min(bins.length - 1, (2000 * 4096 / rate).floor());
    for (var i = 0; i <= end; i++) {
      final db = 20 * math.log(math.max(bins[i], 1e-5)) / math.ln10;
      final x = i / end * size.width,
          y = size.height * (1 - (db + 100).clamp(0, 100) / 100);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_SpectrumPainter old) =>
      old.bins != bins || old.rate != rate || old.color != color;
}
