import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'tempo_estimator.dart';

Future<TempoEstimate?> _estimate(List<double> samples, int rate) =>
    Isolate.run(() => estimateTempo(samples, rate));

class BpmListenScreen extends StatefulWidget {
  const BpmListenScreen({super.key});
  @override
  State<BpmListenScreen> createState() => _BpmListenScreenState();
}

class _BpmListenScreenState extends State<BpmListenScreen>
    with WidgetsBindingObserver {
  final recorder = AudioRecorder();
  final samples = <double>[];
  StreamSubscription<Uint8List>? input;
  StreamSubscription<RecordState>? states;
  Timer? timeout;
  int rate = 22050, token = 0, seconds = 0;
  int? odd;
  bool listening = false, busy = false, foreground = true;
  String? message;
  TempoEstimate? estimate;
  Future<void>? pendingStart, stopping;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    states = recorder.onStateChanged().listen((state) {
      if (state != RecordState.record && listening) {
        unawaited(cancel('Listening interrupted. Try again.'));
      }
    });
    pendingStart = start();
  }

  Future<void> start() async {
    final current = ++token;
    setState(() {
      busy = true;
      message = null;
      estimate = null;
      seconds = 0;
    });
    try {
      await stopping;
      if (!mounted || current != token || !foreground) return;
      if (!await recorder.hasPermission()) {
        throw StateError(
          'Microphone access is off. Enable it in Settings, then retry.',
        );
      }
      if (!mounted || current != token || !foreground) return;
      samples.clear();
      odd = null;
      await recorder.setOnConfigChanged((config) {
        rate = config.sampleRate;
        samples.clear();
        odd = null;
      });
      final stream = await recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 22050,
          numChannels: 1,
          autoGain: false,
          echoCancel: false,
          noiseSuppress: false,
        ),
      );
      if (!mounted || current != token || !foreground) {
        await recorder.stop();
        return;
      }
      setState(() => listening = true);
      input = stream.listen(
        consume,
        onError: (Object _) {
          unawaited(cancel('Could not read microphone audio. Try again.'));
        },
        onDone: () {
          if (listening) unawaited(cancel('Listening ended early. Try again.'));
        },
      );
      timeout = Timer(
        const Duration(seconds: 14),
        () => unawaited(cancel('Not enough audio arrived. Try again.')),
      );
    } catch (e) {
      if (mounted && current == token) {
        setState(
          () => message = e is StateError
              ? e.message.toString()
              : 'Could not start microphone. Try again.',
        );
      }
    } finally {
      if (mounted && current == token) setState(() => busy = false);
    }
  }

  void consume(Uint8List bytes) {
    if (!listening) return;
    var i = 0;
    void sample(int value) {
      if (samples.length < rate * 12) {
        samples.add((value >= 32768 ? value - 65536 : value) / 32768);
      }
    }

    if (odd != null && bytes.isNotEmpty) {
      sample(odd! | (bytes[0] << 8));
      i = 1;
      odd = null;
    }
    for (; i + 1 < bytes.length; i += 2) {
      sample(bytes[i] | (bytes[i + 1] << 8));
    }
    if (i < bytes.length) odd = bytes[i];
    final elapsed = samples.length ~/ rate;
    if (elapsed != seconds && mounted) setState(() => seconds = elapsed);
    if (samples.length >= rate * 12) unawaited(finish());
  }

  Future<void> stopInput() => stopping ??= finishStop().whenComplete(() {
    stopping = null;
  });

  Future<void> finishStop() async {
    listening = false;
    timeout?.cancel();
    await input?.cancel();
    input = null;
    await recorder.stop();
  }

  Future<void> finish() async {
    if (!listening) return;
    final current = token;
    setState(() => busy = true);
    try {
      await stopInput();
      if (!mounted || current != token) return;
      final captured = List<double>.of(samples);
      samples.clear();
      final result = await _estimate(captured, rate);
      if (mounted && token == current) {
        setState(() {
          estimate = result;
          message = result == null
              ? 'No steady pulse found. Try a clearer rhythmic passage.'
              : null;
          busy = false;
        });
      }
    } catch (_) {
      if (mounted && token == current) {
        setState(() {
          busy = false;
          message = 'Could not analyze this audio. Try again.';
        });
      }
    }
  }

  Future<void> cancel(String reason) async {
    token++;
    if (mounted) {
      setState(() {
        busy = false;
        listening = false;
        message = reason;
      });
    }
    try {
      await stopInput();
    } catch (_) {}
    samples.clear();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    if (!foreground) {
      unawaited(cancel('Listening paused. Tap Listen again to restart.'));
    }
  }

  Future<void> cleanup() async {
    try {
      await pendingStart;
      try {
        await stopInput();
      } catch (_) {}
      await states?.cancel();
      await recorder.dispose();
    } catch (_) {}
  }

  @override
  void dispose() {
    token++;
    listening = false;
    timeout?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(cleanup());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Listen for BPM')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.mic_none, size: 64),
          const SizedBox(height: 24),
          const Text(
            'Play a steady passage for 12 seconds. Audio stays on this phone and is not saved.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (listening) ...[
            LinearProgressIndicator(value: seconds / 12),
            Text('Listening… $seconds / 12 s', textAlign: TextAlign.center),
            TextButton(
              onPressed: () => cancel('Listening cancelled.'),
              child: const Text('Cancel listening'),
            ),
          ] else if (busy)
            const Center(child: CircularProgressIndicator()),
          if (message != null) Text(message!, textAlign: TextAlign.center),
          if (estimate != null) ...[
            Text(
              '${estimate!.bpm} BPM',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const Text(
              'Estimated pulse · half or double tempo may also fit.',
              textAlign: TextAlign.center,
            ),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              children: [
                for (final value in {
                  (estimate!.bpm / 2).round(),
                  estimate!.bpm,
                  estimate!.bpm * 2,
                }.where((v) => v >= 40 && v <= 240))
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context, value),
                    child: Text('Use $value BPM'),
                  ),
              ],
            ),
          ],
          if (!listening && !busy)
            TextButton(
              onPressed: () async {
                await pendingStart;
                if (!mounted) return;
                pendingStart = start();
              },
              child: const Text('Listen again'),
            ),
        ],
      ),
    ),
  );
}
