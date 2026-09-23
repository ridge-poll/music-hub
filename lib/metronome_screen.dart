import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'metronome.dart';
import 'metronome_audio.dart';
import 'store.dart';

class MetronomeScreen extends StatefulWidget {
  const MetronomeScreen({super.key, required this.store, this.audio});
  final MusicStore store;
  final MetronomeAudio? audio;
  @override
  State<MetronomeScreen> createState() => _MetronomeScreenState();
}

class _MetronomeScreenState extends State<MetronomeScreen>
    with WidgetsBindingObserver {
  late final audio = widget.audio ?? NativeMetronomeAudio();
  final clock = Stopwatch()..start();
  final taps = TapTempo();
  final subscriptions = <StreamSubscription<dynamic>>[];
  MetronomeSettings settings = MetronomeSettings();
  bool ready = false, running = false, loading = false;
  int beat = -1, generation = 0;
  String? message;
  Future<void> writes = Future.value();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    subscriptions.add(
      audio.positions.listen((position) {
        if (!mounted || !running || loading) return;
        final next =
            (position.inMicroseconds * settings.bpm / 60000000).floor() %
            settings.beats;
        if (beat != next) setState(() => beat = next);
      }),
    );
    subscriptions.add(
      audio.interruptions.listen((_) {
        unawaited(stop('Audio interrupted. Tap Start to resume.'));
      }),
    );
    unawaited(load());
  }

  Future<void> load() async {
    try {
      final rows = await widget.store.db.query(
        'settings',
        where: 'key = ?',
        whereArgs: ['metronome'],
      );
      final value = rows.isEmpty
          ? MetronomeSettings()
          : MetronomeSettings.fromJson(
              jsonDecode(rows.single['value'] as String)
                  as Map<String, dynamic>,
            );
      if (mounted) {
        setState(() {
          settings = value;
          ready = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          ready = true;
          message = 'Could not load preferences. Using defaults.';
        });
      }
    }
  }

  void change({int? bpm, int? beats, int? unit, List<int>? accents}) {
    setState(() {
      settings = MetronomeSettings(
        bpm: bpm ?? settings.bpm,
        beats: beats ?? settings.beats,
        unit: unit ?? settings.unit,
        accents: accents ?? (beats == null ? settings.accents : null),
      );
      beat = -1;
    });
    final value = jsonEncode(settings.toJson());
    writes = writes.then((_) async {
      try {
        await widget.store.db.rawInsert(
          'INSERT OR REPLACE INTO settings(key,value) VALUES (?,?)',
          ['metronome', value],
        );
      } catch (_) {
        if (mounted) {
          setState(() => message = 'Preferences could not be saved.');
        }
      }
    });
    if (running) unawaited(start());
  }

  Future<void> start() async {
    final token = ++generation;
    setState(() {
      running = true;
      loading = true;
      message = null;
      beat = -1;
    });
    try {
      await audio.start(settings);
      if (mounted && token == generation) {
        setState(() {
          loading = false;
          beat = 0;
        });
      }
    } catch (_) {
      if (mounted && token == generation) {
        await stop('Could not start audio. Tap Start to retry.');
      }
    }
  }

  Future<void> stop([String? reason]) async {
    generation++;
    if (mounted) {
      setState(() {
        running = false;
        loading = false;
        beat = -1;
        message = reason;
      });
    }
    try {
      await audio.stop();
    } catch (_) {
      if (mounted) {
        setState(
          () => message =
              'Could not stop audio. Leave this screen to release playback.',
        );
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(stop());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    generation++;
    for (final subscription in subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(audio.dispose().catchError((Object _) {}));
    clock.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Metronome')),
    body: !ready
        ? const Center(child: CircularProgressIndicator())
        : SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    '${settings.bpm}',
                    key: const Key('bpm'),
                    style: const TextStyle(
                      fontSize: 76,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Center(
                  child: Text(
                    'BPM · ${settings.unit == 2
                        ? 'half'
                        : settings.unit == 4
                        ? 'quarter'
                        : 'eighth'}-note pulse',
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Slower',
                      onPressed: settings.bpm > 40
                          ? () => change(bpm: settings.bpm - 1)
                          : null,
                      icon: const Icon(Icons.remove),
                    ),
                    Expanded(
                      child: Slider(
                        value: settings.bpm.toDouble(),
                        min: 40,
                        max: 240,
                        divisions: 200,
                        label: '${settings.bpm}',
                        onChanged: (value) => change(bpm: value.round()),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Faster',
                      onPressed: settings.bpm < 240
                          ? () => change(bpm: settings.bpm + 1)
                          : null,
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
                Center(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final bpm = taps.tap(clock.elapsedMilliseconds);
                      if (bpm != null) change(bpm: bpm);
                    },
                    icon: const Icon(Icons.touch_app_outlined),
                    label: const Text('Tap tempo'),
                  ),
                ),
                const SizedBox(height: 24),
                const Center(child: Text('Time signature')),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    DropdownButton<int>(
                      key: const Key('beats'),
                      value: settings.beats,
                      items: List.generate(
                        12,
                        (i) => DropdownMenuItem(
                          value: i + 1,
                          child: Text('${i + 1}'),
                        ),
                      ),
                      onChanged: (value) {
                        if (value != null) change(beats: value);
                      },
                    ),
                    const Text(' / '),
                    DropdownButton<int>(
                      key: const Key('unit'),
                      value: settings.unit,
                      items: [
                        for (final unit in [2, 4, 8])
                          DropdownMenuItem(value: unit, child: Text('$unit')),
                      ],
                      onChanged: (value) {
                        if (value != null) change(unit: value);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (var i = 0; i < settings.beats; i++)
                      Semantics(
                        label:
                            'Beat ${i + 1}, ${['silent', 'normal', 'accented'][settings.accents[i]]}',
                        selected: beat == i,
                        child: OutlinedButton(
                          key: ValueKey('beat-$i'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(56, 64),
                            backgroundColor: beat == i
                                ? Theme.of(context).colorScheme.primaryContainer
                                : null,
                          ),
                          onPressed: () {
                            final accents = List<int>.of(settings.accents);
                            accents[i] = (accents[i] + 1) % 3;
                            change(accents: accents);
                          },
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('${i + 1}'),
                              Icon(
                                [
                                  Icons.volume_off_outlined,
                                  Icons.circle_outlined,
                                  Icons.keyboard_arrow_up,
                                ][settings.accents[i]],
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                const Center(
                  child: Text(
                    'Tap a beat: normal → accent → silent',
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: running ? stop : start,
                  icon: Icon(running ? Icons.stop : Icons.play_arrow),
                  label: Text(running ? 'Stop' : 'Start'),
                ),
                if (loading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: Text('Preparing clicks…'),
                    ),
                  ),
                if (message != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(message!, textAlign: TextAlign.center),
                  ),
              ],
            ),
          ),
  );
}
